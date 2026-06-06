
Line :: struct {
	chars: [..]u8;
	colors: [256]s32;
	#overlay(chars.count) count: int;
}

Buffer :: struct {
	File_Flags :: enum_flags {
		NO_FILE; // failed to read
		READ_ONLY; // not implemented
		DIRTY;
		NONE :: 0;
	}
	lines: [..]Line;
	is_dirty: bool = false; // i dont know what this means..
	operations: [..]Buffer_Op; // this array shouldn't get touched outside execute_buffer_operation
	operation_index: int = -1; // index of last operation that was done, or -1
	syntax: Syntax;
	modify_time: Editime; // when the last modifying operation happened?
	// file
	filename: string;
	file_flags: File_Flags;
	windows: [..]*Window; // doing it like this for now..
}

create_buffer_from_filename :: (filename: string) -> Buffer {
	time_this("Create buffer");
	buf: Buffer;
	buf.filename = filename;
	//refresh_buffer_size(*buf); // from LINES, COLS
	array_add(*buf.lines, .{});
	buf.syntax = get_jai_syntax();
	file_str: string;
	file_ok: bool = false;
	if filename {
		file_str, file_ok = read_entire_file(filename);
	}
	if file_ok {
		string_lines: []string = split(file_str, #char "\n",, allocator=temp);
		for string_lines {
			array_adds(*peek_pointer(buf.lines).chars, it);
			if it_index + 1 != string_lines.count
				array_add(*buf.lines, .{});
		}
	} else {
		buf.file_flags |= .NO_FILE;
	}
	buf.file_flags &= ~.DIRTY;
	return buf;
}

// this is probably slow !
for_expansion :: (using buffer: *Buffer, body: Code, flags: For_Flags) #expand {
	#assert flags == 0;
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
		DELETE_LINES;
		DELETE_CHARS;
		INSERT_LINES;
		INSERT_CHARS;
		MERGE_LINES; // 2 lines
		SPLIT_LINE;
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
execute_buffer_operation :: (win: *Window, _op: Buffer_Op) {
	op := _op;
	if op.kind == .INSERT_CHARS {
		op.chars = array_copy(op.chars);
	}
	using buf: *Buffer = win.buffer;
	_execute_buffer_operation(win, buf, *op, .FILL_FOR_REVERSE);
	assert(buf.operation_index < operations.count);
	operation_index += 1;
	operations.count = buf.operation_index; // @Leak
	array_add(*operations, op);
}

// leak?
_execute_buffer_operation :: (win: *Window, using buf: *Buffer, op: *Buffer_Op, flags: Execute_Buffer_Op_Flags) {
	using,only(cursor) win;
	if flags & .FILL_FOR_REVERSE {
		op.begin_cursor_position = cursor.position;
		op.begin_mode = context.edit.mode;
		op.begin_time = context.edit.time;
	}
	moved_real_x := false;
	defer {
		if flags & .MOVE_CURSOR {
			move_cursor(win, op.begin_cursor_position);
		}
		buf.modify_time = context.edit.time;
		buf.is_dirty = true;
		buf.file_flags |= .DIRTY;
		for buf.windows {
			normalize_cursor(it); 
			normalize_scroll(it);
			if moved_real_x
				refresh_cursor_virtual_x(it);
		}
	}
	//normalize_buffer_operation(buf, op);
	assert(op.count >= 0);
	assert(op.y >= 0);
	assert(op.x >= 0);
	if op.kind == {
		case .INSERT_CHARS;
			assert(op.count == op.chars.count);
			line: *Line = *lines[op.y];
			assert(op.x <= line.count);
			for op.chars {
				x := op.x + it_index;
				array_insert_at(*line.chars, it, x);
			}
			if cursor.y == op.y && cursor.x >= op.x {
				cursor.x += op.chars.count;
				moved_real_x = true;
			}
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
				if cursor.y == op.y && cursor.x > it {
					cursor.x -= 1;
				}
			}
			moved_real_x = true;
		case .SPLIT_LINE;
			assert(op.y < lines.count);
			assert(op.x <= lines[op.y].count);
			new_line: *Line = array_insert_at(*lines, op.y+1);
			curr_line: *Line = *lines[op.y];
			array_add(*new_line.chars, .. advance(curr_line.chars, op.x));
			curr_line.chars.count = op.x;
			if cursor.y > op.y {
				cursor.y += 1; 
			} else if cursor.y == op.y && cursor.x >= op.x {
				cursor.y += 1;
				cursor.x -= op.x;
				moved_real_x = true;
			}
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
			if cursor.y == op.y + 1 {
				cursor.y -= 1;
				cursor.x += line_len;
				moved_real_x = true;
			} else if cursor.y > op.y + 1 {
				cursor.y -= 1;
			}
		case .INSERT_LINES;
			assert(op.lines.count == op.count);
			for op.lines {
				line: Line;
				array_add(*line.chars, .. cast([]u8)it); // alloc here? though its fine
				y := op.y + it_index;
				array_insert_at(*lines, line, y);
				if y <= cursor.y
					cursor.y += 1;
			}
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
			for < op.y..op.y+op.count-1 { 
				array_ordered_remove_by_index(*lines, it); // @Leak
				if it < cursor.y {
					cursor.y -= 1;
				}
			}
			// this should be handled differently !!
			if lines.count == 0
				array_add(*lines);
		case;
			log("unsupported op: %\n", op.kind);
	}
}

