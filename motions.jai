

// start/end could be reversed, depending on the motion
Motion_Result :: struct {
	Flags :: enum_flags {
		X_ONLY;
		Y_ONLY;
		SCROLL_ONLY;
		NONE :: 0;
	}
	Status :: enum {
		OK;
		ERROR;
		CONTINUE_CHAR; // this motion expects a printable char
	}
	status: Status = .OK;
	flags: Flags = .NONE;
	start: Position = .{ -1, -1 };
	end: Position = .{ -1, -1 };
	// if this motion is used to move the cursor and this is valid, use this instead
	position_for_cursor: Position = .{ -1, -1 };
	continue_no_number: bool = false;
	error_message: string; // not printed rn
	is_jump: bool = false;
	scroll: int = -1;
	window: *Window;
	motion: *Motion;
}

Motion_Res :: Motion_Result;

Motion_Input :: struct {
	window: *Window; // 
	number: int = 1; // > 0
}

Motion_In :: Motion_Input;

Motion :: struct {
	Flags :: enum_flags {
		SUPPORTS_NUMBER; // idk..
		X_ONLY;
		Y_ONLY;
		SCROLL_ONLY;
		RESPECTS_FOLD; // ignored.. and not how it should work anyway !
		NONE :: 0;
	}
	flags: Flags; // not used..
	Proc :: #type (Motion_Input) -> Motion_Result;
	Char_Proc :: #type (Motion_Input, s32) -> Motion_Result;
	keybind: Keybind;
	proc: Proc;
	char_proc: Char_Proc; // is .CONTINUE_CHAR
}

find_motion :: (keybind: $T/.[[]s32, string]) -> *Motion {
	for * context.edit.motions {
		if keybind_matches(it.keybind, keybind)
			return it;
	}
	return null;
}

normalize_motion_result :: (win: *Window, res: *Motion_Res, mode := Edit_Mode.NONE) {
	res.start = normalize_position(win, res.start, mode);
	res.end = normalize_position(win, res.end, mode);
}

// this could recurse, actually..
// works a bit differently than commands.. won't handle motions that get called again!
make_motion_alias :: ($chars: $T/.[ []s32, string ]) -> Motion.Proc {
	inner_proc :: (in: Motion_In) -> Motion_Result {
		motion := find_motion(chars);
		if !motion {
			return .{
				status = .ERROR,
				error_message = "Can't find motion alias"
			};
		}
		return motion.proc(in);
	}
	return inner_proc;
}

find_char_in_line :: (win: *Window, ch: u8, opposite_ch: u8, step: int, count: int) -> int {
	x := win.cursor.x;
	if step < 0
		x -= 1;
	return find_char_in_line(win, x, ch, opposite_ch, step, count);
}

find_char_in_line :: (win: *Window, x: int, ch: u8, opposite_ch: u8, step: int, count: int = 1) -> int {
	assert(step == 1 || step == -1);
	line := *win.lines[win.cursor.y];
	char_cnt := count;
	idx := x;
	while true {
		if idx < 0 || idx >= line.count {
			return -1;
		}
		if line.chars[idx] == ch
			char_cnt -= 1;
		if line.chars[idx] == opposite_ch
			char_cnt += 1;
		if char_cnt == 0
			return idx;
		idx += step;
	}
	return -1;
}

// starts from cursor
find_char_in_window :: (win: *Window, ch: u8, opposite_ch: u8, step: int, count: int = 1) -> Position {
	assert(step == 1 || step == -1);
	y := win.cursor.y;
	x := win.cursor.x + step;
	//x = min(x, win.lines[y].count-1);
	char_cnt := count;
	should_change_x := false;
	while in_range_exclusive(y, 0, win.lines.count) {
		defer y += step;
		line := *win.lines[y];
		if should_change_x
			x = ifx step < 0 then line.count - 1 else 0;
		while in_range_exclusive(x, 0, line.count) {
			defer x += step;
			if line.chars[x] == ch
				char_cnt -= 1;
			if line.chars[x] == opposite_ch
				char_cnt += 1;
			if char_cnt == 0
				return .{ x, y };
		}
		should_change_x = true;
	}
	return .{ -1, -1 };
}

