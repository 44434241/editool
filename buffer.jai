
Line :: struct {
	chars: [..]u8;
	#overlay(chars.count) count: int;
	#overlay(chars) as_string: string;
	//
	mods: [256]Char_Mod = ---; // A LOT !
	user_mods: [256]Char_Mod = ---;
	Dirty_Flags :: enum_flags {
		MODS; 
		USER1; // something the user sets
		REAL_SIZE;
		NONE :: 0;
		ALL :: MODS | USER1;
	}
	dirty_flags: Dirty_Flags = .ALL;
	// size in x, considering tab characters and all that
	real_size: int = - 1; 
}

// this should be fast since line size is cached..
get_line_real_size_as_y :: (win: *Window, line: *Line) -> int {
	if win.size.x <= 0
		return 1;
	sz := get_real_size(line);
	if win.flags & .BUFFER_LINE_NO {
		sz += BUFFER_LINE_NO_SIZE_X;
	}
	if sz <= 1 
		return 1;
	ret := (sz + win.size.x - 1) / win.size.x;
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
		TEMP; // destroy when windows stop referencing it !
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
	// file
	filename: string;
	file_flags: File_Flags;
	syntax: *Syntax;
	// extra stuff
	user_data: *void; // has to be explicitly
	modify_buffer_operation: #type (*Window, *Buffer_Op) -> bool;
}

Directory_Buffer :: struct {
	buffer: *Buffer;
}

find_or_create_directory_buffer :: (_path: string) -> *Buffer {
	path := normalize_path(_path);
	assert(is_directory(path), "'%' is not directory", path);
	assert(false);
	return null;
}

find_or_create_file_buffer :: (_filename: string, flags: Buffer.Flags = .NONE, file_flags: Buffer.File_Flags = .NONE, must_respect_flags := false) -> *Buffer {
	assert(!must_respect_flags); // some flags might be whatever ! but not always ! in the future there will be some case
	assert((file_flags & .READ_ONLY) == file_flags); // has no other flags
	filename := _filename;
	if filename {
		filename = normalize_path(filename,, allocator=temp);
		if is_directory(filename) {
			// TODO: idk fix shit
			assert(false, "Trying to open directory (% -> %)...", _filename, filename);
		}
		for context.edit.buffers {
			if it.filename == filename {
				if it.file_flags != file_flags
					continue;
				// for the buffer to be temp, both the previous and this "new created" buffer must be temp
				if !((it.flags & .TEMP) && (flags &.TEMP))
					it.flags &= ~(.TEMP);
				return it;
			}
		}
	}
	filename = copy_string(filename);
	buf := _create_buffer_from_filename(filename, flags, file_flags);
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
	release(*buffer.pool);
	free(buffer);
}

_new_buffer :: (kind: Buffer.Kind) -> *Buffer {
	buf := New(Buffer);
	set_allocators(*buf.pool);
	buf.id = next_buffer_id();
	buf.kind = kind;
	array_add(*context.edit.buffers, buf);
	allocator := Allocator.{pool_allocator_proc, *buf.pool};
	// in order of declaration
	buf.lines.allocator = allocator;
	buf.ops.allocator = allocator;
	buf.windows.allocator = allocator;
	buf.commands.allocator = allocator;
	buf.search_matches.matches.allocator = allocator;
	buf.marks.allocator = allocator;
	array_add(*buf.lines, .{
		chars.allocator = allocator,
	});
	return buf;
}

// this should never fail, i think, even in the future?
get_current_buffer :: () -> *Buffer {
	win := get_selected_window_of_kind(.BUFFER);
	//assert(win != null);
	return win.buffer;
}

// this doesn't have lines, so it'll crash if u dont add any
create_custom_buffer :: (flags: Buffer.Flags = .NONE) -> *Buffer {
	buf := _new_buffer(.CUSTOM);
	buf.syntax = get_syntax_for_filename("");
	buf.flags |= flags;
	return buf;
}

