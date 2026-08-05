
Waiting_Chars :: struct {
	number: int = 0;
	chars: [..]s32;
	no_number := false;
}

waiting_chars_reset :: (waiting: *Waiting_Chars) {
	waiting.number = 0;
	array_reset(*waiting.chars);
}

// Returns true if chars was added (and therefore there might be a new matching command)
waiting_chars_add :: (waiting: *Waiting_Chars, ch: s32) -> bool {
	if waiting.chars.count == 0 && is_digit(ch) && !waiting.no_number {
		digit := ch - #char "0";
		//if waiting.number == 0 && digit != 0
			//waiting.number = 1;
		waiting.number = waiting.number * 10 + digit;
		return false;
	}
	array_add(*waiting.chars, ch);
	return true;
}

// for now, only a command is waiting for a motion
Waiting_For_Motion :: struct {
	#as using _: Waiting_Chars;
	command: *Command; // pointer i guess..
	command_in: Command_In;
}

// either a motion + waiting for motion, or command
Waiting_For_Char :: struct {
	#as using _: Waiting_Chars;
	motion: *Motion; // pointer i guess..
	command: *Command;
	// a waiting command asked for this motion, and the result will be given to it
	waiting_for_motion_index: int = -1;  // if motion != null
	motion_in: Motion_In;
	command_in: Command_In;
}

Command_State :: struct {
	#as using _: Waiting_Chars;
	all_chars: [..]s32;
	//#overlay(chars) str: string
	waiting_for_motion: [..]Waiting_For_Motion;
	waiting_for_char: [..]Waiting_For_Char;
}

execute_motion :: (motion: *Motion, number: int = 1, window: *Window = null) -> Motion_Res, Motion_In {
	if window == null
		window = context.buffer_window;
	in := Motion_In.{
		number = max(number, 1),
		window = window,
	};
	if in.window.map_window_for_motion {
		in.window = in.window.map_window_for_motion(in.window, motion);
	}
	res := motion.proc(in);
	res.window = in.window;
	if !res.buffer 
		res.buffer = res.window.buffer;
	res.motion = motion;
	return res, in;
}


execute_motion :: (motion: *Motion, in: Motion_In, char: s32) -> Motion_Res {
	assert(motion.char_proc != null);
	res := motion.char_proc(in, char);
	res.window = in.window;
	if !res.buffer 
		res.buffer = res.window.buffer;
	res.motion = motion;
	return res;
}


push_dot_command :: () {
	using context.edit;
	log("update dot command (% -> %)", current_dot_command, next_dot_command);
	if next_dot_command.count > 0 {
		array_reset(*current_dot_command);
		current_dot_command = next_dot_command;
		next_dot_command = default_of([..]s32);
	}
}

enter_command_mode :: () {
	push_dot_command();
	handle_command_step();
}

exit_command_mode :: () {
	_reset_command_mode();
}

_reset_command_mode :: () {
	log("resetting command mode");
	using context.command_state;
	array_reset(*waiting_for_char);
	array_reset(*waiting_for_motion); // @Leak
	array_reset(*all_chars); 
	waiting_chars_reset(*context.command_state); 
	if context.edit.mode == .COMMAND {
		handle_command_step();
	}
}

handle_command_char :: (ch: s32) {
	// printable ch!
	should_reset := true;
	found_command := false;
	for *waiting: context.command_state.waiting_for_char {
		if !waiting_chars_add(waiting, ch) {
			should_reset = false;
			continue;
		}
		if waiting.chars.count > 1
			continue; // this might happen in the future?
		assert(waiting.chars.count == 1);
		assert(waiting.chars[0] == ch);
		if waiting.motion != null {
			in := waiting.motion_in;
			in.number *= max(1, waiting.number);
			//assert(waiting.motion.char_proc != null);
			//res := waiting.motion.char_proc(in, ch);
			res := execute_motion(waiting.motion, in, ch);
			waiting_for_motion: *Waiting_For_Motion = *context.command_state.waiting_for_motion[waiting.waiting_for_motion_index];
			reset := _handle_motion_result(waiting.motion, in, res, waiting_for_motion, waiting.waiting_for_motion_index);
			should_reset &&= reset;
		} else {
			assert(waiting.command != null);
			in := waiting.command_in;
			in.number *= max(1, waiting.number);
			assert(waiting.command.char_proc != null);
			res := waiting.command.char_proc(in, xx ch);
			reset := _handle_command_result(waiting.command, in, res);
			should_reset &&= reset;
		}
		found_command = true;
	}
	for *waiting, waiting_idx:  context.command_state.waiting_for_motion {
		if found_command
			break;
		assert(waiting.command.motion_proc != null);
		if !waiting_chars_add(waiting, ch) {
			should_reset = false;
			continue;
		}
		// thisis slow ?
		for * context.edit.motions {
			if keybind_matches(it.keybind, waiting.chars) {
				res, in := execute_motion(it, waiting.number);
				reset := _handle_motion_result(it, in, res, waiting, waiting_idx, can_char = true);
				should_reset &&= reset;
				found_command = true;
				break waiting;
			}
			if keybind_matches_start(it.keybind, waiting.chars)
				should_reset = false;
		}
	}
	array_add(*context.command_state.all_chars, ch);
	should_try_more_commands := waiting_chars_add(*context.command_state, ch);
	if !found_command {
		if should_try_more_commands {
			step_reset, step_command := handle_command_step();
			should_reset &= step_reset;
			found_command |= step_command;
		} else {
			should_reset = false;
		}
	}
	if should_reset {
		if !found_command {
			array_reset(*context.edit.next_dot_command);
			should_alert := true;
			if context.command_state.chars.count == 1 && context.command_state.chars[0] == KEY_ESCAPE
				should_alert = false;
				
			// doesn't print numbers here..
			if should_alert
				edit_alert("Didn't find command: '%'\n", keybind_to_string(context.command_state.chars,, allocator=temp));
		} else { // found_command
		}
		_reset_command_mode();
		return;
	}
}

