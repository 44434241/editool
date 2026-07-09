
#run {
	//fg, bg := -1, -1;
	//pair := color_fg_bg(31, 1);
	//fg, bg := uncolor_fg_bg(pair);
	//log("pair: %, fg: %, bg: %", pair, fg, bg);
}

Line :: struct {
	chars: [..]u8;
	#overlay(chars.count) count: int;
	#overlay(chars) as_string: string;
	CONST_MOD_COUNT :: 128 + 64; // looks like the best for memory
	// ^ for some lines it not enough... idk
	//
	mods: [CONST_MOD_COUNT]Char_Mod = ---; // A LOT !
	user_mods: [CONST_MOD_COUNT]Char_Mod = ---;
	Dirty_Flags :: enum_flags {
		MODS; // when text is updated, or when fold is updated? 
		USER1; // something the user sets
		REAL_SIZE;
		NONE :: 0;
		USER_ALL :: USER1;
		ALL :: MODS | USER1 | REAL_SIZE;
	}
	dirty_flags: Dirty_Flags = .ALL;
	// size in x, considering tab characters and all that
	real_size: int = - 1;
	// If this line contains multiline syntax that doesnt end (e.g. '/*'),
	// then this is its index
	multiline_syntax_index: int = -1;
	start_multiline_syntax_index: int = -1; // the syntax was evaluated using this index ! 
}

// this should be fast since line size is cached..
get_line_real_size_as_y :: (win: *Window, line: *Line) -> int {
	if win.size.x <= 0
		return 1;
	sz := get_real_size(line) + 1;
	sz_x := win.size.x;
	if win.flags & .BUFFER_LINE_NO {
		sz += BUFFER_LINE_NO_SIZE_X;
		sz_x += BUFFER_LINE_NO_SIZE_X;
	}
	if win.flags & .BUFFER_MARKS {
		sz += BUFFER_MARKS_SIZE_X;
		sz_x += BUFFER_MARKS_SIZE_X;
	}
	if sz <= 1 
		return 1;
	ret := (sz + sz_x - 1) / sz_x;
	// floor dif
	return ret;
}

get_real_size :: (line: *Line) -> int {
	// TODO (but i don't care that much): setting .dirty_flags for each line whenever the window gets resize would be too much...
	if (line.dirty_flags & .REAL_SIZE) || true {
		// this is the position *after* the last character
		line.real_size = _get_real_x_in_line(line, line.chars.count);
		line.dirty_flags |= .REAL_SIZE;
	}
	return line.real_size;
}

// hm...
Char_Mod :: struct {
	// there might be reasons why i'd want this as a strong..
	// syntax real_x doesn't respect this !
	//replaced: string; // count <= 1
	attributes: s32;
	fg: s8 = 0;
	bg: s8 = -1;
}

as_ncurses_attribute :: (mod: Char_Mod) -> s32 {
	col := color_fg_bg(mod.fg, mod.bg);
	ret: s32 = 0;
	ret |= COLOR_PAIR(col);
	ret |= mod.attributes;
	//ret |= A_BOLD;
	return ret;
}

// creating/destroying buffers still leaks some shit !

// For now, buffer operations must be executed within a window..
// Not sure if i'll want to change that, but might be difficult!
Buffer :: struct {
	Kind :: enum {
		NONE :: 0;
		FILE;
		DIRECTORY; // i'll have a builtin directory file, then maybe make it custom later
		CUSTOM;
	}
	File_Flags :: enum_flags {
		NO_FILE; // failed to read
		READ_ONLY; // Just can't save, no matter what
		CLRF;
		NONE :: 0;
	}
	// capabilities
	Caps :: enum_flags {
		INSERT_CHARS;
		INSERT_LINES;
		ERASE_CHARS; // should rename this to erase...
		ERASE_LINES; // should rename this to erase...
		// Move is (mostly) not implemented, not sure if i even wanna do it like this..
		MOVE_X;
		MOVE_Y;
		//
		MODE_INSERT;
		MODE_COMMAND;
		// Aliases:
		INSERT :: INSERT_CHARS | INSERT_LINES;
		ERASE :: ERASE_CHARS | ERASE_LINES;
		MOVE :: MOVE_X | MOVE_Y;
		MODE_ALL :: MODE_INSERT | MODE_COMMAND;
		ALL :: INSERT | ERASE | MOVE | MODE_INSERT | MODE_COMMAND;
		NONE :: 0;
	}
	Flags :: enum_flags {
		NO_SEARCH;
		//TEMP; // destroy when windows stop referencing it !
		PERM; // actually, an explicitly perm flag makes more sense. not implemented
		NONE :: 0;
	}
	pool: Pool;
	flags: Flags;
	id: BufId = BUF_ID_NULL;
	kind: Kind = .NONE;
	caps: Caps = .NONE;
	// ^ could be a file flag tbh
	lines: [..]Line;
	//is_dirty: bool = false; // i dont know what this means..
	ops: [..]Buffer_Op; // this array shouldn't get touched outside execute_buffer_operation (and loading file rn)
	// Index for next operation to be done
	// 0 <= x <= ops.count
	op_index: int = 0; 
	// Operation index when buffer was saved
	// -1 <= x <= ops.count (-1 when messing with undo/redo)
	// (save could mean something generic, not specifically file)
	save_op_index: int = 0; 
	modify_time: Editime; // when the last modifying operation happened?
	windows: [..]*Window; // doing it like this for now..
	commands: [..]Command; // can only be added to after buffer creation
	search_matches: Search_Matches; // touched by search..
	marks: [..]Mark;
	folds: [..]Fold;
	// file
	path: string; // for .FILE or .DIRECTORY
	file_flags: File_Flags;
	syntax: *Syntax;
	// extra stuff
	user_data: *void; // has to be explicitly
	modify_buffer_operation: #type (*Window, *Buffer, *Buffer_Op) -> bool;
	// both buffer and window have apply_mods
	apply_mods: #type (*Window, []*Line) -> ();
	active_checkpoint: Buffer_Checkpoint = BUFFER_CHECKPOINT_NULL;
	user_title: string;
	ref_count: int;
	//
	directory_files: [..]Directory_File;
	directory_files_confirm_index := -1;
	//is_in_directory_confirm_thing := false;
}