motion_inner :: (in: Motion_In, $ch: u8, $inclusive: bool) -> Motion_Result {
	left_x, right_x: int = ---;
	win := in.window;
	#if ch == "(" || ch == ")" {
		left_x = find_char_in_line(win, "(", ")", -1, in.number);
		right_x = find_char_in_line(win, ")", "(", 1, in.number);
		//
	} else #if ch == "[" || ch == "]" {
		left_x = find_char_in_line(win, "[", "]", -1, in.number);
		right_x = find_char_in_line(win, "]", "[", 1, in.number);
		//
	} else #if ch == "<" || ch == ">" {
		left_x = find_char_in_line(win, "<", ">", -1, in.number);
		right_x = find_char_in_line(win, ">", "<", 1, in.number);
	} else #if ch == "{" || ch == "}" {
		left_x = find_char_in_line(win, "{", "}", -1, in.number);
		right_x = find_char_in_line(win, "}", "{", 1, in.number);
	} else #if ch == "\"" || ch == " " || ch == "'" || ch == "." || ch == "_" 
			|| ch == "/" || ch == "`" {
		left_x = find_char_in_line(win, ch, 0, -1, in.number);
		right_x = find_char_in_line(win, ch, 0, 1, in.number);
		//
	} else #if ch == "w" {
		#assert !inclusive;
		left_x = motion_word(in, -1, .INCLUSIVE).end.x;
		right_x = motion_word(in, 1, .INCLUSIVE).end.x;
	} else #if ch == "W" {
		#assert !inclusive; 
		left_x = motion_word(in, -1, .INCLUSIVE | .FULL).end.x;
		right_x = motion_word(in, 1, .INCLUSIVE | .FULL).end.x;
	} else {
		#assert false;
	}
	if left_x < 0 || right_x < 0 {
		return .{ status = .ERROR };
	}
	#if ch == "w" || ch == "W" {
		left_x -= 1;
		right_x += 1;
	}
	#if !inclusive {
		left_x += 1;
		right_x -= 1;
	}
	cursor := in.window.cursor;
	return {
		start = .{ left_x, cursor.y },
		end = .{ right_x, cursor.y },
		flags = .X_ONLY,
	};
}

Motion_Word_Flags :: enum_flags {
	FULL; // every non white space character counts as a character
	INCLUSIVE;
	NONE :: 0;
}

// TODO: in.number not supported
motion_word :: (in: Motion_In, $step: int = 1, $flags: Motion_Word_Flags = 0) -> Motion_Result {
	using,except(flags) win := in.window;
	assert(step == 1 || step == -1);
	line := *win.lines[cursor.y];
	// early returns don't support number (though it doesn't matter that much, maybe its better?)
	if step > 0 && cursor.x >= line.count {
		return .{
			start = cursor.position,
			//end = ifx cursor.position.y + 1 < lines.count then Position.{ 0, cursor.position.y + 1 } else cursor.position,
			end = cursor.position,
		};
	}
	if step < 0 && cursor.x <= 0 {
		return .{
			start = cursor.position,
			//end = ifx cursor.y > 0 then Position.{ lines[cursor.y-1].count, cursor.y - 1 } else cursor.position,
			end = cursor.position,
		};
	}
	next_x := min(cursor.x, line.count-1);
	//x_ok :: () -> bool #expand {
		//return clamp(next_x + step, 0, line.count) == next_x + step;
	//}
	is_alunder :: (ch: u8) -> bool { // digit works too lol oops
		return is_alpha(ch) || ch == #char "_" || is_digit(ch);
	}
	x_ok :: () -> bool #expand {
		return clamp(next_x, 0, line.count-1) == next_x;
	}
	for 1..in.number {
	// still not sure if i wanna do it like this!
		if flags & .INCLUSIVE {
			if flags & .FULL {
				while x_ok() && !is_space(line.chars[next_x]) {
					next_x += step;
				}
				next_x -= step;
			} else {
				while x_ok() && is_alnum(line.chars[next_x]) {
					next_x += step;
				}
				next_x -= step;
			}
		} else if flags & .FULL {
			if step > 0 {
				while x_ok() && !is_space(line.chars[next_x]) {
					next_x += step;
				}
				while x_ok() && is_space(line.chars[next_x]) {
					next_x += step;
				}
			} else {
				next_x += step;
				while x_ok() && is_space(line.chars[next_x]) {
					next_x += step;
				} 
				while x_ok() && !is_space(line.chars[next_x]) {
					next_x += step;
				}
				next_x -= step;
			}
		} else { 
			if step > 0 {
				while x_ok() && is_alunder(line.chars[next_x]) {
					next_x += step;
				}
				while x_ok() && !is_alunder(line.chars[next_x]) {
					next_x += step;
				}
			} else {
				next_x += step;
				while x_ok() && !is_alunder(line.chars[next_x]) {
					next_x += step;
				} 
				while x_ok() && is_alunder(line.chars[next_x]) {
					next_x += step;
				}
				next_x -= step;
			}
		}
	}
	return .{
		start = cursor.position,
		end = .{ next_x, cursor.position.y },
		flags = .X_ONLY,
	};
}

