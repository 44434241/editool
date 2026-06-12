
// Window file is too big !! I wanna try putting some stuff here.
// These are all operations for modifing the buffer in a window:
// - cursor/scroll
// - cursor/scroll/buffer undo/redo
// 

/// Vec/Position structs

Vec2i :: struct {
	x, y: int;
}

// @CompilerBug can't use with interface, NOT A STRUCT
//Position :: #type,isa Vec2i;

Position :: struct {
	x, y: int;
	#overlay(x) vec2: Vec2i;
}

operator + :: (l: $T/.[Vec2i, Position] , r: T) -> T {
	return .{ l.x + r.x, l.y + r.y };
}

operator - :: (l: $T/.[Vec2i, Position] , r: T) -> T {
	return .{ l.x - r.x, l.y - r.y };
}

operator * :: (l: $T/.[Vec2i, Position], r: int) -> T #symmetric {
	return .{ l.x * r, l.y * r };
}

operator == :: (l: $T/.[Vec2i, Position], r: T) -> bool {
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

// starts from 0/0
Cursor :: struct {
	using position: Position;
	// this is real x, and *not* in terms of char index
	virtual_real_x: int; 
	// <virtual> x - the 'highest' x that the cursor was on, so when lines change, it can update its x.
	// <real> x - x, respecting the size of tabs and other characters of size > 1.
}

/// MARKS

Mark :: struct {
	position: Position = .{-1, -1};
	scroll: int = -1;
	name: u8 = 0; // Not all marks are named.
	buffer_id: BufId = BUF_ID_NULL;
	time: Editime = -1;
}

// name has to be explicitly set
create_mark :: (using win: *Window) -> Mark {
	return .{
		position = cursor.position,
		scroll = scroll,
		buffer_id = buffer.id,
		time = context.edit.time,
	};
}

go_to_mark :: (win: *Window, mark: Mark, is_jump := true) -> bool {
	if !change_buffer(win, mark.buffer_id)
		return false;
	move_cursor(win, mark.position, jump = is_jump);
	set_scroll(win, mark.scroll);
	return true;
}

find_mark :: (using buf: *Buffer, name: s32) -> bool, Mark {
	for marks {
		if it.name == name {
			return true, it;
		}
	}
	return false, .{};
}

set_mark :: (using buf: *Buffer, mark: Mark) {
	if !mark.name {
		edit_error("Can't set un-named mark");
		return;
	}
	for * marks {
		if it.name == mark.name {
			it.* = mark;
			return;
		}
	}
	array_add(*marks, mark);
}

// there might be more than one! 
get_mark_at_y :: (using buf: *Buffer, y: int) -> bool, Mark {
	for marks {
		if it.position.y == y {
			return true, it;
		}
	}
	return false, .{};
}


/// SCROLL

normalize_scroll :: (using win: *Window) {
	scroll = clamp(scroll, 0, max(0, lines.count - size.y));
	scroll = clamp(scroll, cursor.y - size.y + 1, cursor.y);
	// TODO: doesn't work properly
	// _update_cursor_mark(win, false);
}

offset_scroll :: (using win: *Window, val: int) {
	scroll += val;
	normalize_scroll(win);
}

set_scroll :: (using win: *Window, val: int) {
	edit_alert("set scroll: %", val);
	scroll = val;
	normalize_scroll(win);
}

// CURSOR START
// (should have less of these tbh)
// some of these do unnecessary extra work, its whatever though

cursor_undo :: (using win: *Window) -> bool {
	_in_cursor_op = true;
	defer _in_cursor_op = false;
	if cursor_mark_index <= 0 {
		return false; // heh :)
	}
	cursor_mark_index -= 1;
	ok := go_to_mark(win, cursor_marks[cursor_mark_index]);
	return ok;
}

cursor_redo :: (using win: *Window) -> bool {
	_in_cursor_op = true;
	defer _in_cursor_op = false;
	if cursor_mark_index + 1 >= cursor_marks.count {
		return false;
	}
	cursor_mark_index += 1;
	ok := go_to_mark(win, cursor_marks[cursor_mark_index]);
	return ok;
}

_update_cursor_mark :: (using win: *Window, create: bool) {
	if _in_cursor_op
		return;
	if cursor_mark_index >= 0 {
		last_mark := cursor_marks[cursor_mark_index];
		if last_mark.time == context.edit.time {
			create = false;
		}
		// Changing buffer overwrites multiple marks in a single tick.
		// Not sure if that's good, or if it even matters.
		if last_mark.buffer_id != buffer.id {
			create = true;
		}
	}
	if create {
		if cursor_mark_index >= 0 {
			cursor_marks.count = cursor_mark_index + 1; 
		}
		array_add(*cursor_marks, create_mark(win));
		cursor_mark_index = cursor_marks.count - 1;
	} else if cursor_mark_index >= 0 {
		// fully update the mark
		time := cursor_marks[cursor_mark_index].time;
		cursor_marks[cursor_mark_index] = create_mark(win);
		cursor_marks[cursor_mark_index].time = time;
	}
}

normalize_position :: (using win: *Window, pos: Position) -> Position {
	ret: Position = ---;
	ret.y = clamp(pos.y, 0, lines.count-1);
	ret.x = clamp(pos.x, 0, lines[ret.y].count);
	return ret;
}

normalize_cursor :: (using win: *Window, with_scroll: bool, force_jump := false) {
	cursor.position = normalize_position(win, cursor.position);
	if with_scroll
		normalize_scroll(win);
	should_create_mark := force_jump || cursor_mark_index < 0;
	_update_cursor_mark(win, should_create_mark);
}

// only these 3 call normalize_cursor, or change cursor position..
// 

move_cursor :: (using win: *Window, pos: Position, jump := false) {
	if jump
		_update_cursor_mark(win, true);
	move_cursor_y(win, pos.y);
	move_cursor_x(win, pos.x);
	normalize_cursor(win, with_scroll = false, force_jump = false);
}

move_cursor_y :: (using win: *Window, y: int) {
	if buffer.caps & .MOVE_Y == 0
		return;
	cursor.y = clamp(y, 0, lines.count-1); // normalizes self, because needs to get virtual x
	virtual_x := _from_real_x_in_line(*win.lines[cursor.y], cursor.virtual_real_x);
	cursor.x = virtual_x;
	normalize_cursor(win, with_scroll = true);
}

move_cursor_x :: (using win: *Window, x: int) {
	if buffer.caps & .MOVE_X == 0
		return;
	cursor.x = clamp(x, 0, lines[cursor.y].count);
	refresh_cursor_virtual_x(win);
	normalize_cursor(win, with_scroll = false);
}

// these 2 are extras..

update_from_cursor_virtual_x :: (using win: *Window) {
	virtual_x := _from_real_x_in_line(*win.lines[cursor.y], cursor.virtual_real_x);
	move_cursor_x(win, virtual_x);
}

refresh_cursor_virtual_x :: (using win: *Window) {
	cursor.virtual_real_x = _get_real_x_in_line(*lines[cursor.y], cursor.x);
}

offset_cursor :: (using win: *Window, x: int, y: int) {
	move_cursor(win, .{ cursor.x + x, cursor.y + y });
}

offset_cursor_y :: (using win: *Window, y: int) {
	move_cursor_y(win, cursor.y + y);
}

offset_cursor_x :: (using win: *Window, x: int) {
	move_cursor_x(win, cursor.x + x);
}

// this is kinda a helper
// (count is number)
// this also moves scroll !!
move_cursor :: (res: Motion_Result, count: int = 1) {
	if res.status != .OK
		return;
	win := res.window;
	if win.motion_proc {
		ok := win.motion_proc(win, res);
		if !ok
			return;
	} 
	if res.is_jump {
		move_cursor(win, res.end, jump = true);
	} else if res.start.x == res.end.x || (res.flags & .Y_ONLY) {
		y := win.cursor.y + (res.end.y - win.cursor.y) * count;
		move_cursor_y(win, y);
	} else if res.start.y == res.end.y {
		x := win.cursor.x + (res.end.x - win.cursor.x) * count;
		move_cursor_x(win, x);
	} else {
		// count not supported
		move_cursor(win, res.end);
	}
	if res.scroll >= 0
		set_scroll(win, res.scroll); 
}

/// CURSOR END

/// EDITING WINDOW (BUFFER) COMMANDS START

// no funky characters!
_write_normal_string :: (using win: *Window, s: string) {
	_write_normal_string(win, cursor.position, s);
}

// no funky characters!
_write_normal_string :: (using win: *Window, pos: Position, s: string) {
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = pos.y,
		x = pos.x,
		count = s.count,
		chars = cast([]u8)s,
	});
}