Fold :: struct {
	// inclusive
	start: int = -1;
	end: int = -1;
}

get_fold_exact :: (buf: *Buffer, y: int) -> *Fold {
	for * buf.folds {
		if it.start == y
			return it;
	}
	return null;
}

get_fold :: (buf: *Buffer, y: int) -> *Fold {
	for * buf.folds {
		if it.start <= y && y <= it.end
			return it;
	}
	return null;
}

add_fold :: (buf: *Buffer, fold: Fold) {
	buf.lines[fold.start].dirty_flags |= .MODS;
	array_add(*buf.folds, fold);
}

remove_fold :: (buf: *Buffer, fold: *Fold) {
	buf.lines[fold.start].dirty_flags |= .MODS;
	array_ordered_remove_by_index(*buf.folds, fold - buf.folds.data);
}

Directory_File :: struct {
	last_name: string;
	Flags :: enum_flags {
		IMMUTABLE;
		NONE :: 0;
	}
	flags: Flags;
	is_marked_for_delete: int; // true if > 0
	is_new: bool = false; // actuall could have a last_name == ""
}

BUFFER_CHECKPOINT_NULL : Buffer_Checkpoint : -1;
CHECKPOINT_NULL : Buffer_Checkpoint : -1;

Buffer_Checkpoint :: #type,distinct int;

create_checkpoint :: (win: *Window) -> Buffer_Checkpoint {
	using win.buffer;
	if active_checkpoint != BUFFER_CHECKPOINT_NULL
		return BUFFER_CHECKPOINT_NULL;
	active_checkpoint = xx op_index;
	return active_checkpoint;
}

reset_checkpoint :: (win: *Window, checkpoint: Buffer_Checkpoint) {
	using win.buffer;
	assert(checkpoint != BUFFER_CHECKPOINT_NULL);
	assert(checkpoint == active_checkpoint);
	active_checkpoint = BUFFER_CHECKPOINT_NULL;
}

restore_checkpoint :: (win: *Window) {
	using win.buffer;
	if active_checkpoint != CHECKPOINT_NULL
		restore_checkpoint(win, active_checkpoint);
}

restore_checkpoint :: (win: *Window, checkpoint: Buffer_Checkpoint) {
	using win.buffer;
	assert(checkpoint != BUFFER_CHECKPOINT_NULL);
	assert(checkpoint == active_checkpoint);
	while xx checkpoint < op_index {
		ok := buffer_undo(win);
		assert(ok);
	}
	active_checkpoint = BUFFER_CHECKPOINT_NULL;
}

refresh_buffer :: (win: *Window) -> bool, string {
	buf := win.buffer;
	if is_dirty(buf)
		return false, "Can't refresh dirty";
	if buf.kind == {
		case .FILE;
			if !buf.path
				return false, "Can't refresh without filename";
			refresh_file_buffer(buf);
			return true, "";
		case .DIRECTORY;
			refresh_directory_buffer(buf);
			return true, "";
		case;
			return false, "Not a file (%)";
	}
}

