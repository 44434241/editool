


Position :: struct {
	x, y: int;
}

operator + :: (l: Position, r: Position) -> Position {
	return .{ l.x + r.x, l.y + r.y };
}

operator * :: (l: Position, r: int) -> Position #symmetric {
	return .{ l.x * r, l.y * r };
}

operator == :: (l: Position, r: Position) -> bool {
	return l.x == r.x && l.y == r.y;
}

operator < :: (l: Position, r: Position) -> bool {
	return l.y < r.y || (l.y == r.y && l.x < r.x);
}

operator <= :: (l: Position, r: Position) -> bool {
	return l.y < r.y || (l.y == r.y && l.x <= r.x);
}

operator >= :: (l: Position, r: Position) -> bool {
	return r <= l;
}

Line :: struct {
	chars: [..]u8;
	colors: [256]s32;
	#overlay(chars.count) count: int;
}

// starts from 0/0
Cursor :: struct {
	using position: Position;
	virtual_real_x: int; // this is real x, and *not* in terms of char index
}

Buffer :: struct {
	lines: [..]Line;
	cursor: Cursor; // should belong to window, not buffer?
	scroll: int = 0;
	size: Position;
	is_dirty: bool = false;
	filename: string;
	operations: [..]Buffer_Op; // this array shouldn't get touched outside execute_buffer_operation
	operation_index: int = -1; // index of last operation that was done, or -1
	syntax: Syntax;
	modify_time: Editime; // when the last modifying operation happened?
}

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

execute_buffer_operation :: (using buf: *Buffer, op: Buffer_Op) {
	op_copy := op;
	if op_copy.kind == .INSERT_CHARS {
		op_copy.chars = array_copy(op_copy.chars);
	}
	_execute_buffer_operation(buf, *op_copy, .FILL_FOR_REVERSE);
	assert(buf.operation_index < operations.count);
	buf.operation_index += 1;
	operations.count = buf.operation_index; // @Leak
	array_add(*operations, op_copy);
}

Execute_Buffer_Op_Flags :: enum_flags {
	FILL_FOR_REVERSE;
	MOVE_CURSOR;
	NONE :: 0;
}

