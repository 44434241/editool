

// HMM
// There should this kind of logic here:
// When trying to "start" commands, we *hold* any window but ours, even if it's buffer is the same.
// But, when continuing inputting in the window, we hold any window but that window or ours
// (except for cases where it's not possible to find any other window. I suppose then using our own is fine, but there should be some checks for that)

// Not sure about the naming..
// String commands are something that:
// - commands are written in their own buffer/window
// - have history
// Right now, it's only search and exec
String_Command_State :: struct {
	held_window: *Window = null; // held
	buffer: *Buffer;
	window: *Window;
	// .update must be called after chars get changed, since there might be some string views referencing it..
	chars: [..]u8; 
	#overlay(chars) as_string: string;
	// callbacks:
	// Gonna pass state, but search/exec won't use them...
	execute: #type (*String_Command_State, *Window) -> ();
	update: #type (*String_Command_State, *Window) -> (); // update is called when chars were changed, in any way
	cancel: #type (*String_Command_State, *Window) -> ();
}

string_commands_start :: (state: *String_Command_State, start_text: string) {
	using,except(window) state;
	//window := ifx context.buffer_window.buffer == buffer then context.buffer_window else state.window;
	window := state.window;
	//
	_ensure_window_held(state);
	// IT CRASHES SOMEWHERE HERE??? is start_text referencing something that gets changed?
	// Create new line if needed
	if window.lines[window.lines.count-1].count != 0 {
		execute_buffer_operation(window, .{
			kind = .INSERT_LINES,
			y = window.lines.count,
			count = 1,
			lines = .[ "" ],
			flags = .IGNORE_CAPS | .NO_CALLBACK,
		});
	}
	// Insert start text in new line
	execute_buffer_operation(window, .{
		kind = .INSERT_CHARS,
		y = window.lines.count-1,
		x = 0,
		count = start_text.count,
		chars = cast([]u8)start_text,
		flags = .IGNORE_CAPS | .NO_CALLBACK,
	});
	//
	select_window(window);
	change_edit_mode(.INSERT);
	// make sure cursor x is kept if not start text .. handles 80% of the cases when going through history
	if start_text {
		move_cursor(window, .{ window.lines[window.lines.count-1].count, window.lines.count-1 });
	} else {
		move_cursor_y(window, window.lines.count-1 );
	}
}

string_commands_execute :: (state: *String_Command_State) {
	string_commands_ensure_up_to_date(state);
	using,except(window) state;
	window := ifx context.buffer_window.buffer == buffer then context.buffer_window else state.window;
	if window.cursor.y + 1 != window.lines.count {
		// move last executed line to the front
		line: *Line = *window.lines[window.lines.count-1];
		if line.count > 0 {
			execute_buffer_operation(window, .{
				kind = .INSERT_LINES,
				y = window.lines.count,
				count = 1,
				lines = .[ "" ],
				flags = .IGNORE_CAPS | .NO_CALLBACK,
			});
		}
		execute_buffer_operation(window, .{
			kind = .INSERT_CHARS,
			y = window.lines.count-1,
			x = 0,
			count = window.lines[window.cursor.y].count,
			chars = window.lines[window.cursor.y].chars, // should be fine to pass this reference
			flags = .IGNORE_CAPS | .NO_CALLBACK,
		});
		//array_ordered_remove_by_index(*window.lines, window.cursor.y); // @Leak
		execute_buffer_operation(window, .{
			kind = .ERASE_LINES,
			y = window.cursor.y,
			count = 1,
			flags = .IGNORE_CAPS | .NO_CALLBACK,
		});
		move_cursor_y(window, window.lines.count - 1);
	} else if window.cursor.y > 0 {
		// if last command was the same as the second-last, remove it from history
		if window.lines[window.cursor.y].as_string == window.lines[window.cursor.y-1].as_string {
			execute_buffer_operation(window, .{
				kind = .ERASE_LINES,
				y = window.cursor.y,
				count = 1,
				flags = .IGNORE_CAPS | .NO_CALLBACK,
			});
		}
	}
	_ensure_window_held(state);
	win := state.held_window;
	_ensure_window_released(state);
	select_window(win);
	change_edit_mode(.COMMAND);
	if state.execute
		state.execute(state, win);
}