save_buffer :: (buf: *Buffer) -> bool, string {
	if buf.kind == {
		case .FILE;
			if !buf.path
				return false, "Can't save without filename";
			if buf.file_flags & .READ_ONLY
				return false, "Can't save a read only file";
			s := buffer_as_string_for_saving(buf,, allocator=temp);
			edit_alert("Writing % bytes to '%'", s.count, buf.path);
			ok := write_entire_file(buf.path, s);
			if ok {
				buf.file_flags &= ~.NO_FILE; 
				clear_dirty(buf);
			}
			if !ok
				return false, "Failed to modify file";
			return true, "";
		case .DIRECTORY;
			if buf.directory_files_confirm_index >= 0 {
				return false, "Already saving";
			}
			if buf.windows.count == 0 {
				return false, "Man... no windows :(";
			}
			decode_filename :: (s: string) -> (ok: bool, name: string, is_directory: bool) {
				idx := find_index_from_left(s, "/");
				if idx >= 0 {
					if idx != s.count - 1
						return false, "", false;
					return true, slice(s, 0, s.count-1), true;
				} else {
					return true, s, false;
				}
			}
			Directory_Thing_Res :: struct {
				ok: bool;
				error_message: string;
				should_execute: bool; // if this has any modifications
				should_delete_line: bool; // only set if `request || execute`
				execute_request: string; // allocated in temp?
			}
			name_table: Table(string, void);
			name_table.allocator = temp;
			check_file_and_maybe_execute :: (f: *Directory_File, line: *Line,
					name_table: *Table(string, void) = null, base_path := "",
					$request := false, $execute: bool = false, recurse := false) -> Directory_Thing_Res {
				if line.as_string == "" {
					return .{
						ok = false,
						error_message = "Can't have empty filenames!"
					};
				}
				ok, name, is_dir := decode_filename(line.as_string);
				if !ok {
					return .{
						ok = false,
						error_message = tprint("Invalid name: '%'", line.as_string),
					};
				}
				if name_table {
					if table_find(name_table, name) {
						return .{ 
							ok = false,
							error_message = tprint("Dupe name: '%'", name),
						};
					}
					table_add(name_table, name, default_of(void));
				}
				if f.last_name != line.as_string {
					last_ok, last_name, last_is_dir := decode_filename(f.last_name);
					assert(last_ok);
					if !f.is_new && is_dir != last_is_dir {
						return .{
							ok = false,
							error_message = tprint("Don't mess with with directories ('%')", line.as_string),
						};
					}
					if name_table && !f.is_new {
						if table_find(name_table, last_name) {
							return .{
								ok = false,
								error_message = tprint("Dupe name (last): '%'", last_name),
							};
						}
						table_add(name_table, last_name, default_of(void));
					}
				}
				#assert !request || !execute; // can't do both!
				#if !request && !execute {
					return .{
						ok = true,
					};
				} else {
					if f.is_new && f.is_marked_for_delete {
						return .{
							ok = true,
							should_delete_line = true,
						};
					}
					file_or_dir := ifx is_dir then "dir" else "file";
					// can this be tprinted?
					full_path := path_join(base_path, name,, allocator=temp);
					if is_dir
						full_path = tprint("%/", full_path);
					last_full_path := path_join(base_path, f.last_name,, allocator=temp);
					if is_dir
						last_full_path = tprint("%/", last_full_path);
					if f.is_marked_for_delete {
						#if request {
							return .{
								ok = true,
								execute_request = tprint("Delete % '%'?", file_or_dir, last_full_path),
								should_delete_line = true,
							};
						} else {
							ok := true;
							if is_dir && recurse {
								// this is recursive
								ok = delete_directory(last_full_path);
							} else {
								ok = file_delete(last_full_path);
							}
							return .{
								ok = ok,
								should_delete_line = true,
							};
						}
					} else if f.is_new {
						#if request {
							return .{
								ok = true,
								execute_request = tprint("Create % '%'?", file_or_dir, full_path),
							};
						} else {
							ok := true;
							if is_dir {
								ok = make_directory_if_it_does_not_exist(full_path);
							} else {
								ok = write_entire_file(full_path, "");
							}
							return .{
								ok = ok,
							};
						}
					} else if f.last_name != line.as_string {
						#if request {
							return .{
								ok = true,
								execute_request = tprint("Rename % '%' -> '%'", file_or_dir, last_full_path, full_path),
							};
						} else {
							ok := file_move(last_full_path, full_path);
							return .{
								ok = ok,
							};
						}
					} else {
						return .{
							ok = true,
						};
					}
				}
			}
			for * buf.directory_files {
				line := *buf.lines[it_index];
				res := check_file_and_maybe_execute(it, line, *name_table);
				if !res.ok {
					return false, res.error_message;
				}
			}
			get_next_request :: (using buf: *Buffer, idx: int) -> int, string {
				while idx < directory_files.count {
					res := check_file_and_maybe_execute(*directory_files[idx], *lines[idx], base_path = path, request = true);
					assert(res.ok);
					if !res.execute_request {
						if res.should_delete_line {
							// Case where there's nothing to execute but data should be modified anyway..
							execute_buffer_operation(windows[0], .{
								kind = .ERASE_LINES,
								y = idx,
								count = 1,
								flags = .NO_CALLBACK | .NO_UNDO,
							});
							array_ordered_remove_by_index(*directory_files, idx);
							continue;
						}
						idx += 1;
						continue;
					}
					return idx, tprint("%: [y]es/[n]o/[r]ecurse", res.execute_request);
				}
				return directory_files.count, "";
			}
			execute_and_get_next_request :: (using buf: *Buffer, idx: int, recurse := false) -> int, string {
				res := check_file_and_maybe_execute(*directory_files[idx], *lines[idx], base_path = path, execute = true, recurse = recurse);
				if !res.ok {
					edit_alert("File op for '%' failed: %", lines[idx].as_string, res.error_message);
					return directory_files.count, "";
				}
				if res.should_delete_line {
					execute_buffer_operation(windows[0], .{
						kind = .ERASE_LINES,
						y = idx,
						count = 1,
						flags = .NO_CALLBACK | .NO_UNDO,
					});
					array_ordered_remove_by_index(*directory_files, idx);
				} else {
					execute_buffer_operation(windows[0], .{
						kind = .NOP,
						flags = .NO_CALLBACK | .NO_UNDO,
					});
					assert(!directory_files[idx].is_marked_for_delete);
					// unnecessary copy
					directory_files[idx].last_name = copy_string(lines[idx].as_string,, allocator=allocator_of(buf));
					directory_files[idx].is_new = false;
					idx += 1;
				}
				new_idx, req := get_next_request(buf, idx);
				return new_idx, req;
			}
			maybe_clear_dirty :: (buf: *Buffer) {
				idx := get_next_request(buf, 0,, allocator=temp);
				if idx >= buf.directory_files.count
					clear_dirty(buf);
			}
			//
			idx, req := get_next_request(buf, 0);
			if idx == buf.directory_files.count {
				clear_dirty(buf);
				return true, ""; // actually, clear dirty here if needed !
			}
			hold(buf);
			buf.directory_files_confirm_index = idx;
			ask_for_char(req, (ch: s32, _buf: *void) -> bool, string {
				buf := _buf.(*Buffer);
				ret: bool;
				msg: string;
				if ch == {
					case 0;
						ret = false;
					case #char "n";
						new_idx, new_msg := get_next_request(buf, buf.directory_files_confirm_index+1);
						if new_idx >= buf.directory_files.count {
							ret = false;
						} else {
							ret = true;
							buf.directory_files_confirm_index = new_idx;
							msg = new_msg;
						}
					case #char "r"; // recursive
						new_idx, new_msg := execute_and_get_next_request(buf, buf.directory_files_confirm_index, recurse = true);
						if new_idx >= buf.directory_files.count {
							maybe_clear_dirty(buf);
							ret = false;
						} else {
							ret = true;
							buf.directory_files_confirm_index = new_idx;
							msg = new_msg;
						}
					case #char "y";
						new_idx, new_msg := execute_and_get_next_request(buf, buf.directory_files_confirm_index);
						if new_idx >= buf.directory_files.count {
							maybe_clear_dirty(buf);
							ret = false;
						} else {
							ret = true;
							buf.directory_files_confirm_index = new_idx;
							msg = new_msg;
						}
					case;
						ret = true;
						edit_warn("Bad char");
				}
				if !ret {
					release(buf);
					buf.directory_files_confirm_index = -1;
				}
				return ret, msg;
			}, buf);
			return true, "";
		case;
			return false, "Not a file (%)";
	}
}