write_char :: (using win: *Window, ch: u8) {
	write_char(win, cursor.position, ch);
}

write_char :: (using win: *Window, pos: Position, ch: u8) {
	if ch == #char "\n" {
		split_line(win, pos);
		return;
	} 
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = pos.y,
		x = pos.x,
		count = 1,
		chars = .[ ch ],
	});
}

merge_lines_after :: (using win: *Window, line_y: int) {
	if line_y < 0
		return;
	if line_y + 1 >= lines.count
		return;
	execute_buffer_operation(win, .{
		kind = .MERGE_LINES,
		y = line_y,
		count = 1, // not used
	});
}

delete_chars :: (using win: *Window, count: int) -> bool {
	return delete_chars(win, cursor.position, count);
}

// this is different to delete_at_x_offset, because it doesn't mess with lines
delete_chars :: (using win: *Window, pos: Position, count: int) -> bool {
	line := *lines[pos.y];
	count = min(line.count - pos.x, count);
	if count <= 0
		return false;
	execute_buffer_operation(win, .{
		kind = .DELETE_CHARS,
		y = pos.y,
		x = pos.x,
		count = count,
	});
	return true;
}

// this should change to something else (x_offset argument is akward)
delete_at_x_offset :: (using win: *Window, x_offset: int) {
	assert(x_offset == 0 || x_offset == -1);
	x := cursor.x + x_offset;
	if x < 0 {
		if cursor.y == 0
			return;
		merge_lines_after(win, cursor.y-1);
	} else if x >= lines[cursor.y].count {
		merge_lines_after(win, cursor.y);
	} else {
		execute_buffer_operation(win, .{
			kind = .DELETE_CHARS,
			y = cursor.y,
			x = x,
			count = 1,
		});
	}
}

