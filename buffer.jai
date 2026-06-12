
Line :: struct {
	chars: [..]u8;
	#overlay(chars.count) count: int;
	#overlay(chars) as_string: string;
	//
	mods: [1024]Char_Mod = ---; // A LOT !
	user_mods: [1024]Char_Mod = ---;
	Dirty_Flags :: enum_flags {
		MODS; 
		NONE :: 0;
		ALL :: MODS;
	}
	dirty_flags: Dirty_Flags = .ALL;
	//
}

// hm...
Char_Mod :: struct {
	bg_color: s32 = -1;
	#overlay(bg_color) bg: s32;
	fg_color: s32 = -1;
	#overlay(fg_color) fg: s32;
	attributes: s32;
	// there might be reasons why i'd want this as a strong..
	// syntax real_x doesn't respect this !
	replaced: string; // count <= 1
}

as_ncurses_attribute :: (mod: Char_Mod) -> s32 {
	col := color_fg_bg(mod.fg, mod.bg);
	ret: s32 = 0;
	ret |= COLOR_PAIR(col);
	ret |= mod.attributes;
	//ret |= A_BOLD;
	return ret;
}

BufId :: #type,distinct s64;
BUF_ID_NULL :: 0;
_running_buffer_id: BufId = 1;

next_buffer_id :: () -> BufId {
	ret := _running_buffer_id;
	_running_buffer_id += 1;
	return ret;
}


// For now, buffer operations must be executed within a window..
// Not sure if i'll want to change that, but might be difficult!
Buffer :: struct {
	Kind :: enum {
		NONE :: 0;
		FILE;
		CUSTOM;
	}
	File_Flags :: enum_flags {
		NO_FILE; // failed to read
		READ_ONLY; // not implemented
		NONE :: 0;
	}
	// capabilities
	Caps :: enum_flags {
		INSERT_CHARS;
		INSERT_LINES;
		DELETE_CHARS; // should rename this to erase...
		DELETE_LINES; // should rename this to erase...
		// Move is (mostly) not implemented, not sure if i even wanna do it like this..
		MOVE_X;
		MOVE_Y;
		//
		MODE_INSERT;
		MODE_COMMAND;
		// Aliases:
		ERASE_CHARS :: DELETE_CHARS;
		ERASE_LINES :: DELETE_LINES;
		INSERT :: INSERT_CHARS | INSERT_LINES;
		DELETE :: DELETE_CHARS | DELETE_LINES;
		MOVE :: MOVE_X | MOVE_Y;
		MODE_ALL :: MODE_INSERT | MODE_COMMAND;
		ALL :: INSERT | DELETE | MOVE | MODE_INSERT | MODE_COMMAND;
		NONE :: 0;
	}
	Flags :: enum_flags {
		NO_SEARCH;
		TEMP; // destroy when windows stop referencing it !
		NONE :: 0;
	}
	flags: Flags;
	id: BufId = BUF_ID_NULL;
	kind: Kind = .NONE;
	caps: Caps = .NONE;
	lines: [..]Line;
	is_dirty: bool = false; // i dont know what this means..
	operations: [..]Buffer_Op; // this array shouldn't get touched outside execute_buffer_operation
	operation_index: int = -1; // index of last operation that was done, or -1
	modify_time: Editime; // when the last modifying operation happened?
	windows: [..]*Window; // doing it like this for now..
	commands: [..]Command; // can only be added to after buffer creation
	insert_commands: [..]Command; // these are all assumed to be of length 1!!!
	search_matches: Search_Matches; // touched by search..
	marks: [..]Mark;
	// file
	filename: string;
	file_flags: File_Flags;
	syntax: Syntax;
	// extra stuff
	user_data: *void; // @Leak
	modify_buffer_operation: #type (*Window, *Buffer_Op) -> bool;
}

find_or_create_file_buffer :: (_filename: string) -> *Buffer {
	filename := _filename;
	if filename {
		filename = _normalize_path(filename,, allocator=temp);
		if is_directory(filename) {
			// TODO: idk fix shit
			assert(false, "Trying to open directory (% -> %)...", _filename, filename);
		}
		for context.edit.buffers {
			if it.filename == filename
				return it;
		}
	}
	filename = copy_string(filename);
	buf := _create_buffer_from_filename(copy_string(filename));
	return buf;
}

get_file_buffer :: find_or_create_file_buffer;