// At the end there's either.
// 1. No command matched, but there's possible commands waiting. Don't reset.
// 2. No command matched, and there's no more commands waiting. Reset.
// 3. A command matched, but it should continue. Doesn't count as a match. Don't reset.
// 4. A command matched, but it failed. Reset.
// 5. A command matched and it was ok. Should keep it's result. Reset.

// Handles command step but only for commands (not waiting motions or chars or anything else).
// Returns true if it should continue.
// Now with commands from the buffer !
handle_command_step :: () -> (should_reset: bool, found_command: bool) {
	found_command := false;
	should_reset := true;
	{
		win := get_selected_window_of_kind(.BUFFER);
		if win {
			// thats fairly simple actually.....
			for * win.buffer.commands {
				if keybind_matches(it.keybind, context.command_state.chars) {
					in := Command_In.{
						number = max(1, context.command_state.number),
						window = context.buffer_window,
					};
					res := it.proc(in); 
					log("Found command '%' - %\n", keybind_to_string(it.keybind), res);
					reset := _handle_command_result(it, in, res, can_motion = true, can_char = true);
					should_reset &&= reset;
					found_command = true;
					break;
				}
				if keybind_matches_start(it.keybind, context.command_state.chars) {
					should_reset = false;
				}
			}
		}
	}
	for get_current_valid_commands(.COMMAND) {
		if keybind_matches(it.keybind, context.command_state.chars) {
			in := Command_In.{
				number = max(1, context.command_state.number),
				window = context.buffer_window,
			};
			res := it.proc(in); 
			log("Found command '%' - %\n", keybind_to_string(it.keybind), res);
			reset := _handle_command_result(it, in, res, can_motion = true, can_char = true);
			should_reset &&= reset;
			found_command = true;
			break;
		}
		if keybind_matches_start(it.keybind, context.command_state.chars) {
			log("shouldn't reset?");
			should_reset = false;
		}
	}
	return should_reset, found_command;
}

_handle_command_result :: (command: *Command, in: Command_In, res: Command_Result, can_motion := false, can_char := false, dont_touch_dot := false) -> (should_reset: bool) {
	if res.status == {
		case .OK;
			if !dont_touch_dot {
				if res.inserted_chars {
					array_reset(*context.edit.next_dot_command);
				}
				if context.edit.added_chars.count == 0 {
					if !res.modifies_dot {
						array_reset(*context.edit.next_dot_command);
					} else {
						if context.edit.mode == .COMMAND {
							push_dot_command();
						}
					}
				}
			}
			return true;
		case .ERROR;
			array_reset(*context.edit.next_dot_command);
			if res.error_message
				edit_alert("Command '%' failed: %", keybind_to_string(command.keybind), res.error_message);
			else
				edit_alert("Command '%' failed", keybind_to_string(command.keybind));
			return true;
		case .CONTINUE_MOTION;
			if !can_motion {
				edit_alert("Command cannot continue motion!");
				return true;
			}
			array_add(*context.command_state.waiting_for_motion, .{
				no_number = res.continue_no_number,
				command = command,
				command_in = in,
			});
			return false;
		case .CONTINUE_CHAR;
			if !can_char {
				edit_alert("Command cannot continue char!");
				return true;
			}
			array_add(*context.command_state.waiting_for_char, .{
				no_number = res.continue_no_number,
				command = command,
				command_in = in,
			});
			return false;
		case;
			array_reset(*context.edit.next_dot_command);
			edit_alert("BAD command status: %\n", res.status);
			return true;
	}
}

// optionally returns command result, if any was executed
_handle_motion_result :: (motion: *Motion, in: Motion_In, res: Motion_Result, waiting: *Waiting_For_Motion,
		waiting_idx: int, can_char := false) -> (should_reset: bool) {
	if res.status == {
		case .OK;
			assert(waiting.command != null);
			assert(waiting.command.motion_proc != null);
			if res.window.buffer != res.buffer && waiting.command.flags & .ALLOW_DIFFERENT_BUFFER == 0 {
				edit_alert("Motion to different buffer disallowed with '%' command (% %)",
						keybind_to_string(waiting.command.keybind), res.window.buffer, res.buffer);
				return true;
			}
			command_res := waiting.command.motion_proc(waiting.command_in, res);
			return _handle_command_result(waiting.command, waiting.command_in, command_res, can_char = can_char);
		case .CONTINUE_CHAR;
			if !can_char {
				edit_alert("Motion cannot continue char!\n");
				return true;
			}
			array_add(*context.command_state.waiting_for_char, .{
				no_number = res.continue_no_number,
				motion_in = in,
				motion = motion,
				waiting_for_motion_index = waiting_idx,
			});
			return false;
		case .ERROR;
			if res.error_message
				edit_alert("Motion '%' failed: %", keybind_to_string(motion.keybind), res.error_message);
			else
				edit_alert("Motion '%' failed", keybind_to_string(motion.keybind));
			return true;
	}
	edit_alert("BAD motion status: %\n", res.status);
	return true;
}