// this should never fail, i think, even in the future?
get_current_buffer :: () -> *Buffer {
	win := get_selected_window_of_kind(.BUFFER);
	//assert(win != null);
	return win.buffer;
}

buffer_as_string_for_saving :: (using buf: *Buffer) -> string {
	chars: [..]u8;
	for buf.lines {
		array_add(*chars, .. it.chars);
		if it_index + 1 != buf.lines.count {
			if buf.file_flags & .CLRF
				array_add(*chars, "\r");
			array_add(*chars, "\n");
		}
	}
	return cast(string)chars;
}

buffer_as_string :: (using buf: *Buffer) -> string {
	chars: [..]u8;
	for buf {
		array_add(*chars, it);
	}
	return cast(string)chars;
}

// this is probably slow !
for_expansion :: (using buffer: *Buffer, body: Code, for_flags: For_Flags) #expand {
	#assert for_flags == 0;
	`it_index: Position = ---;
	`it: u8 = ---;
	for line, y: lines {
		for ch, x: line.chars {
			`it_index = Position.{ x, y};
			`it = ch;
			#insert(break = break line, remove=#assert false) body;
		}
		// @CompilerBug (need to declare it stuff at the begining of this..
		{
			`it_index = Position.{ line.chars.count, y };
			`it = #char "\n";
			#insert(break = break line, remove=#assert false) body;
		}
	}
}

// Maybe have a separate file for operations??

Buffer_Op :: struct {
	Flags :: enum_flags {
		NO_UNDO; // cannot be undone (rn just used by directory)
		NO_CALLBACK; // 
		IGNORE_CAPS; // (handled by _) execute even if capabilities disallow it
		IS_UNDO; // this is info for callbacks
		// This shit is very specific:
		// (this still saves stuff like cursor position..)
		DO_NOT_EXECUTE_BUT_CONSIDER_EXECUTED; // (handled by _)
		CALLBACK_BEFORE_UNDO_AND_REDO;
		NONE :: 0;
	}
	Kind :: enum {
		NONE :: 0;
		// delete operations:
		ERASE_LINES;
		ERASE_CHARS;
		MERGE_LINES; // 2 lines
		// insert operations:
		INSERT_LINES;
		INSERT_CHARS;
		SPLIT_LINE;
		NOP;
	}
	kind: Kind;
	flags: Flags;
	y: int; // on what line this happened
	x: int; // on what x this happened (if char or split operation) 
	count: int; // if delete, otherwise should match chars/lines
	// these 2 are populated by query if insert, and populated by executing the operation if delete
	chars: []u8; // if delete/insert chars
	lines: []string; // if delete/insert lines
	begin_cursor_position: Position; // where cursor was when this was executed
	begin_time: Editime;
	begin_mode: Edit_Mode;
}

set_dirty :: (buf: *Buffer) {
	buf.save_op_index = -1;
}

clear_dirty :: (buf: *Buffer) {
	buf.save_op_index = buf.op_index;
}

is_dirty :: (buf: *Buffer) -> bool {
	return buf.save_op_index != buf.op_index;
}

allocator_of :: (buf: *Buffer) -> Allocator {
	return .{pool_allocator_proc, *buf.pool};
}