undo :: (win: *Window) -> bool, Buffer_Op {
	reverse_operation :: inline (op: *Buffer_Op) -> bool {
		if op.kind == {
			case .DELETE_LINES;
				op.kind = .INSERT_LINES;
			case .INSERT_LINES;
				op.kind = .DELETE_LINES;
			//
			case .DELETE_CHARS;
				op.kind = .INSERT_CHARS;
			case .INSERT_CHARS;
				op.kind = .DELETE_CHARS;
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
	if buf.operation_index < 0
		return false, .{};
	op := buf.operations[buf.operation_index];
	if op.flags & .NO_UNDO {
		return false, op;
	}
	if !reverse_operation(*op) {
		log_error("Can't undo? %\n", op.kind);
		return false, op; // this is a panic
	}
	_execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	buf.operation_index -= 1;
	return true, op;
}

redo :: (win: *Window) -> bool, Buffer_Op {
	using buf: *Buffer = win.buffer;
	if operation_index + 1 >= operations.count
		return false, .{};
	op := buf.operations[buf.operation_index+1];
	_execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	operation_index += 1;
	return true, op;
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

// lines is a view to buffer lines..
_refresh_buffer_colors :: (using buf: *Buffer, ly: int, ry: int) {
	time_this("Refresh buffer colors");
	lines_to_refresh := []Line.{ data = lines.data + ly, count = ry - ly };
	for lines_to_refresh {
		true_line_no := it_index + ly;
		using,only(colors) it;
		assert (it.count <= colors.count);
		for * colors {
			it.* = color_fg_bg(syntax.normal_color, -1);
		}
		if !syntax.is_compiled
			continue;
		// should have a limit here i think?
		chars := it.chars;
		idx := 0;
		for 1..20 {
			string_to_match := advance(cast(string)chars, idx);
			matched, captures := Uniform.match(string_to_match, syntax.regex, .ANCHOR_START,, allocator=temp);
			if !matched
				break;
			// captures[0] = full
			// captures[1] = prefix
			// captures[2] = value + suffix
			// whichever captures[3..3+COUNT] = value
			start_capture := captures[1];
			something_capture := captures[2];
			//color := ifx captures[3].count then syntax.kw_color1 else syntax.kw_color2;
			color: s32 = syntax.normal_color;
			for advance(captures, 3) {
				if it != "" {
					something_capture = it;
					color = syntax.elements[it_index].color;
					break;
				}
			}
			//color := syntax.elements[0].color;
			idx += start_capture.count;
			for idx..idx+something_capture.count-1 {
				colors[it] = color_fg_bg(color, -1);
			}
			idx += something_capture.count;
			if it > 15 {
				log_error("kept matching at line % (%)\n", true_line_no, idx);
			}
		}
	}
	do_some_extra_stuff_to_the_buffer_colors();
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