// find implies that it might return null
find_buffer :: (id: BufId) -> *Buffer {
	for context.edit.buffers {
		if it.id == id
			return it;
	}
	return null;
}

destroy_buffer :: (buffer: *Buffer) {
	assert(buffer.windows.count == 0);
	ok := array_ordered_remove_by_value(*context.edit.buffers, buffer);
	assert(ok);
	array_reset(*buffer.commands);
	array_reset(*buffer.insert_commands);
	array_reset(*buffer.marks);
	array_reset(*buffer.operations); // @Leak
	array_reset(*buffer.lines); // @Leak
	free(buffer);
}

// this should never fail, i think, even in the future?
get_current_buffer :: () -> *Buffer {
	win := get_selected_window_of_kind(.BUFFER);
	//assert(win != null);
	return win.buffer;
}

// this doesn't have lines, so it'll crash if u dont add any
create_custom_buffer :: () -> *Buffer {
	buf := New(Buffer);
	buf.id = next_buffer_id();
	array_add(*context.edit.buffers, buf);
	buf.kind = .CUSTOM;
	array_add(*buf.lines);
	//buf.syntax = get_jai_syntax(); // TODO: don't duplicate this!!
	return buf;
}

_create_buffer_from_filename :: (filename: string) -> *Buffer {
	time_this("Create buffer");
	buf := New(Buffer);
	buf.id = next_buffer_id();
	array_add(*context.edit.buffers, buf);
	buf.caps = .ALL;
	buf.kind = .FILE;
	buf.filename = filename;
	//refresh_buffer_size(*buf); // from LINES, COLS
	array_add(*buf.lines, .{});
	buf.syntax = get_jai_syntax(); // TODO: don't duplicate this!!
	file_str: string;
	file_ok: bool = false;
	if filename {
		file_str, file_ok = read_entire_file(filename);
	}
	if file_ok {
		string_lines: []string = split(file_str, #char "\n",, allocator=temp);
		if string_lines.count > 0 && peek(string_lines) == ""
			string_lines.count -= 1;
		for string_lines {
			array_adds(*peek_pointer(buf.lines).chars, it);
			if it_index + 1 != string_lines.count
				array_add(*buf.lines, .{});
		}
	} else {
		buf.file_flags |= .NO_FILE;
	}
	return buf;
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

Buffer_Op :: struct {
	Flags :: enum_flags {
		NO_UNDO; // cannot be undone (opening a file)
		NONE :: 0;
	}
	Kind :: enum {
		NONE :: 0;
		// delete operations:
		DELETE_LINES;
		DELETE_CHARS;
		MERGE_LINES; // 2 lines
		// insert operations:
		INSERT_LINES;
		INSERT_CHARS;
		SPLIT_LINE;
		ERASE_CHARS :: DELETE_CHARS;
		ERASE_LINES :: DELETE_LINES;
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

Execute_Buffer_Op_Flags :: enum_flags {
	FILL_FOR_REVERSE;
	MOVE_CURSOR;
	NONE :: 0;
}

// buffer operation THROUGH window
// This is the only one that respects the callback?
execute_buffer_operation :: (win: *Window, _op: Buffer_Op, even_if_no_caps := false, no_callback := false) -> bool {
	op := _op;
	if op.kind == .INSERT_CHARS {
		op.chars = array_copy(op.chars);
	}
	using buf: *Buffer = win.buffer;
	ok: bool = true;
	if ok && buf.modify_buffer_operation && !no_callback {
		ok = buf.modify_buffer_operation(win, *op);
	}
	if ok {
		ok = _execute_buffer_operation(win, buf, *op, .FILL_FOR_REVERSE, even_if_no_caps = even_if_no_caps);
	}
	if ok {
		assert(buf.operation_index < operations.count);
		operation_index += 1;
		operations.count = buf.operation_index; // @Leak
		array_add(*operations, op);
	}
	return ok;
}

// leak? (?)
// The only time this touches `win` instead of just its buffer, is when .MOVE_CURSOR flag is true !!!
_execute_buffer_operation :: (win: *Window, using,except(flags) buf: *Buffer, op: *Buffer_Op, flags: Execute_Buffer_Op_Flags, even_if_no_caps := false) -> bool {
	if !even_if_no_caps {
		if op.kind == {
			case .INSERT_CHARS;
				if caps & .INSERT_CHARS == 0
					return false;
			case .INSERT_LINES; #through;
			case .SPLIT_LINE;
				if caps & .INSERT_LINES == 0
					return false;
			case .DELETE_CHARS;
				if caps & .DELETE_CHARS == 0
					return false;
			case .DELETE_LINES; #through;
			case .MERGE_LINES;
				if caps & .DELETE_LINES == 0
					return false;
			case;
				log_error("whoops, forgor %\n", op.kind);
		}
	}
	using,only(cursor) win;
	if flags & .FILL_FOR_REVERSE {
		op.begin_cursor_position = cursor.position;
		op.begin_mode = context.edit.mode;
		op.begin_time = context.edit.time;
	}
	defer {
		if flags & .MOVE_CURSOR {
			move_cursor(win, op.begin_cursor_position);
		}
		buf.modify_time = context.edit.time;
		buf.is_dirty = true;
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
	shift_y :: (pos: Position, count: int) #expand {
		if buf.caps & .MOVE_Y == 0
			return;
		for * buf.marks {
			_shift_y(*it.position, pos, count, null);
		}
		for buf.windows {
			moved_line_y: bool = false;
			_shift_y(*it.cursor.position, pos, count, *moved_line_y);
			if moved_line_y {
				update_from_cursor_virtual_x(it);
			}
		}
	}
	shift_x :: (pos: Position, count: int) #expand {
		if buf.caps & .MOVE_X == 0
			return;
		for * buf.marks {
			_shift_x(*it.position, pos, count, null);
		}
		for buf.windows {
			moved_real_x := false;
			_shift_x(*it.cursor.position, pos, count, *moved_real_x);
			if moved_real_x
				refresh_cursor_virtual_x(it);
		}
	}
	if op.kind == {
		case .INSERT_CHARS;
			assert(op.count == op.chars.count);
			line: *Line = *lines[op.y];
			assert(op.x <= line.count);
			for op.chars {
				x := op.x + it_index;
				array_insert_at(*line.chars, it, x);
			}
			shift_x(.{op.x, op.y}, op.chars.count);
			line.dirty_flags |= .ALL;
		case .DELETE_CHARS;
			// slow
			line := *lines[op.y];
			assert(op.x + op.count <= line.count);
			if flags & .FILL_FOR_REVERSE {
				assert(op.chars.count == 0);
				// alloc here aswell
				op.chars = array_copy([]u8.{ data = line.chars.data + op.x, count = op.count });
			}
			for < op.x..op.x+op.count-1 {
				array_ordered_remove_by_index(*line.chars, it);
			}
			shift_x(.{ op.x, op.y }, -op.count);
			line.dirty_flags |= .ALL;
		case .SPLIT_LINE;
			assert(op.y < lines.count);
			assert(op.x <= lines[op.y].count);
			new_line: *Line = array_insert_at(*lines, op.y+1);
			curr_line: *Line = *lines[op.y];
			array_add(*new_line.chars, .. advance(curr_line.chars, op.x));
			curr_line.chars.count = op.x;
			shift_y(.{op.x, op.y}, 1);
			shift_x(.{0, op.y+1}, -curr_line.count);
			new_line.dirty_flags |= .ALL;
			curr_line.dirty_flags |= .ALL;
		case .MERGE_LINES;
			assert(op.y + 1 < lines.count);
			assert(op.count == 1);
			if flags & .FILL_FOR_REVERSE {
				op.x = lines[op.y].count;
			}
			line: *Line = *lines[op.y];
			line_len := line.count;
			next_line: *Line = *lines[op.y+1];
			array_add(*line.chars, .. next_line.chars);
			array_ordered_remove_by_index(*lines, op.y+1); // @Leak
			shift_x(.{0, op.y+1 }, line_len);
			shift_y(op.y, -1);
			line.dirty_flags |= .ALL;
		case .INSERT_LINES;
			assert(op.lines.count == op.count);
			for op.lines {
				line: Line; // dirty flags already all !
				array_add(*line.chars, .. cast([]u8)it); // alloc here? though its fine
				y := op.y + it_index;
				array_insert_at(*lines, line, y);
			}
			shift_y(op.y, op.lines.count); // this isn't tested for non undos
		case .DELETE_LINES;
			assert(op.y + op.count <= lines.count);
			if flags & .FILL_FOR_REVERSE {
				assert(op.lines.count == 0);
				lines: [..]string; // alloc here too
				for op.y..op.y+op.count-1 {
					array_add(*lines, copy_string(cast(string)buf.lines[it].chars)); // alloc here
				}
				op.lines = lines;
			}
			array_ordered_remove_range(*lines, op.y, op.count);
			shift_count := op.count;
			shift_y_val := op.y;
			if op.y == lines.count
				shift_y_val -= 1;
			shift_y(shift_y_val, -shift_count);
			// TODO: this should be handled differently !!
			if lines.count == 0
				array_add(*lines);
		case;
			log("unsupported op: %\n", op.kind);
	}
	return true;
}

replace_buffer_lines_without_caps :: (using win: *Window, new_lines: []string) {
	cursor_pos := win.cursor.position;
	execute_buffer_operation(win, .{
		kind = .INSERT_LINES,
		y = lines.count,
		count = new_lines.count,
		lines = new_lines,
	}, even_if_no_caps = true);
	if new_lines.count == 0 {
		execute_buffer_operation(win, .{
			kind = .INSERT_LINES,
			y = lines.count,
			count = 1,
			lines = .[ "" ],
		}, even_if_no_caps = true);
	}
	execute_buffer_operation(win, .{
		kind = .ERASE_LINES,
		y = 0,
		count = lines.count - new_lines.count,
	}, even_if_no_caps = true);
	move_cursor(win, cursor_pos); // this normalizes it too
}

peek_last_operation :: (using buf: *Buffer) -> *Buffer_Op {
	if operation_index >= 0
		return *operations[operation_index];
	return null;
}

peek_next_operation :: (using buf: *Buffer) -> *Buffer_Op {
	if operation_index + 1 < operations.count
		return *operations[operation_index+1];
	return null;
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

// It takes a window on which the buffer will be drawn to.
// Maybe should organize this better.
_refresh_buffer_modifiers :: (win: *Window, using buf: *Buffer, ly: int, ry: int) {
	time_this("Refresh buffer modifiers");
	lines_to_refresh := []Line.{ data = lines.data + ly, count = ry - ly };
	for * lines_to_refresh {
		true_line_no := it_index + ly;
		using,only(mods) it;
		//assert (it.count <= mods.count, "%", it.count);
		if it.dirty_flags & .MODS {
			for * mods {
				it.* = .{};
				it.fg_color = syntax.normal_color;
			}
		}
		defer it.user_mods = mods;
		if !syntax.is_compiled
			continue;
		// should have a limit here i think?
		chars := it.chars;
		idx := 0;
		defer it.dirty_flags &= ~.MODS;
		line: *Line = it;
		for 1..20 {
			if line.dirty_flags & .MODS == 0
				break;
			string_to_match := advance(cast(string)chars, idx);
			matched, captures := Uniform.match(string_to_match, syntax.regex, .ANCHOR_START,, allocator=temp);
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
						log("Found syntax % %\n", true_line_no, cast(Syntax_Element.Kind)it_index);
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
					if replace.count > 0 {
						mod.replaced = string.{ data = *replace[it%replace.count], count = 1 };
					}
				}
			}
			idx += something_capture.count;
			if it > 15 { //
				log_error("kept matching at line % (%)\n", true_line_no, idx);
			}
		}
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

#run {
	log("%\n", _normalize_path("./asdf.jai"));
}
// sheesh
// TODO: './', '../' not supported
_normalize_path :: (_path: string) -> string {
	path := _path;
	if !path {
		return path;
	}
	b: String_Builder;
	b.allocator = temp;
	// lil hack
	while path.count >= 2 && path[0] == #char "." && path[1] == "/" {
		path = advance(path, 2);
	}
	if path[0] == "~" {
		home, ok := get_home_directory(,, allocator=temp);
		if !ok
			return "";
		print(*b, "%", home);
		path = advance(path, 1);
	}
	if path[0] != #char "/" {
		dir := get_working_directory(,, allocator=temp);
		if !dir {
			log_error("Cannot get working directory");
			return ""; 
		}
		append(*b, dir);
		if peek(dir) != #char "/"
			append(*b, "/");
	} 
	while path {
		if path[0] != #char "/" {
			append(*b, string.{ data = path.data, count = 1 });
			path = advance(path, 1);
			continue;
		}
		append(*b, "/");
		while path.count && path[0] == #char "/" {
			path = advance(path, 1);
		}
	}
	return builder_to_string(*b);
}

#import "Math";
#import "File";
#import "File_Utilities";
#import "System";
