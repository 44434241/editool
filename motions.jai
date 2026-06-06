

// start/end could be reversed, depending on the motion
Motion_Result :: struct {
	Flags :: enum_flags {
		X_ONLY;
		Y_ONLY;
		NONE :: 0;
	}
	Status :: enum {
		OK;
		ERROR;
		CONTINUE_CHAR; // this motion expects a printable char
	}
	status: Status = .OK;
	flags: Flags = .NONE;
	start: Vec2i = .{ -1, -1 };
	end: Vec2i = .{ -1, -1 };
	continue_no_number: bool = false;
	error_message: string; // not printed rn
}

Motion_Input :: struct {
	number: int = 1; // > 0
}

Motion_In :: Motion_Input;

Motion :: struct {
	Flags :: enum_flags {
		SUPPORTS_NUMBER; // idk..
		NONE :: 0;
	}
	flags: Flags; // not used..
	Proc :: #type (Motion_Input) -> Motion_Result;
	Char_Proc :: #type (Motion_Input, s32) -> Motion_Result;
	keybind: Keybind;
	proc: Proc;
	char_proc: Char_Proc; // is .CONTINUE_CHAR
}

get_motion :: (keybind: $T/.[[]s32, string]) -> *Motion {
	for * context.edit.motions {
		if keybind_matches(it.keybind, keybind)
			return it;
	}
	return null;
}

// this could recurse, actually..
// works a bit differently than commands.. won't handle motions that get called again!
make_motion_alias :: ($chars: $T/.[ []s32, string ]) -> Motion.Proc {
	inner_proc :: (in: Motion_In) -> Motion_Result {
		motion := get_motion(chars);
		if !motion {
			return .{ status = .ERROR, error_message = "Can't find motion alias" };
		}
		return motion.proc(in);
	}
	return inner_proc;
}

find_char_in_line :: (ch: u8, opposite_ch: u8, step: int, count: int) -> int {
	x := context.current_buffer.cursor.x;
	if step < 0
		x -= 1;
	return find_char_in_line(x, ch, opposite_ch, step, count);
}

find_char_in_line :: (x: int, ch: u8, opposite_ch: u8, step: int, count: int) -> int {
	assert(step == 1 || step == -1);
	line := *context.current_buffer.lines[context.current_buffer.cursor.y];
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

motion_inner :: (in: Motion_In, $ch: u8, $inclusive: bool) -> Motion_Result {
	left_x, right_x: int = ---;
	// TODO: weird bug with deleting exclusive inner ()[], deletes ()[] too..
	#if ch == "(" || ch == ")" {
		left_x = find_char_in_line("(", ")", -1, in.number);
		right_x = find_char_in_line(")", "(", 1, in.number);
		//
	} else #if ch == "[" || ch == "]" {
		left_x = find_char_in_line("[", "]", -1, in.number);
		right_x = find_char_in_line("]", "[", 1, in.number);
		//
	} else #if ch == "\"" || ch == " " || ch == "'" {
		left_x = find_char_in_line(ch, 0, -1, in.number);
		right_x = find_char_in_line(ch, 0, 1, in.number);
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
	cursor := context.current_buffer.cursor;
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
	using buf := context.edit.current_buffer;
	assert(step == 1 || step == -1);
	line := *buf.lines[cursor.y];
	// TODO: early returns don't support number (though it doesn't matter that much, maybe its better?)
	if step > 0 && cursor.x >= line.count {
		return .{
			start = cursor.position,
			end = ifx cursor.position.y + 1 < lines.count then Vec2i.{ 0, cursor.position.y + 1 } else cursor.position,
		};
	}
	if step < 0 && cursor.x <= 0 {
		return .{
			start = cursor.position,
			end = ifx cursor.y > 0 then Vec2i.{ lines[cursor.y-1].count, cursor.y - 1 } else cursor.position,
		};
	}
	next_x := min(cursor.x, line.count-1);
	//x_ok :: () -> bool #expand {
		//return clamp(next_x + step, 0, line.count) == next_x + step;
	//}
	is_alunder :: (ch: u8) -> bool {
 		return is_alpha(ch) || ch == #char "_";
	}
	x_ok :: () -> bool #expand {
		return clamp(next_x, 0, line.count-1) == next_x;
	}
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
		log("next x: %\n", next_x);
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
	if !is_printable_char(char) {
		return .{ status = .ERROR };
	}
	x := context.current_buffer.cursor.x + step;
	idx := find_char_in_line(x, xx char, 0, step, in.number);
	if idx < 0 {
		return .{ status = .ERROR };
	}
	if !inclusive
		idx -= step;
	buf := context.edit.current_buffer;
	return .{
		start = buf.cursor.position,
		end = .{ idx, buf.cursor.position.y },
		flags = .X_ONLY,
	};
}

motion_page_step :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	buf := context.current_buffer;
	return .{
		start = buf.cursor.position,
		end = .{ x = buf.cursor.x, y = buf.cursor.y + step * buf.size.y * in.number },
		flags = .Y_ONLY,
	};
}

motion_step :: (in: Motion_In, step: Vec2i) -> Motion_Result {
	assert(step.x == 0 || step.y == 0);
	assert(step.x != 0 || step.y != 0);
	buf := context.current_buffer;
	return .{
		start = buf.cursor.position,
		end = buf.cursor.position + step * in.number,
		flags = ifx step.y == 0 then .X_ONLY else .Y_ONLY,
	};
}

// either start of line or end of line
// Number unsupported here, don't know how to define that..
motion_end_of_line  :: (_: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	buf := context.current_buffer;
	x := ifx step < 0 then 0 else buf.lines[buf.cursor.y].count;
	return .{
		start = buf.cursor.position,
		end = .{ x, buf.cursor.y },
		flags = .X_ONLY,
	};
}

// either start of line of file
// TODO: Should define that it supports 0 number ?
motion_end_of_file  :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	buf := context.current_buffer;
	y := ifx step < 0 then 0 else buf.lines.count - 1;
	if in.number > 1
		y = in.number;
	return .{
		start = buf.cursor.position,
		end = .{ buf.cursor.x, y },
		flags = .Y_ONLY,
	};
}

motion_empty_line  :: (in: Motion_In, step: int) -> Motion_Result {
	assert(step == 1 || step == -1);
	buf := context.current_buffer;
	to_find := in.number;
	y := buf.cursor.y;
	while true {
		y += step;
		is_eof := clamp(y, 0, buf.lines.count - 1) != y;
		if is_eof || buf.lines[y].count == 0
			to_find -= 1;
		if to_find == 0
			break;
		if is_eof
			return .{ status = .ERROR };
	}
	return .{
		start = buf.cursor.position,
		end = .{ buf.cursor.x, y },
		flags = .Y_ONLY,
	};
}