// leak?
_execute_buffer_operation :: (using buf: *Buffer, op: *Buffer_Op, flags: Execute_Buffer_Op_Flags) {
	if flags & .FILL_FOR_REVERSE {
		op.begin_cursor_position = buf.cursor.position;
		op.begin_mode = context.edit.mode;
		op.begin_time = context.edit.time;
	}
	defer {
		if flags & .MOVE_CURSOR {
			move_cursor(buf, op.begin_cursor_position);
		}
		buf.modify_time = context.edit.time;
		buf.is_dirty = true;
		normalize_cursor(buf); // i don't think i ned to do that?
		normalize_scroll(buf);
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
				refresh_cursor_virtual_x(buf); 
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
			refresh_cursor_virtual_x(buf);
		case .SPLIT_LINE;
			assert(op.y < lines.count);
			assert(op.x <= lines[op.y].count);
			new_line: *Line = array_insert_at(*lines, op.y+1);
			curr_line: *Line = *lines[op.y];
			array_add(*new_line.chars, .. advance(curr_line.chars, op.x));
			curr_line.chars.count = op.x;
			if cursor.y > op.y {
				buf.cursor.y += 1; 
			} else if cursor.y == op.y && cursor.x >= op.x {
				cursor.y += 1;
				cursor.x -= op.x;
				refresh_cursor_virtual_x(buf); 
			}
		case .MERGE_LINES;
			assert(op.y + 1 < buf.lines.count);
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
				refresh_cursor_virtual_x(buf);
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
			assert(op.y + op.count <= buf.lines.count);
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

undo :: (using buf: *Buffer) -> bool, Buffer_Op {
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
	_execute_buffer_operation(buf, *op, .MOVE_CURSOR);
	buf.operation_index -= 1;
	return true, op;
}

redo :: (using buf: *Buffer) -> bool, Buffer_Op {
	if operation_index + 1 >= operations.count
		return false, .{};
	op := buf.operations[buf.operation_index+1];
	_execute_buffer_operation(buf, *op, .MOVE_CURSOR);
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

normalize_scroll :: (using buf: *Buffer) {
	//
	scroll = clamp(scroll, 0, max(0, lines.count - size.y + 1));
	//
	scroll = max(cursor.y - size.y + 1, scroll);
	scroll = min(cursor.y, scroll);
}

offset_scroll :: (using buf: *Buffer, val: int) {
	scroll += val;
	normalize_scroll(buf);
}

set_scroll :: (using buf: *Buffer, val: int) {
	scroll = val;
	normalize_scroll(buf);
}

refresh_buffer_size :: (using buf: *Buffer) {
	buf.size = .{ COLS, LINES-1 };
	normalize_scroll(buf);
}

// maybe this should go somewhere else
draw_buffer :: (using buf: *Buffer) {
	{
		_refresh_buffer_colors(buf);
	}
	time_this("Draw buffer");
	clear();
	//width, height := getmaxx(stdscr)+1, getmaxy(stdscr)+1;
	lines_to_draw := advance(buf.lines, scroll);
	lines_to_draw.count = min(lines_to_draw.count, size.y);
	for lines_to_draw {
		true_line_no := it_index + scroll;
		line_no := true_line_no;
		if context.edit.flags & .RELATIVE_LINES {
			if line_no != buf.cursor.y
				line_no = abs(line_no - buf.cursor.y);
		}
		line_no_str := tprint(ifx buf.cursor.y == it_index + scroll then "%   " else " %  ", formatInt(line_no, padding = #char " ", minimum_digits = 3));
		attrset(A_BOLD);
		mvaddnstr(xx it_index, 0, line_no_str.data, xx line_no_str.count);
		attrset(0);
		move(xx it_index, 5);
		using,only(colors) it;
		assert (it.count <= colors.count);
		for it.chars {
			info := _get_char_info(it);
			// doing goofy colors here.. whatever !!
			if context.edit.flags & .GOOFY_COLORS {
				fg, bg := uncolor_fg_bg(colors[it_index]);
				bg = it_index / 1 - 1;
				colors[it_index] = color_fg_bg(fg, bg);
			}
			// matches are color 2
			attrset(COLOR_PAIR(colors[it_index]));
			if info.replaced {
				assert(info.replaced.count == info.size);
				addnstr(info.replaced.data, xx info.replaced.count);
			} else {
				assert(info.size == 1);
				addch(it);
			}
			attrset(0);
		}
	}
	mode_s := tprint("%", context.edit.mode);
	if context.edit.mode == .COMMAND {
		mode_s = tprint("%: '%'", mode_s, keybind_to_string(context.command_state.all_chars,, allocator=temp));
	}
	if context.edit.mode == .SEARCH || context.edit.search_state.regex_string {
		using context.edit.search_state;
		mode_s = tprint("% | Search: '%' (%/%)", mode_s, regex_string, min(selected_match + 1, matches.count), matches.count);
	}
	mvaddnstr(LINES-1, 0, mode_s.data, xx mode_s.count);
	real_x := _get_real_x_in_line(*buf.lines[buf.cursor.y], cursor.x);
	//
	move(xx (cursor.y - scroll), xx (real_x + 5));
	//
	refresh();
}

_refresh_buffer_colors :: (using buf: *Buffer) {
	time_this("Refresh buffer colors");
	lines_to_draw := advance(buf.lines, scroll);
	lines_to_draw.count = min(lines_to_draw.count, size.y);
	for lines_to_draw {
		true_line_no := it_index + scroll;
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
			if true_line_no == cursor.y {
				#if 0 {
					log("line %", true_line_no);
					for captures {
						log("%: '%'\n", it_index, it);
					}
				}
			}
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

move_cursor_y :: (using buf: *Buffer, y: int) {
	cursor.y = clamp(y, 0, lines.count-1);
	virtual_x := _from_real_x_in_line(*buf.lines[cursor.y], cursor.virtual_real_x);
	cursor.x = min(virtual_x, buf.lines[cursor.y].count);
	normalize_scroll(buf);
}

refresh_cursor_virtual_x :: (using buf: *Buffer) {
	cursor.virtual_real_x = _get_real_x_in_line(*lines[cursor.y], cursor.x);
}

move_cursor_x :: (using buf: *Buffer, x: int) {
	cursor.x = clamp(x, 0, lines[cursor.y].count);
	refresh_cursor_virtual_x(buf);
}

move_cursor :: (using buf: *Buffer, x: int, y: int) {
	move_cursor(buf, Position.{x, y});
}

move_cursor :: (using buf: *Buffer, v: Position, jump := false) {
	move_cursor_y(buf, v.y);
	move_cursor_x(buf, v.x);
}

offset_cursor :: (using buf: *Buffer, x: int, y: int) {
	assert(x == 0 || y == 0);
	if y != 0 {
		move_cursor_y(buf, cursor.y + y);
	}
	if x != 0 {
		move_cursor_x(buf, cursor.x + x);
	}
}

// EDITING BUFFER COMMANDS

write_string :: (using buf: *Buffer, s: string) {
	str := s;
	while str != "" {
		for str {
			if it == #char "\n" || it_index + 1 == str.count {
				cut := string.{ data = str.data, count = it_index };
				_write_normal_string(buf, cut);
				if it == #char "\n"
					write_char(buf, #char "\n");
				str = advance(str, it_index+1);
				break;
			}
		}
	}
}

// no funky characters!
_write_normal_string :: (using buf: *Buffer, s: string) {
	execute_buffer_operation(buf, .{
		kind = .INSERT_CHARS,
		y = cursor.y,
		x = cursor.x,
		count = s.count,
		chars = cast([]u8)s,
	});
}

write_char :: (using buf: *Buffer, ch: u8) {
	if ch == #char "\n" {
		split_line(buf, buf.cursor.position);
		return;
	} 
	#if 0 {
		array_insert_at(*lines[cursor.y].chars, ch, cursor.x);
		offset_cursor(buf, 1, 0);
		buf.is_dirty = true;
	} else {
		execute_buffer_operation(buf, .{
			kind = .INSERT_CHARS,
			y = cursor.y,
			x = cursor.x,
			count = 1,
			chars = .[ ch ],
		});
	}
}

merge_lines_after :: (using buf: *Buffer, line_y: int) {
	if line_y < 0
		return;
	if line_y + 1 >= buf.lines.count
		return;
	#if 0 {
		line: *Line = *lines[line_y];
		next_line: *Line = *lines[line_y+1];
		array_add(*line.chars, .. next_line.chars);
		array_ordered_remove_by_index(*lines, line_y+1); // @Leak
		buf.is_dirty = true;
		// ... update cursor
	} else {
		execute_buffer_operation(buf, .{
			kind = .MERGE_LINES,
			y = line_y,
			count = 1, // not used
		});
	}
}

// this should change to something else (x_offset argument is akward)
delete_at_x_offset :: (using buf: *Buffer, x_offset: int) {
	assert(x_offset == 0 || x_offset == -1);
	x := cursor.x + x_offset;
	if x < 0 {
		if cursor.y == 0
			return;
		//old_count := lines[cursor.y-1].count;
		merge_lines_after(buf, cursor.y-1);
		//offset_cursor(buf, 0, -1);
		//move_cursor_x(buf, old_count);
	} else if x >= lines[cursor.y].count {
		merge_lines_after(buf, cursor.y);
	} else {
		execute_buffer_operation(buf, .{
			kind = .DELETE_CHARS,
			y = cursor.y,
			x = x,
			count = 1,
		});
	}
}

delete_range_in_line :: (using buf: *Buffer, y: int, lx: int, rx: int) {
	if clamp(y, 0, lines.count-1) != y
		return;
	if lx > rx
		lx, rx = rx, lx;
	line := *lines[y];
	lx = clamp(lx, 0, line.count-1);
	rx = clamp(rx, 0, line.count-1);
	#if 0 {
		for < lx..rx {
			array_ordered_remove_by_index(*line.chars, it);
			if cursor.y == y && cursor.x > it {
				cursor.x -= 1;
			}
		}
		normalize_cursor_x(buf);
		buf.is_dirty = true;
	} else {
		execute_buffer_operation(buf, .{
			kind = .DELETE_CHARS,
			y = y,
			x = lx,
			count = rx - lx + 1,
		});
	}
}

delete_line_range :: (using buf: *Buffer, l: int, r: int) {
	l = clamp(l, 0, buf.lines.count-1);
	r = clamp(r, 0, buf.lines.count-1);
	if l > r
		l, r = r, l;
	delete_lines(buf, l, r - l + 1);
	// not setting dirty
}

delete_lines :: (using buf: *Buffer, y: int, count: int = 1) {
	y = clamp(y, 0, lines.count-1);
	count = min(count, lines.count - y + 1);
	#if 0 {
		for < y..y+count-1 { 
			array_ordered_remove_by_index(*lines, it); // @Leak
			if it < cursor.y {
				cursor.y -= 1;
			}
		}
		if lines.count == 0
			array_add(*lines);
		normalize_cursor(buf);
		buf.is_dirty = true;
	} else {
		execute_buffer_operation(buf, .{
			kind = .DELETE_LINES,
			y = y,
			count = count,
		});
	}
}

split_line :: (using buf: *Buffer, pos: Position) {
	// probably validated...
	#if 0 {
		new_line: *Line = array_insert_at(*lines, pos.y+1);
		curr_line: *Line = *lines[pos.y];
		array_add(*new_line.chars, .. advance(curr_line.chars, pos.x));
		curr_line.chars.count = cursor.x;
		if buf.cursor.y > pos.y {
			buf.cursor.y += 1; // cursors line didn't change, so i can just add
		} else if buf.cursor.y == pos.y && buf.cursor.x >= pos.x {
			move_cursor(buf, .{ buf.cursor.x - pos.x, buf.cursor.y + 1 });
		}
		buf.is_dirty = true;
	} else {
		execute_buffer_operation(buf, .{
			kind = .SPLIT_LINE,
			y = pos.y,
			x = pos.x,
		});
	}
}