motion_find_char :: (_: Motion_In) -> Motion_Result {
	return .{ status = .CONTINUE_CHAR, continue_no_number = true };
}

motion_find_char_char :: (in: Motion_In, char: s32, $step: int, $inclusive: bool) -> Motion_Result {
	assert(step == -1 || step == 1);
	if !is_printable_char(char) && char != #char "\t" {
		return .{ status = .ERROR };
	}
	win := in.window;
	x := win.cursor.x + step;
	idx := find_char_in_line(win, x, xx char, 0, step, in.number);
	if idx < 0 {
		return .{ status = .ERROR };
	}
	if !inclusive
		idx -= step;
	return .{
		start = win.cursor.position,
		end = .{ idx, win.cursor.position.y },
		flags = .X_ONLY,
	};
}

motion_page_step :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	using win := in.window;
	return .{
		is_jump = true,
		start = cursor.position,
		end = .{ x = cursor.x, y = get_relative_y(buffer, cursor.y, step * (size.y-1) * in.number) },
		flags = .Y_ONLY,
	};
}

motion_step :: (in: Motion_In, step: Position, is_jump: bool) -> Motion_Result {
	assert(step.x == 0 || step.y == 0);
	assert(step.x != 0 || step.y != 0);
	win := in.window;
	if step.x != 0 || in.number != 1 {
		return .{
			start = win.cursor.position,
			end = win.cursor.position + step * in.number,
			flags = ifx step.x != 0 then .X_ONLY else .Y_ONLY,
			is_jump = is_jump,
		};
	} else {
		return .{
			start = win.cursor.position,
			end = .{ win.cursor.x, get_relative_y(in.window.buffer, win.cursor.y, step.y * in.number) },
			flags = .Y_ONLY,
			is_jump = is_jump,
		};
	}
}

// either start of line or end of line
// Number unsupported here, don't know how to define that..
motion_end_of_line :: (in: Motion_In, step: int, really_end: bool = true) -> Motion_Result {
	assert(step == 1 || step == -1);
	win := in.window;
	x := ifx step < 0 then 0 else win.lines[win.cursor.y].count;
	if !really_end && step > 0
		x = max(0, win.lines[win.cursor.y].count-1);
	return .{
		start = win.cursor.position,
		end = .{ x, win.cursor.y },
		flags = .X_ONLY,
	};
}

// (g/GG)
// either start of line of file
// TODO: Should define that it supports 0 number ?
motion_end_of_file  :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	win := in.window;
	y := ifx step < 0 then 0 else win.lines.count - 1;
	if in.number > 1
		y = in.number;
	return .{
		start = win.cursor.position,
		end = .{ win.cursor.x, y },
		flags = .Y_ONLY,
		is_jump = true,
	};
}

// '{', '}' 
motion_empty_line  :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	using win := in.window;
	count := in.number;
	y := win.cursor.y;
	start: Position = cursor.position;
	is_jump := true;
	if lines[start.y].count == 0 {
		is_jump = false;
	}
	if step < 0 && lines[start.y].count == 0 {
		start.y -= 1;
		start.x = lines[start.y].count;
	}
	seen_normal_line := false;
	while true {
		is_eof := clamp(y, 0, win.lines.count - 1) != y;
		if !is_eof && win.lines[y].count != 0 {
			seen_normal_line = true;
		}
		if seen_normal_line && (is_eof || win.lines[y].count == 0) {
			count -= 1;
			seen_normal_line = false;
		}
		if count == 0
			break;
		if is_eof
			return .{ status = .ERROR };
		y += step;
	}
	end := Position.{ 0, y};
	if step > 0 {
		end.y -= 1;
		end.x = lines[end.y].count;
	}
	return .{
		start = start,
		end = end,
		position_for_cursor = .{0, y},
		is_jump = is_jump,
		//flags = .Y_ONLY,
	};
}