_ensure_window_held :: (state: *String_Command_State) {
	if state.held_window == null {
		state.held_window = context.buffer_window;
		if state.held_window.buffer == state.buffer {
			// we wanna hold some other window, but the search window is selected...
			// so let's override that with some other random window!
			if state.held_window.is_floating
				state.held_window = get_window(.BUFFER, not_floating = true);
		}
		hold(state.held_window);
	}
}

_ensure_window_released :: (state: *String_Command_State) {
	if state.held_window != null {
		release(state.held_window);
		state.held_window = null;
	}
}

string_commands_cancel :: (state: *String_Command_State) {
	using,except(window) state;
	window := ifx context.buffer_window.buffer == buffer then context.buffer_window else state.window;
	if window.cursor.y + 1 != window.lines.count {
		move_cursor_y(window, window.lines.count - 1);
	}
	if window.cursor.y + 1 == window.lines.count {
		// *clear* last line! (it's fine if it exists as empty, i think)
		y := window.cursor.y;
		if window.lines[y].count > 0 {
			execute_buffer_operation(window, .{
				kind = .ERASE_CHARS,
				y = y,
				count = window.lines[y].count,
				flags = .IGNORE_CAPS | .NO_CALLBACK,
			});
		}
	}
	_ensure_window_held(state);
	win := state.held_window;
	_ensure_window_released(state);
	select_window(win);
	change_edit_mode(.COMMAND);
	if state.cancel
		state.cancel(state, win);
}

string_commands_ensure_up_to_date :: (state: *String_Command_State) {
	using,except(window) state;
	window := ifx context.buffer_window.buffer == buffer then context.buffer_window else state.window;
	win := ifx state.held_window else (ifx context.buffer_window.buffer != buffer then context.buffer_window else get_window(.BUFFER, not_floating = true));
	s := window.lines[window.cursor.y].as_string;
	if s != state.as_string {
		array_reset(*state.chars);
		array_adds(*state.chars, s);
		if state.update
			state.update(state, win);
	}
}

string_commands_init :: (state: *String_Command_State, title: string) {
	using state;
	//
	buffer = create_custom_buffer();
	buffer.flags |= .NO_SEARCH; // might want this later?
	buffer.caps |= .MODE_INSERT | .MODE_COMMAND;
	buffer.caps |= .INSERT_CHARS | .ERASE_CHARS;
	buffer.caps |= .MOVE;
	buffer.modify_buffer_operation = (win: *Window, buf: *Buffer, op: *Buffer_Op) -> bool {
		// this if should be only if insert/delete chars, i think...
		if win != null && win.cursor.y != win.lines.count - 1 {
			line: *Line = *win.lines[win.lines.count-1];
			if line.count > 0 {
				//array_reset(*line.chars);
				execute_buffer_operation(win, .{
					kind = .ERASE_CHARS,
					y = win.lines.count - 1,
					x = 0,
					count = line.count,
					flags = .IGNORE_CAPS | .NO_CALLBACK,
				});
			}
			execute_buffer_operation(win, .{
				kind = .INSERT_CHARS,
				y = win.lines.count - 1,
				x = 0,
				chars = win.lines[win.cursor.y].chars,
				count = win.lines[win.cursor.y].count,
				flags = .IGNORE_CAPS | .NO_CALLBACK,
			});
			move_cursor_y(win, win.lines.count - 1);
			op.y = win.cursor.y;
		}
		return true;
	};
	add_command(*buffer.commands, 
		keybind = "\n",
		mode = .INSERT | .COMMAND,
		proc = (in: Command_In) -> Command_Res {
			state := in.window.buffer.user_data.(*String_Command_State);
			if !state
				return command_error("Not the right buffer?");
			string_commands_execute(state);
			return .{};
		},
	);
	add_command(*buffer.commands, 
		keybind = .[ KEY_ESCAPE ],
		mode = .INSERT | .COMMAND,
		proc = (in: Command_In) -> Command_Res {
			state := context.buffer_window.buffer.user_data.(*String_Command_State);
			string_commands_cancel(state);
			return .{};
		},
	);
	window = create_buffer_window(context.edit.second_root, buffer,
			select = false, is_hidden = false);
	add_flags(window, .BUFFER_LINE_NO);
	buffer.user_title = title;
	//
	buffer.user_data = state;
	window.user_data = state;
}