
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

// starts from 0/0
Cursor :: struct {
	using position: Position;
	virtual_real_x: int; // this is real x, and *not* in terms of char index
}

Window :: struct {
	using,only(lines) buffer: *Buffer;
	size: #type,distinct Position;
	cursor: Cursor; // should belong to window, not buffer?
	scroll: int = 0;
}

refresh_window_size :: (using win: *Window) {
	win.size = .{ COLS, LINES-2 };
	normalize_scroll(win);
}

create_window_from_buffer :: (buf: *Buffer) -> *Window {
	win := New(Window);
	win.buffer = buf;
	array_add(*buf.windows, win);
	refresh_window_size(win);
	move_cursor(win, .{0, 0});
	return win;
}

// maybe this should go somewhere else
draw_window :: (using win: *Window) {
	{
	}
	//width, height := getmaxx(stdscr)+1, getmaxy(stdscr)+1;
	lines_to_draw_count := min(lines.count - scroll, size.y);
	lines_to_draw := []Line.{ data = lines.data + scroll, count = lines_to_draw_count };
	_refresh_buffer_colors(buffer, scroll, scroll + lines_to_draw_count);
	//
	time_this("Draw buffer");
	clear();
	for lines_to_draw {
		true_line_no := it_index + scroll;
		line_no := true_line_no;
		if context.edit.flags & .RELATIVE_LINES {
			if line_no != cursor.y
				line_no = abs(line_no - cursor.y);
		}
		line_no_str := tprint(ifx cursor.y == it_index + scroll then "%   " else " %  ", formatInt(line_no, padding = #char " ", minimum_digits = 3));
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
	{
		using,except(lines) win.buffer;
		fn := ifx filename else "<none>";
		file_info := tprint(" %  FLAGS: %", fn, file_flags);
		attron(A_STANDOUT); // seems to swap fg/bg !!
		attron(A_BOLD);
		attron(COLOR_PAIR(color_fg_bg(3, -1)));
		mvaddnstr(LINES-2, 0, file_info.data, xx file_info.count);
		for 1..size.x-file_info.count
			addch(#char " ");
		attrset(0);
	}
	{
		using,except(lines) win.buffer;
		mode_s := tprint("%", context.edit.mode);
		if context.edit.mode == .COMMAND {
			mode_s = tprint("%: '%'", mode_s, keybind_to_string(context.command_state.all_chars,, allocator=temp));
		}
		if context.edit.mode == .EXEC {
			mode_s = tprint("% :%", mode_s, context.edit.exec_state.str);
		}
		if context.edit.mode == .SEARCH || context.edit.search_state.regex_string {
			using context.edit.search_state;
			mode_s = tprint("% | Search: '%' (%/%)", mode_s, regex_string, min(selected_match + 1, matches.count), matches.count);
		}
		attrset(A_BOLD);
		mvaddnstr(LINES-1, 0, mode_s.data, xx mode_s.count);
		attrset(0);
	}
	real_x := _get_real_x_in_line(*lines[cursor.y], cursor.x);
	//
	move(xx (cursor.y - scroll), xx (real_x + 5));
	//
	refresh();
}

// CURSOR START
// (should have less of these tbh)

move_cursor_y :: (using win: *Window, y: int) {
	cursor.y = clamp(y, 0, lines.count-1);
	virtual_x := _from_real_x_in_line(*win.lines[cursor.y], cursor.virtual_real_x);
	cursor.x = min(virtual_x, win.lines[cursor.y].count);
	normalize_scroll(win);
}

refresh_cursor_virtual_x :: (using win: *Window) {
	cursor.virtual_real_x = _get_real_x_in_line(*lines[cursor.y], cursor.x);
}

move_cursor_x :: (using win: *Window, x: int) {
	cursor.x = clamp(x, 0, lines[cursor.y].count);
	refresh_cursor_virtual_x(win);
}

move_cursor :: (using win: *Window, x: int, y: int) {
	move_cursor(win, Position.{x, y});
}

move_cursor :: (using win: *Window, v: Position, jump := false) {
	move_cursor_y(win, v.y);
	move_cursor_x(win, v.x);
}

offset_cursor :: (using win: *Window, x: int, y: int) {
	assert(x == 0 || y == 0);
	if y != 0 {
		move_cursor_y(win, cursor.y + y);
	}
	if x != 0 {
		move_cursor_x(win, cursor.x + x);
	}
}

// not sure from where this is called?
normalize_cursor_x :: (using win: *Window) {
	move_cursor_x(win, min(win.cursor.x, win.lines[win.cursor.y].count));
}

// not sure from where this is called?
normalize_cursor :: (using win: *Window) {
	cursor.y = clamp(cursor.y, 0, lines.count-1);
	normalize_cursor_x(win);
}

// this is kinda a helper
// (count is number)
move_cursor :: (res: Motion_Result, count: int = 1) {
	if res.status != .OK
		return;
		win := context.current_window;
	if res.start.x == res.end.x {
		y := win.cursor.y + (res.end.y - win.cursor.y) * count;
		move_cursor_y(win, y);
	} else if res.start.y == res.end.y {
		x := win.cursor.x + (res.end.x - win.cursor.x) * count;
		move_cursor_x(win, x);
	} else {
		// count not supported
		move_cursor(win, res.end);
	}
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

// CURSOR END

// SCROLL BEGIN

normalize_scroll :: (using win: *Window) {
	//
	scroll = clamp(scroll, 0, max(0, lines.count - size.y + 1));
	//
	scroll = max(cursor.y - size.y + 1, scroll);
	scroll = min(cursor.y, scroll);
}

offset_scroll :: (using win: *Window, val: int) {
	scroll += val;
	normalize_scroll(win);
}

set_scroll :: (using win: *Window, val: int) {
	scroll = val;
	normalize_scroll(win);
}

// SCROLL END

// EDITING WINDOW (BUFFER) COMMANDS

/*
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
*/

// no funky characters!
_write_normal_string :: (using win: *Window, s: string) {
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = cursor.y,
		x = cursor.x,
		count = s.count,
		chars = cast([]u8)s,
	});
}

write_char :: (using win: *Window, ch: u8) {
	if ch == #char "\n" {
		split_line(win, cursor.position);
		return;
	} 
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = cursor.y,
		x = cursor.x,
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
	execute_buffer_operation(win, .{
		kind = .DELETE_CHARS,
		y = y,
		x = lx,
		count = rx - lx + 1,
	});
}

delete_line_range :: (using win: *Window, l: int, r: int) {
	l = clamp(l, 0, lines.count-1);
	r = clamp(r, 0, lines.count-1);
	if l > r
		l, r = r, l;
	delete_lines(win, l, r - l + 1);
	// not setting dirty
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

split_line :: (using win: *Window, pos: Position) {
	// probably validated...
	execute_buffer_operation(win, .{
		kind = .SPLIT_LINE,
		y = pos.y,
		x = pos.x,
	});
}

// EDITING BUFFER COMMANDS END