buffer_undo :: (win: *Window) -> bool {
	reverse_operation :: inline (op: *Buffer_Op) -> bool {
		assert(op.flags & .IS_UNDO == 0); // sanity check, there's a lot to mess up here
		op.flags |= .IS_UNDO;
		if op.kind == {
			case .NOP; //
			case .ERASE_LINES;
				op.kind = .INSERT_LINES;
			case .INSERT_LINES;
				op.kind = .ERASE_LINES;
			//
			case .ERASE_CHARS;
				op.kind = .INSERT_CHARS;
			case .INSERT_CHARS;
				op.kind = .ERASE_CHARS;
			//
			case .SPLIT_LINE;
				op.kind = .MERGE_LINES;
				op.count = 1;
			case .MERGE_LINES;
				assert(op.count == 1);
				op.kind = .SPLIT_LINE;
			case;
				return false;
		}
		return true;
	}
	using buf: *Buffer = win.buffer;
	if op_index <= 0
		return false;
	if active_checkpoint != BUFFER_CHECKPOINT_NULL && xx active_checkpoint >= op_index {
		return false;
	}
	op := buf.ops[buf.op_index-1];
	if op.flags & .NO_UNDO {
		return false;
	}
	if !reverse_operation(*op) {
		edit_alert("Can't undo? %\n", op.kind, is_internal = true);
		return false; // this is a panic
	}
	ok := true;
	if ok && (op.flags & .NO_CALLBACK == 0) && (op.flags &.CALLBACK_BEFORE_UNDO_AND_REDO) {
		if win.buffer.modify_buffer_operation
			ok = win.buffer.modify_buffer_operation(win, buf, *op);
	}
	if ok
		ok = _execute_buffer_operation(win, buf, *op, update_cursor = true);
	if ok {
		buf.op_index -= 1;
		assert(buf.op_index >= 0);
	}
	return ok;
}

buffer_redo :: (win: *Window) -> bool {
	using buf: *Buffer = win.buffer;
	if op_index >= ops.count
		return false;
	op := buf.ops[buf.op_index];
	ok := true;
	if ok && (op.flags & .NO_CALLBACK == 0) && (op.flags &.CALLBACK_BEFORE_UNDO_AND_REDO) {
		if win.buffer.modify_buffer_operation
			ok = win.buffer.modify_buffer_operation(win, buf, *op);
	}
	if ok
		ok = _execute_buffer_operation(win, buf, *op, update_cursor = true);
	if ok {
		op_index += 1;
	}
	return ok;
}

execute_buffer_operation :: (win: *Window, op: Buffer_Op) -> bool {
	assert(win != null);
	return execute_buffer_operation(win, win.buffer, op);
}

// buffer operation THROUGH window
// This is the only one that respects the callback?
// window could be null here
execute_buffer_operation :: (win: *Window, using buf: *Buffer, _op: Buffer_Op) -> bool {
	allocator := Allocator.{pool_allocator_proc, *buf.pool};
	op := _op;
	ok: bool = true;
	if ok {
		if op.kind == .INSERT_CHARS {
			op.chars = array_copy(op.chars,, allocator);
		} else if op.kind == .INSERT_LINES {
			lines: [..]string;
			lines.allocator = allocator_of(buf);
			//array_reserve(*lines, op.lines.count);
			for op.lines {
				//log("looking for error in op lines (%/%)", it_index, op.lines.count);
				array_add(*lines, copy_string(it));
			}
			op.lines = lines;
		}
	}
	// TODO: check i need parenths here
	if ok && (op.flags & .NO_CALLBACK == 0) {
		// this doesn't have to return a bool, instead it could modify it to a nop !
		if buf.modify_buffer_operation
			ok = buf.modify_buffer_operation(win, buf, *op);
	}
	if ok {
		// it's actually scary to pass the allocator here, incase some callback happens?
		ok = _execute_buffer_operation(win, buf, *op, fill_for_undo = true,, allocator);
	}
	if ok {
		assert(buf.op_index <= ops.count);
		//log("looking for error in ops % %", buf.op_index, ops.count); // <- here
		ops.count = buf.op_index; 
		array_add(*ops, op);
		//log("done looking for error in ops"); // <- here
		op_index += 1;
		if save_op_index > ops.count
			set_dirty(buf);
	}
	return ok;
}