delete_range_in_line :: (using win: *Window, y: int, lx: int, rx: int) {
	if clamp(y, 0, lines.count-1) != y
		return;
	if lx > rx
		lx, rx = rx, lx;
	line := *lines[y];
	lx = clamp(lx, 0, line.count-1);
	rx = clamp(rx, 0, line.count-1);
	if lx < 0
		return;
	execute_buffer_operation(win, .{
		kind = .DELETE_CHARS,
		y = y,
		x = lx,
		count = rx - lx + 1,
	});
}

delete_line_range :: (using win: *Window, l: int, r: int) {
	if l > r
		l, r = r, l;
	delete_lines(win, l, r - l + 1);
}

delete_lines :: (using win: *Window, y: int, count: int = 1) {
	y = clamp(y, 0, lines.count-1);
	count = min(count, lines.count - y + 1);
	execute_buffer_operation(win, .{
		kind = .DELETE_LINES,
		y = y,
		count = count,
	});
}

_indentation_of_next_line :: (buf: *Buffer, y: int) -> int {
	ret: int = 0;
	for buf.lines[y].chars {
		if it != #char "\t"
			break;
		ret += 1;
	}
	for buf.lines[y].chars {
		if it == #char "{"
			ret += 1;
		if it == #char "}"
			ret -= 1;
	}
	ret = max(ret, 0);
	return ret;
}

split_line :: (using win: *Window, indent: bool = true) {
	split_line(win, cursor.position, indent);
}

split_line :: (using win: *Window, pos: Position, indent: bool = true) {
	curr_y := pos.y; // to prevent this aliasing thing
	// probably validated...
	ok := execute_buffer_operation(win, .{
		kind = .SPLIT_LINE,
		y = pos.y,
		x = pos.x,
	});
	if ok && indent {
		indent := _indentation_of_next_line(buffer, curr_y);
		edit_alert("indent (%): %", pos.y, indent);
		indent_chars := NewArray(indent, u8, initialized = false,, allocator=temp);
		for * indent_chars
			it.* = #char "\t";
		_write_normal_string(win, .{0, curr_y+1}, cast(string)indent_chars);
	}
}

// Still not sure if i wanna put anything else in buffer operations...
// I dont like these operations being shared between buffer and window files..
// ^ I'll be able to after everything gets cleaned up.

buffer_undo :: (win: *Window) -> bool, Buffer_Op {
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
		edit_alert("Can't undo? %\n", op.kind, is_internal = true);
		return false, op; // this is a panic
	}
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		buf.operation_index -= 1;
	}
	return ok, op;
}

buffer_redo :: (win: *Window) -> bool, Buffer_Op {
	using buf: *Buffer = win.buffer;
	if operation_index + 1 >= operations.count
		return false, .{};
	op := buf.operations[buf.operation_index+1];
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		operation_index += 1;
	}
	return ok, op;
}

// EDITING BUFFER COMMANDS END

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

