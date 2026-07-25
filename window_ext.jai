
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
	// Allocated in window or buffer, depending on which it belongs to
	// But that means mark can't be copied
	path: string;
}

// name has to be explicitly set
create_mark :: (using win: *Window) -> Mark {
	mark := Mark.{
		position = cursor.position,
		scroll = scroll,
		buffer_id = buffer.id,
		time = context.edit.time,
	};
	if buffer.kind == .FILE || buffer.kind == .DIRECTORY {
		mark.path = copy_string(buffer.path,, allocator=allocator_of(*win.pool));
	}
	return mark;
}

get_mark_buffer :: (mark: Mark) -> *Buffer {
	buf := find_buffer(mark.buffer_id);
	if !buf && mark.path
		buf = get_path_buffer(mark.path);
	return buf;
}

go_to_mark :: (win: *Window, mark: Mark, is_jump := true) -> bool {
	buf := get_mark_buffer(mark);
	if !buf
		return false;
	change_buffer(win, buf);
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

// this returns a normalized y..
get_relative_y :: (using buf: *Buffer, y: int, rel: int, inclusive := false) -> int {
	y = clamp(y, 0, buf.lines.count-1);
	while rel > 0 && y < buf.lines.count {
		fold := get_fold(buf, y);
		if fold {
			y = fold.end + 1;
		} else {
			y = y + 1;
		}
		rel -= 1;
	}
	while rel < 0 && y >= 0 {
		fold := get_fold(buf, y-1);
		if fold {
			y = fold.start;
		} else {
			y = y - 1;
		}
		rel += 1;
	}
	y = clamp(y, 0, ifx inclusive then buf.lines.count else buf.lines.count-1);
	return y;
}

/// SCROLL

// Assume cursor.y is ok?
normalize_scroll :: (using win: *Window) {
	#if 0 {
		scroll = clamp(scroll, 0, max(0, lines.count - size.y));
		scroll = clamp(scroll, cursor.y - size.y + 1, cursor.y);
		return;
	}
	scroll = clamp(scroll, 0, win.lines.count-1);
	if scroll < cursor.y {
		count_left := size.y; // -1 because we only care about the first real_line of last line !
		y := cursor.y;
		while y >= scroll {
			size_y := get_line_real_size_as_y(win, *lines[y]);
			count_left -= size_y;
			if count_left < 0 {
				scroll = min(get_relative_y(buffer, y, +1), cursor.y);
				break;
			}
			if y == 0
				break;
			y = get_relative_y(buffer, y, -1);
		}
	} else { // scroll > cursor.y
		scroll = cursor.y;
	}
	// TODO: doesn't work properly
	//_update_cursor_mark(win, false);
}

offset_scroll :: (using win: *Window, val: int) {
	scroll += val;
	normalize_scroll(win);
}

set_scroll :: (using win: *Window, val: int) {
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

normalize_position :: (using win: *Window, pos: Position, mode: Edit_Mode) -> Position {
	ret: Position = ---;
	ret.y = clamp(pos.y, 0, lines.count-1);
	ret.x = clamp(pos.x, 0, lines[ret.y].count);
	if mode == .COMMAND && lines[ret.y].count > 0
		ret.x = min(ret.x, lines[ret.y].count - 1);
	return ret;
}

normalize_cursor :: (using win: *Window, with_scroll: bool, force_jump := false) {
	cursor.position = normalize_position(win, cursor.position, context.edit.mode);
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
	pos := res.end;
	if res.position_for_cursor.x >= 0 && res.position_for_cursor.y >= 0
		pos = res.position_for_cursor;
	if res.is_jump {
		move_cursor(win, pos, jump = true);
	} else if res.start.x == pos.x || (res.flags & .Y_ONLY) {
		y := win.cursor.y + (pos.y - win.cursor.y) * count;
		move_cursor_y(win, y);
	} else if res.start.y == pos.y {
		x := win.cursor.x + (pos.x - win.cursor.x) * count;
		move_cursor_x(win, x);
	} else {
		// count not supported
		move_cursor(win, pos);
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

erase_chars :: (using win: *Window, count: int) -> bool {
	return erase_chars(win, cursor.position, count);
}

// this is different to delete_at_x_offset, because it doesn't mess with lines
erase_chars :: (using win: *Window, pos: Position, count: int) -> bool {
	line := *lines[pos.y];
	count = min(line.count - pos.x, count);
	if count <= 0
		return false;
	execute_buffer_operation(win, .{
		kind = .ERASE_CHARS,
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
			kind = .ERASE_CHARS,
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
		kind = .ERASE_CHARS,
		y = y,
		x = lx,
		count = rx - lx + 1,
	});
}

erase_line_range :: (using win: *Window, l: int, r: int) {
	if l > r
		l, r = r, l;
	erase_lines(win, l, r - l + 1);
}

erase_lines :: (using win: *Window, y: int, count: int = 1) {
	y = clamp(y, 0, lines.count-1);
	count = min(count, lines.count - y);
	for y..y+count-1 {
		f := get_fold(buffer, y);
		if f
			remove_fold(buffer, f);
	}
	if y == 0 && count == lines.count {
		execute_buffer_operation(win, .{
			kind = .ERASE_LINES,
			y = y,
			count = count - 1,
		});
		execute_buffer_operation(win, .{
			kind = .ERASE_CHARS,
			y = 0,
			x = 0,
			count = lines[0].count,
		});
	} else {
		execute_buffer_operation(win, .{
			kind = .ERASE_LINES,
			y = y,
			count = count,
		});
	}
}

_indentation_of_next_line :: (buf: *Buffer, y: int) -> int {
	ret: int = 0;
	for buf.lines[y].chars {
		if it != #char "\t"
			break;
		ret += 1;
	}
	add := 0;
	for buf.lines[y].chars {
		if it == #char "{"
			add += 1;
		if it == #char "}"
			add -= 1;
	}
	add = max(add, 0);
	return ret + add;
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