// leak? (?)
// The only time this touches `win` instead of just its buffer, is when move_cursor is true !!!
_execute_buffer_operation :: (win: *Window, using,except(flags) buf: *Buffer, op: *Buffer_Op,
			fill_for_undo := false, update_cursor := false) -> bool {
	if op.flags & .IGNORE_CAPS == 0 {
		if op.kind == {
			case .NOP; //
			case .INSERT_CHARS;
				if caps & .INSERT_CHARS == 0
					return false;
			case .INSERT_LINES; #through;
			case .SPLIT_LINE;
				if caps & .INSERT_LINES == 0
					return false;
			case .ERASE_CHARS;
				if caps & .ERASE_CHARS == 0
					return false;
			case .ERASE_LINES; #through;
			case .MERGE_LINES;
				if caps & .ERASE_LINES == 0
					return false;
			case;
				log_error("whoops, forgor %\n", op.kind);
		}
	}
	if fill_for_undo {
		// only place where cursor is used..
		if win != null {
			op.begin_cursor_position = win.cursor.position;
		} else {
			op.begin_cursor_position = .{0, 0}; // should mark this as none or something??
		}
		op.begin_mode = context.edit.mode;
		op.begin_time = context.edit.time;
	}
	defer {
		if win != null {
			if update_cursor {
				move_cursor(win, op.begin_cursor_position);
			}
		}
		buf.modify_time = context.edit.time;
		for buf.windows {
			// Mark x might get out of bounds..
			// But if it gets normalized, then undo will be overly complicated.
			// The solution now is to not take marks at face value.
			//
			// Undo messing it up it still a problem, when the line it's on gets deleted.
			//
			//normalize_marks(it);
			normalize_cursor(it, with_scroll = true); 
		}
	}
	//normalize_buffer_operation(buf, op);
	assert(op.count >= 0);
	assert(op.y >= 0);
	assert(op.x >= 0, "% %", op.x, op.count);
	if fill_for_undo {
		if op.kind == {
			case .ERASE_CHARS;
				assert(op.chars.count == 0);
				line := *lines[op.y];
				op.chars = array_copy([]u8.{ data = line.chars.data + op.x, count = op.count },, allocator=allocator_of(buf));
			case .MERGE_LINES;
				op.x = lines[op.y].count;
			case .ERASE_LINES;
				assert(op.lines.count == 0);
				lines: [..]string; // alloc here too
				lines.allocator = allocator_of(buf);
				for op.y..op.y+op.count-1 {
					array_add(*lines, copy_string(cast(string)buf.lines[it].chars),, allocator=allocator_of(buf));
				}
				op.lines = lines;
		}
	}
	if op.flags & .DO_NOT_EXECUTE_BUT_CONSIDER_EXECUTED {
		return true;
	}
	_shift_x :: (it: *Position, pos: Position, count: int, moved_real_x: *bool) {
		if pos.y == it.y {
			if count > 0 {
				if it.x >= pos.x {
					it.x += count;
					if moved_real_x
						moved_real_x.* = true;
				}
			} else {
				if it.x > pos.x {
					it.x -= min(-count, it.x - pos.x);
					if moved_real_x
						moved_real_x.* = true;
				}
			}
		}
	}
	_shift_y :: (it: *Position, pos: Position, count: int, moved_line_y: *bool) {
		if count > 0 {
			is_after: bool = ---;
			if true
				is_after = it >= pos;
			else
				is_after = it.y > pos.y;
			if is_after
				it.y += count;
		} else if count < 0 {
			//moved_line_y &&= (it.y -y) <= (-count);
			// ^ some ass logic
			y := pos.y; // if shifting back, x doesn't matter?
			if y < it.y {
				it.y -= min(-count, it.y - y);
			}
			if it.y == y {
				// THINK: moved_line_y
				// calls update_from_cursor_virtual_x(it) ??
				//
				// The line that the cursor is on has changed.
				// More specifically, the characters before the cursor are different.
				// (the ones after the cursor are unimportant)
				if moved_line_y
					moved_line_y.* = true;
				// Though i still haven't wrapped my head aroung this so, let it be ignored...
			}
		}
	}
	shift_y :: (y: int, count: int) #expand {
		shift_y(.{0, y}, count);
	}
	shift_y :: (pos: Position, count: int, dont_update_from_virtual_x := false) #expand {
		if buf.caps & .MOVE_Y == 0
			return;
		for * buf.marks {
			_shift_y(*it.position, pos, count, null);
		}
		for * buf.folds {
			if it.start > pos.y {
				it.start += count;
			}
			if it.end > pos.y {
				it.end += count;
			}
		}
		for buf.windows {
			moved_line_y: bool = false;
			_shift_y(*it.cursor.position, pos, count, *moved_line_y);
			if moved_line_y {
				if !dont_update_from_virtual_x {
					update_from_cursor_virtual_x(it);
				}
			}
		}
	}
	shift_x :: (pos: Position, count: int, dont_refresh_virtual_x := false) #expand {
		if buf.caps & .MOVE_X == 0
			return;
		for * buf.marks {
			_shift_x(*it.position, pos, count, null);
		}
		for buf.windows {
			moved_real_x := false;
			_shift_x(*it.cursor.position, pos, count, *moved_real_x);
			if moved_real_x {
				if !dont_refresh_virtual_x
					refresh_cursor_virtual_x(it);
			}
		}
	}
	if op.kind == {
		case .NOP; //
		case .INSERT_CHARS;
			assert(op.count == op.chars.count);
			line: *Line = *lines[op.y];
			assert(op.x <= line.count, "%", op.x, line.count);
			for op.chars {
				x := op.x + it_index;
				array_insert_at(*line.chars, it, x);
			}
			shift_x(.{op.x, op.y}, op.chars.count);
			line.dirty_flags |= .ALL;
		case .ERASE_CHARS;
			// slow
			line := *lines[op.y];
			assert(op.x + op.count <= line.count);
			for < op.x..op.x+op.count-1 {
				array_ordered_remove_by_index(*line.chars, it);
			}
			shift_x(.{ op.x, op.y }, -op.count);
			line.dirty_flags |= .ALL;
		case .SPLIT_LINE;
			assert(op.y < lines.count);
			assert(op.x <= lines[op.y].count);
			new_line: *Line = array_insert_at(*lines, op.y+1);
			new_line.chars.allocator = allocator_of(buf);
			curr_line: *Line = *lines[op.y];
			array_add(*new_line.chars, .. advance(curr_line.chars, op.x));
			curr_line.chars.count = op.x;
			// this messes up but whatever rn
			shift_y(.{op.x, op.y}, 1, dont_update_from_virtual_x = false);
			shift_x(.{0, op.y+1}, -curr_line.count);
			new_line.dirty_flags |= .ALL;
			curr_line.dirty_flags |= .ALL;
		case .MERGE_LINES;
			assert(op.y + 1 < lines.count);
			assert(op.count == 1);
			line: *Line = *lines[op.y];
			line_len := line.count;
			next_line: *Line = *lines[op.y+1];
			array_add(*line.chars, .. next_line.chars);
			array_ordered_remove_by_index(*lines, op.y+1); 
			shift_x(.{0, op.y+1 }, line_len, dont_refresh_virtual_x = true);
			shift_y(.{0, op.y}, -1, dont_update_from_virtual_x = true);
			line.dirty_flags |= .ALL;
		case .INSERT_LINES;
			assert(op.lines.count == op.count);
			lines_to_insert: [..]Line;
			lines_to_insert.allocator = temp;
			array_reserve(*lines_to_insert, op.lines.count);
			for op.lines {
				line: Line; // dirty flags already all !
				line.chars.allocator = allocator_of(buf);
				array_add(*line.chars, .. cast([]u8)it); 
				array_add(*lines_to_insert, line);
				//y := op.y + it_index;
				//array_insert_at(*lines, line, y);
			}
			array_insert_range_at(*lines, op.y, lines_to_insert);
			shift_y(op.y, op.lines.count); // this isn't tested for non undos
		case .ERASE_LINES;
			assert(op.y + op.count <= lines.count);
			array_ordered_remove_range(*lines, op.y, op.count);
			shift_count := op.count;
			shift_y_val := op.y;
			if op.y == lines.count
				shift_y_val -= 1;
			shift_y(shift_y_val, -shift_count);
			// TODO: this should be handled differently !!
			assert(lines.count != 0, "you shouldve handled this !!!");
		case;
			log("unsupported op: %\n", op.kind);
	}
	return true;
}