_create_buffer_from_filename :: (filename: string, flags: Buffer.Flags, file_flags: Buffer.File_Flags) -> *Buffer {
	time_this("Create buffer");
	buf := _new_buffer(.FILE);
	buf.caps = .ALL;
	buf.flags = flags;
	buf.file_flags = file_flags;
	buf.filename = filename;
	//refresh_buffer_size(*buf); // from LINES, COLS
	buf.syntax = get_syntax_for_filename(filename);
	file_str: string;
	file_ok: bool = false;
	if filename {
		file_str, file_ok = read_entire_file(filename,, allocator=temp);
	}
	if file_ok {
		string_lines: []string = split(file_str, #char "\n",, allocator=temp);
		for * string_lines {
			// maybe should have some flag for clrf endings ?
			if it.count && peek(it.*) == #char "\r" {
				it.count -= 1;
				buf.file_flags |= .CLRF;
			}
		}
		if string_lines.count > 0 && peek(string_lines) == ""
			string_lines.count -= 1;
		for string_lines {
			// Only place left where lines/chars are directly added/removed.
			array_adds(*peek_pointer(buf.lines).chars, it);
			if it_index + 1 != string_lines.count {
				array_add(*buf.lines, .{
					chars.allocator = .{pool_allocator_proc, *buf.pool},
				});
			}
		}
	} else {
		buf.file_flags |= .NO_FILE;
	}
	return buf;
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
		NO_UNDO; // cannot be undone (opening a file)
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

Execute_Buffer_Op_Flags :: enum_flags {
	FILL_FOR_REVERSE;
	MOVE_CURSOR;
	NONE :: 0;
}

buffer_undo :: (win: *Window) -> bool, Buffer_Op {
	reverse_operation :: inline (op: *Buffer_Op) -> bool {
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
	if buf.op_index <= 0
		return false, .{};
	op := buf.ops[buf.op_index-1];
	if op.flags & .NO_UNDO {
		return false, op;
	}
	if !reverse_operation(*op) {
		edit_alert("Can't undo? %\n", op.kind, is_internal = true);
		return false, op; // this is a panic
	}
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		buf.op_index -= 1;
	}
	return ok, op;
}

buffer_redo :: (win: *Window) -> bool, Buffer_Op {
	using buf: *Buffer = win.buffer;
	if op_index >= ops.count
		return false, .{};
	op := buf.ops[buf.op_index];
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		op_index += 1;
	}
	return ok, op;
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

// buffer operation THROUGH window
// This is the only one that respects the callback?
execute_buffer_operation :: (win: *Window, _op: Buffer_Op, even_if_no_caps := false, no_callback := false) -> bool {
	allocator := Allocator.{pool_allocator_proc, *win.buffer.pool};
	op := _op;
	using buf: *Buffer = win.buffer;
	ok: bool = true;
	if ok && buf.modify_buffer_operation && !no_callback {
		// this doesn't have to return a bool, instead it could modify it to a nop !
		ok = buf.modify_buffer_operation(win, *op);
	}
	if ok {
		if op.kind == .INSERT_CHARS {
			op.chars = array_copy(op.chars,, allocator);
		} else if op.kind == .INSERT_LINES {
			lines: [..]string;
			array_reserve(*lines, op.lines.count);
			for op.lines {
				log("looking for error in op lines (%/%)", it_index, op.lines.count);
				array_add(*lines, copy_string(it));
			}
			op.lines = lines;
		}
	}
	if ok {
		ok = _execute_buffer_operation(win, buf, *op, .FILL_FOR_REVERSE, even_if_no_caps = even_if_no_caps,, allocator);
	}
	if ok {
		assert(buf.op_index <= ops.count);
		ops.count = buf.op_index; // @Leak
		log("looking for error in ops");
		array_add(*ops, op);
		op_index += 1;
		if save_op_index > ops.count
			set_dirty(buf);
	}
	return ok;
}

allocator_of :: (buf: *Buffer) -> Allocator {
	return .{pool_allocator_proc, *buf.pool};
}

// leak? (?)
// The only time this touches `win` instead of just its buffer, is when .MOVE_CURSOR flag is true !!!
_execute_buffer_operation :: (win: *Window, using,except(flags) buf: *Buffer, op: *Buffer_Op, flags: Execute_Buffer_Op_Flags, even_if_no_caps := false) -> bool {
	if !even_if_no_caps {
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
	using,only(cursor) win;
	allocator := Allocator.{pool_allocator_proc, *win.buffer.pool};
	//if even_if_no_caps
		//flags &= ~.FILL_FOR_REVERSE;
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
		for buf.windows {
			// Mark x might get out of bounds..
			// But if it gets normalized, then undo will be overly complicated.
			// The solution now is to not take marks at face value.
			//
			// Undo messing it up it still a problem, when the line it's on gets deleted.
			//
			//normalize_marks(it);
			normalize_cursor(it, with_scroll = true); 
			recalculate_window_real_size_y(win);
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
			if flags & .FILL_FOR_REVERSE {
				assert(op.chars.count == 0);
				// alloc here aswell
				op.chars = array_copy([]u8.{ data = line.chars.data + op.x, count = op.count },, allocator=allocator_of(buf));
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
			new_line.chars.allocator = allocator_of(buf);
			curr_line: *Line = *lines[op.y];
			array_add(*new_line.chars, .. advance(curr_line.chars, op.x));
			curr_line.chars.count = op.x;
			// this messes up but whatever rn
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
			array_ordered_remove_by_index(*lines, op.y+1); 
			shift_x(.{0, op.y+1 }, line_len);
			shift_y(op.y, -1);
			line.dirty_flags |= .ALL;
		case .INSERT_LINES;
			assert(op.lines.count == op.count);
			for op.lines {
				line: Line; // dirty flags already all !
				line.chars.allocator = allocator_of(buf);
				array_add(*line.chars, .. cast([]u8)it); 
				y := op.y + it_index;
				array_insert_at(*lines, line, y);
			}
			shift_y(op.y, op.lines.count); // this isn't tested for non undos
		case .ERASE_LINES;
			assert(op.y + op.count <= lines.count);
			if flags & .FILL_FOR_REVERSE {
				assert(op.lines.count == 0);
				lines: [..]string; // alloc here too
				lines.allocator = allocator_of(buf);
				for op.y..op.y+op.count-1 {
					array_add(*lines, copy_string(cast(string)buf.lines[it].chars),, allocator=allocator_of(buf));
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
			if lines.count == 0 {
				assert(false, "you shouldve handled this !!!");
				array_add(*lines);
			}
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
		count = lines.count - max(new_lines.count, 1),
	}, even_if_no_caps = true);
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

apply_syntax_mods :: (line: *Line, syntax: *Syntax, line_no_hint := -1, first_x := 0) {
	using,only(mods) line;
	idx := first_x;
	for 1..20 {
		string_to_match := advance(line.as_string, idx);
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
				if replace.count > 0 {
					mod.replaced = string.{ data = *replace[it%replace.count], count = 1 };
				}
			}
		}
		idx += something_capture.count;
		if it > 15 { //
			log_error("kept matching at line % (%)\n", line_no_hint, idx);
		}
	}
}

// It takes a window on which the buffer will be drawn to.
// Maybe should organize this better.
_refresh_buffer_modifiers :: (win: *Window, using buf: *Buffer, ly: int, ry: int) {
	time_this("Refresh buffer modifiers");
	lines_to_refresh := []Line.{ data = lines.data + ly, count = ry - ly };
	for * lines_to_refresh {
		true_line_no := it_index + ly;
		//assert (it.count <= mods.count, "%", it.count);
		if (it.dirty_flags & .MODS) {
			for * it.mods {
				it.* = .{};
				it.fg_color = syntax.normal_color;
			}
			if syntax.is_compiled
				apply_syntax_mods(it, syntax, line_no_hint = true_line_no, first_x = 0);
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

normalize_path :: (path: string) -> string {
	arr: [..]string;
	arr.allocator = temp;
	if path[0] == "~" {
		home, ok := get_home_directory(,, allocator=temp);
		if !ok {
			log_error("Cannot get home directory");
			return "";
		}
		array_add(*arr, .. split(home, #char "/",, allocator=temp));
	} else if path[0] != #char "/" {
		dir := get_working_directory(,, allocator=temp);
		if !dir {
			log_error("Cannot get working directory");
			return ""; 
		}
		array_add(*arr, .. split(dir, "/",, allocator=temp));
	}
	array_add(*arr, .. split(path, "/",, allocator=temp));
	idx := 0;
	while idx < arr.count {
		if arr[idx] == "" || arr[idx] == "." {
			array_ordered_remove_by_index(*arr, idx);
			continue;
		}
		if arr[idx] == ".." {
			array_ordered_remove_by_index(*arr, idx);
			if idx > 0 {
				array_ordered_remove_by_index(*arr, idx-1);
				idx -= 1;
			}
			continue;
		}
		idx += 1;
	}
	if arr.count == 0
		return "/";
	b: String_Builder;
	for arr {
		print(*b, "/%", it);
	}
	return builder_to_string(*b);
}

#scope_file

#import "Math";
#import "File";
#import "File_Utilities";
#import "System";