motion_mark :: (_: Motion_In) -> Motion_Result {
	return .{ status = .CONTINUE_CHAR, continue_no_number = true };
}

motion_mark_char :: (in: Motion_In, char: s32) -> Motion_Result {
	win := in.window;
	ok, mark := find_mark(win.buffer, char);
	if !ok {
		return .{
			status = .ERROR,
			error_message = tprint("Mark '%' not found", keybind_to_string(.[ char ])),
		};
	}
	return .{
		start = win.cursor.position,
		end = mark.position,
		scroll = mark.scroll,
		flags = .Y_ONLY,
		is_jump = true,
	};
}

motion_scroll_offset :: (in: Motion_In, $step: int) -> Motion_Result {
	// i might feel like changing the step for this one
	using win := in.window;
	return .{
		start = win.cursor.position,
		end = win.cursor.position,
		flags = .SCROLL_ONLY,
		//scroll = max(win.scroll + step * in.number, 0),
		scroll = get_relative_y(buffer, scroll, step * in.number),
	};
}

motion_scroll_center :: (in: Motion_In) -> Motion_Result {
	win := in.window;
	scroll := get_relative_y(win.buffer, win.cursor.y, -win.size.y / 2);
	scroll = max(scroll, 0);
	return .{
		start = win.cursor.position,
		end = win.cursor.position,
		flags = .SCROLL_ONLY,
		scroll = scroll,
	};
}