replace_buffer_lines_without_caps :: (win: *Window, new_lines: []string, extra_flags: Buffer_Op.Flags = .NONE) {
	assert(win != null);
	replace_buffer_lines_without_caps(win, win.buffer, new_lines, extra_flags);
}

replace_buffer_lines_without_caps :: (win: *Window, using,except(flags) buf: *Buffer, new_lines: []string, extra_flags: Buffer_Op.Flags = .NONE) {
	cursor_pos: Position;
	if win != null
		cursor_pos = win.cursor.position;
	flags := extra_flags | .IGNORE_CAPS;
	execute_buffer_operation(win, buf, .{
		kind = .INSERT_LINES,
		y = lines.count,
		count = new_lines.count,
		lines = new_lines,
		flags = flags,
	});
	if new_lines.count == 0 {
		execute_buffer_operation(win, buf, .{
			kind = .INSERT_LINES,
			y = lines.count,
			count = 1,
			lines = .[ "" ],
			flags = flags,
		});
	}
	execute_buffer_operation(win, buf, .{
		kind = .ERASE_LINES,
		y = 0,
		count = lines.count - max(new_lines.count, 1),
		flags = flags,
	});
	if win != null
		move_cursor(win, cursor_pos); // this normalizes it too
}

peek_last_operation :: (using buf: *Buffer) -> bool, Buffer_Op {
	if op_index > 0
		return true, ops[op_index-1];
	return false, .{};
}

peek_next_operation :: (using buf: *Buffer) -> bool, Buffer_Op {
	if op_index < ops.count
		return true, ops[op_index];
	return false, .{};
}

//
is_position_in_buffer :: (using buf: *Buffer, pos: Position) -> bool {
	if pos.y >= lines.count {
		return false;
	}
	line := *lines[pos.y];
	if pos.x > line.count {
		return false;
	}
	return true;
}

apply_syntax_mods :: (line: *Line, syntax: *Syntax, line_no_hint := -1, first_x := 0,
			multiline_syntax_index := -1) {
	#if 1 {
		apply_syntax_mods_differently(line, syntax, line_no_hint, first_x, multiline_syntax_index);
		return;
	}
	using,only(mods) line;
	idx := first_x;
	for 1..20 {
		string_to_match := advance(line.as_string, idx);
		matched, captures := Uniform.match(string_to_match, syntax.regex, .UNANCHORED,, allocator=temp);
		//matched, captures := Uniform.match(string_to_match, syntax.regex, .AN,, allocator=temp);
		if !matched
			break;
		// captures[0] = full
		// captures[1] = suffix + value + prefix
		// captures[2] = value
		// whichever captures[3..3+COUNT] = value
		// ^ this is wrong..
		start_capture := captures[1];
		something_capture := captures[2];
		//color := ifx captures[3].count then syntax.kw_color1 else syntax.kw_color2;
		syntax_element: Syntax_Element = syntax.elements[xx Syntax_Element.Kind.DEFAULT];
		for advance(captures, 3) {
			if it != "" {
				something_capture = it;
				syntax_element = syntax.elements[it_index];
				if it_index == xx Syntax_Element.Kind.EOL_SPACE
					log("Found syntax % %\n", line_no_hint, cast(Syntax_Element.Kind)it_index);
				break;
			}
		}
		//color := syntax.elements[0].color;
		capture_offset := something_capture.data - string_to_match.data;
		idx += capture_offset;
		for 0..something_capture.count-1 {
			using syntax_element;
			if idx + it < mods.count {
				mod := *mods[idx+it];
				mod.fg = color;
				#if 0 {
					if replace.count > 0 {
						mod.replaced = string.{ data = *replace[it%replace.count], count = 1 };
					}
				}
			}
		}
		idx += something_capture.count;
		if it > 15 { //
			log_error("kept matching at line % (%)\n", line_no_hint, idx);
		}
	}
}