// EDITING BUFFER COMMANDS END

// not sure from where this is called?
normalize_cursor_x :: (using buf: *Buffer) {
	move_cursor_x(buf, min(buf.cursor.x, buf.lines[buf.cursor.y].count));
}

// not sure from where this is called?
normalize_cursor :: (using buf: *Buffer) {
	cursor.y = clamp(cursor.y, 0, lines.count-1);
	normalize_cursor_x(buf);
}

// this is kinda a helper
// (count is number)
move_cursor :: (res: Motion_Result, count: int = 1) {
	if res.status != .OK
		return;
	buf := context.current_buffer;
	if res.start.x == res.end.x {
		y := buf.cursor.y + (res.end.y - buf.cursor.y) * count;
		move_cursor_y(buf, y);
	} else if res.start.y == res.end.y {
		x := buf.cursor.x + (res.end.x - buf.cursor.x) * count;
		move_cursor_x(buf, x);
	} else {
		// count not supported
		move_cursor(buf, res.end);
	}
}

Buffer_Char_Info :: struct {
	size: int = 1;
	replaced: string; // 
}

_get_real_x_in_line :: (line: *Line, x: int) -> int {
	if x == 0
		return 0;
	ret: int = 0;
	for 0..min(x-1, line.count-1) {
		ret += _get_char_info(line.chars[it]).size;
	}
	//ret += 1; // the NEXT char counts as size 1
	return ret;
}

_from_real_x_in_line :: (line: *Line, real_x: int) -> int {
	for line.chars {
		if real_x <= 0
			return it_index;
		real_x -= _get_char_info(it).size;
		if real_x < 0
			return it_index;
	}
	return line.chars.count;
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

#import "Math";