add_all_motions :: () {
	// MOTIONS
	add_motion(
		keybind = .[ KEY_SR ],
		proc = #bake_arguments motion_scroll_offset(step = -5),
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = .[ KEY_SF ],
		proc = #bake_arguments motion_scroll_offset(step = 5),
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = .[ KEY_SNEXT ],
		proc = #bake_arguments motion_scroll_offset(step = 999),
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = .[ KEY_SPREVIOUS ],
		proc = #bake_arguments motion_scroll_offset(step = -999),
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = "Z",
		proc = motion_scroll_center,
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = "zz",
		proc = motion_scroll_center,
		flags = .SCROLL_ONLY,
	);
	add_motion(
		keybind = "w",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_word(step = 1, flags = .NONE)),
	);
	add_motion(
		keybind = "W",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_word(step = 1, flags = .FULL)),
	);
	add_motion(
		keybind = "b",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_word(step = -1, flags = .NONE)),
	);
	add_motion(
		keybind = "B",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_word(step = -1, flags = .FULL)),
	);
	add_motion(
		keybind = "i/",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "/", inclusive = false)),
	);
	add_motion(
		keybind = "a/",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "/", inclusive = true)),
	);
	add_motion(
		keybind = "i]",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "]", inclusive = false)),
	);
	add_motion(
		keybind = "a]",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "]", inclusive = true)),
	);
	add_motion(
		keybind = "i}",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "}", inclusive = false)),
	);
	add_motion(
		keybind = "a}",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "}", inclusive = true)),
	);
	add_motion(
		keybind = "i>",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char ">", inclusive = false)),
	);
	add_motion(
		keybind = "a>",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char ">", inclusive = true)),
	);
	add_motion(
		keybind = "i)",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char ")", inclusive = false)),
	);
	add_motion(
		keybind = "a)",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char ")", inclusive = true)),
	);
	add_motion(
		keybind = "i`",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "`", inclusive = false)),
	);
	add_motion(
		keybind = "i.",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char ".", inclusive = false)),
	);
	add_motion(
		keybind = "i_",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "_", inclusive = false)),
	);
	add_motion(
		keybind = "i\"",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "\"", inclusive = false)),
	);
	add_motion(
		keybind = "i'",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "'", inclusive = false)),
	);
	add_motion(
		keybind = "a\"",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "\"", inclusive = true)),
	);
	add_motion(
		keybind = "iw",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "w", inclusive = false)),
	);
	add_motion(
		keybind = "iW",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_inner(ch = #char "W", inclusive = false)),
	);
	add_motion(
		keybind = "j",
		flags = .Y_ONLY,
		proc = #bake_arguments(motion_step(step = .{ y = 1 }, is_jump = true)),
	);
	add_motion(
		keybind = "k",
		flags = .Y_ONLY,
		proc = #bake_arguments(motion_step(step = .{ y = -1 }, is_jump = true)),
	);
	add_motion(
		keybind = .[ KEY_LEFT ],
		flags = .X_ONLY,
		proc = #bake_arguments(motion_step(step = .{ x = -1 }, is_jump = false)),
	);
	add_motion(
		keybind = .[ KEY_RIGHT ],
		flags = .X_ONLY,
		proc = #bake_arguments(motion_step(step = .{ x = 1 }, is_jump = false)),
	);
	add_motion(
		keybind = .[ KEY_UP ],
		flags = .Y_ONLY,
		proc = #bake_arguments(motion_step(step = .{ y = -1 }, is_jump = false)),
	);
	add_motion(
		keybind = .[ KEY_DOWN ],
		flags = .Y_ONLY,
		proc = #bake_arguments(motion_step(step = .{ y = 1 }, is_jump = false)),
	);
	add_motion(
		keybind = .[ KEY_HOME ],
		flags = .X_ONLY,
		proc = #bake_arguments(motion_end_of_line(step = -1, really_end = true)),
	);
	add_motion(
		keybind = .[ KEY_END ],
		flags = .X_ONLY,
		proc = #bake_arguments(motion_end_of_line(step = 1, really_end = true)),
	);
	add_motion(
		keybind = "$",
		flags = .X_ONLY,
		proc = #bake_arguments(motion_end_of_line(step = 1, really_end = false)),
	);
	add_motion(
		keybind = "f",
		proc = motion_find_char,
		flags = .X_ONLY,
		char_proc = #bake_arguments motion_find_char_char(step = 1, inclusive = true),
	);
	add_motion(
		keybind = "F",
		proc = motion_find_char,
		flags = .X_ONLY,
		char_proc = #bake_arguments motion_find_char_char(step = -1, inclusive = true),
	);
	add_motion(
		keybind = "t",
		proc = motion_find_char,
		flags = .X_ONLY,
		char_proc = #bake_arguments motion_find_char_char(step = 1, inclusive = false),
	);
	add_motion(
		keybind = "T",
		proc = motion_find_char,
		flags = .X_ONLY,
		char_proc = #bake_arguments motion_find_char_char(step = -1, inclusive = false),
	);
	add_motion(
		keybind = .[ KEY_CRIGHT ],
		flags = .X_ONLY,
		proc = make_motion_alias("W"),
	);
	add_motion(
		keybind = .[ KEY_CLEFT ],
		flags = .X_ONLY,
		proc = make_motion_alias("B"),
	);
	add_motion(
		keybind = "gg",
		flags = .Y_ONLY | .RESPECTS_FOLD,
		proc = #bake_arguments motion_end_of_file(step = -1),
	);
	add_motion(
		keybind = "G",
		flags = .Y_ONLY | .RESPECTS_FOLD,
		proc = #bake_arguments motion_end_of_file(step = 1),
	);
	add_motion(
		keybind = .[ KEY_NPAGE ],
		flags = .Y_ONLY,
		proc = #bake_arguments motion_page_step(step = 1),
	);
	add_motion(
		keybind = .[ KEY_PPAGE ],
		flags = .Y_ONLY,
		proc = #bake_arguments motion_page_step(step = -1),
	);
	add_motion(
		keybind = "{",
		proc = #bake_arguments motion_empty_line(step = -1),
		flags = .RESPECTS_FOLD,
	);
	add_motion(
		keybind = "}",
		proc = #bake_arguments motion_empty_line(step = 1),
		flags = .RESPECTS_FOLD,
	);
	add_motion( // identity motion
		keybind = "!",
		proc = (in: Motion_In) -> Motion_Res {
			return .{
				start = in.window.cursor.position,
				end = in.window.cursor.position,
			};
		}
	);
	add_motion(
		keybind = "m",
		proc = motion_mark,
		char_proc = motion_mark_char,
		flags = .RESPECTS_FOLD,
	);
}

add_motion :: inline ($keybind: $T/.[string, []s32], flags: Motion.Flags = .NONE, proc: Motion.Proc, char_proc: Motion.Char_Proc = null) {
	array_add(*context.edit.motions, .{
		keybind = to_keybind(keybind),
		flags = flags,
		proc = proc,
		char_proc = char_proc,
	});
}