apply_syntax_mods_differently :: (line: *Line, syntax: *Syntax, line_no_hint := -1, first_x := 0,
			multiline_syntax_index := -1) {
	using,only(mods) line;
	Here_Match :: struct {
		position: int; // start of the actual match
		start: int;
		end: int;
		tried_match: bool = false;
	}
	matches: [Syntax_Element.COUNT]Here_Match;
	idx := first_x;
	line.start_multiline_syntax_index = multiline_syntax_index;
	defer {
		line.multiline_syntax_index = multiline_syntax_index;
	}
	for 1..20 {
		if idx >= line.count
			break;
		string_to_match := advance(line.as_string, idx);
		best_position := line.count;
		match_index: int = -1;
		if multiline_syntax_index >= 0 {
			elem := *syntax.elements[multiline_syntax_index];
			ok, captures := Uniform.match(string_to_match, elem.multiline_end_regex, .UNANCHORED,, allocator=temp);
			next_idx := line.count;
			if ok {
				next_idx = (captures[0].data - line.chars.data) + captures[0].count;
			}
			for idx..next_idx-1 {
				if it >= line.mods.count
					break;
				mod := *mods[it];
				mod.fg = elem.color;
			}
			if ok {
				multiline_syntax_index = -1;
				idx = next_idx;
				continue;
			} else {
				break;
			}
		}
		for syntax.elements {
			if !it.is_compiled
				continue;
			// super specific thing optimization:
			if best_position == idx
				break;
			match := *matches[it_index];
			if !match.tried_match || match.position < idx {
				match.tried_match = true;
				if it.match_kind == .NORMAL {
					ok, captures := Uniform.match(string_to_match, it.regex, .UNANCHORED,, allocator=temp);
					if ok {
						match.position = captures[0].data - line.chars.data;
						match.start = captures[1].data - line.chars.data;
						match.end = match.start + captures[1].count - 1;
					} else {
						match.position = line.count;
					}
				} else if it.match_kind == .MULTILINE_START_END {
					ok, captures := Uniform.match(string_to_match, it.multiline_start_regex, .UNANCHORED,, allocator=temp);
					if ok {
						// multiline doesn't have any prefix/suffix shit
						match.position = captures[0].data - line.chars.data;
						match.start = captures[0].data - line.chars.data;
						match.end = match.start + captures[0].count - 1;
					} else {
						match.position = line.count;
					}
				}
			}
			if match.position < best_position {
				best_position = match.position;
				match_index = it_index;
			}
		}
		if best_position >= line.count
			break;
		m := *matches[match_index];
		elem := *syntax.elements[match_index];
		for m.start..m.end {
			if it >= line.mods.count
				break;
			mod := *mods[it];
			mod.fg = elem.color;
		}
		idx = m.end + 1;
		if elem.match_kind == .MULTILINE_START_END {
			multiline_syntax_index = match_index;
		}
		if it > 15 {
			log_error("(2) kept matching at line % (%)\n", line_no_hint, idx);
		}
	}
}

change_syntax :: (buf: *Buffer, syntax: *Syntax) {
	if buf.syntax == syntax
		return;
	buf.syntax = syntax;
	for * buf.lines
		it.dirty_flags |= .MODS | .USER_ALL;
}

// It takes a window on which the buffer will be drawn to.
// Maybe should organize this better (user_mods should belong to window?? that seems too much).
// [ly, ry)
_refresh_buffer_modifiers :: (win: *Window, using buf: *Buffer, ly: int, ry: int) {
	time_this("Refresh buffer modifiers");
	assert(ry <= lines.count);
	#if 0 {
		lines_to_refresh := []Line.{ data = lines.data + ly, count = ry - ly };
	} else {
		// Since we're using multiline syntax stuff, we need to refresh all lines up to this one
		//lines_to_refresh := []Line.{ data = lines.data, count = ry };
		// But let's not be too slow.
		actual_ly := max(0, ry - 100);
		actual_ly = clamp(ry - 100, 0, ly);
		lines_to_refresh := []Line.{ data = lines.data + actual_ly, count = ry - actual_ly };
	}
	maybe_update_search_matches(win); // makes sure search replace is ok
	for * lines_to_refresh {
		y := it - buf.lines.data;
		//assert (it.count <= mods.count, "%", it.count);
		multiline_syntax_index := ifx it_index == 0 then -1 else lines_to_refresh[it_index-1].multiline_syntax_index;
		if it.start_multiline_syntax_index != multiline_syntax_index
			it.dirty_flags |= .MODS;
		if (it.dirty_flags & .MODS) {
			for * it.mods {
				it.* = .{};
				it.fg = syntax.normal_color;
			}
			if syntax.is_compiled
				apply_syntax_mods(it, syntax, line_no_hint = y, first_x = 0, multiline_syntax_index = multiline_syntax_index);
			{
				fold := get_fold_exact(buf, y);
				if fold {
					for * it.mods {
						it.bg = 4;
					}
				}
			}
			it.dirty_flags &= ~.MODS;
		}
		it.user_mods = it.mods;
		// should have a limit here i think?
		idx := 0;
	}
	do_some_extra_stuff_to_the_buffer_colors(win);
}

// not sure how i wanna use this buffer char info yet..

Buffer_Char_Info :: struct {
	size: int = 1;
	replaced: string; // 
}

_get_char_info :: (ch: u8) -> Buffer_Char_Info {
	if ch == {
		case "\r";
			return .{
				size = 2,
				replaced = "@r",
			};
		case 0;
			return .{
				size = 2,
				replaced = "@n",
			};
		case "\t";
			return .{
				size = 4,
				replaced = ">---",
			};
	}
	// defaults:
	return .{};
}

#scope_file

#import "Math";
#import "File";
#import "Hash_Table";
#import "File_Utilities";
#import "System";