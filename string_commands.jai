

// Not sure about the naming..
// String commands are something that:
// - commands are written in their own buffer/window
// - have history
// Right now, it's only search and exec
String_Command_State :: struct {
	saved_window: *Window = null; // held
	buffer: *Buffer;
	window: *Window;
	// .update must be called after chars get changed, since there might be some string views referencing it..
	chars: [..]u8; 
	#overlay(chars) as_string: string;
	// callbacks:
	// Gonna pass state, but search/exec won't use them...
	execute: #type (*String_Command_State) -> ();
	update: #type (*String_Command_State) -> (); // update is called when chars were changed, in any way
	cancel: #type (*String_Command_State) -> ();
}

string_commands_start :: (state: *String_Command_State, start_text: string) {
	using state;
	//
	if saved_window {
		release(saved_window);
		saved_window = null;
	}
	saved_window = context.buffer_window;
	hold(saved_window);
	// Create new line if needed
	if window.lines[window.lines.count-1].count != 0 {
		execute_buffer_operation(window, .{
			kind = .INSERT_LINES,
			y = window.lines.count,
			count = 1,
			lines = .[ "" ],
		}, even_if_no_caps = true, no_callback = true);
	}
	// TODO: what if start_text is the same as the previous command?
	// Insert start text in new line
	execute_buffer_operation(window, .{
		kind = .INSERT_CHARS,
		y = window.lines.count-1,
		x = 0,
		count = start_text.count,
		chars = cast([]u8)start_text,
	}, even_if_no_caps = true, no_callback = true);
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
	using state;
	if window.cursor.y + 1 != window.lines.count {
		// move last executed line to the front
		line: *Line = *window.lines[window.lines.count-1];
		if line.count > 0 {
			execute_buffer_operation(window, .{
				kind = .INSERT_LINES,
				y = window.lines.count,
				count = 1,
				lines = .[ "" ],
			}, even_if_no_caps = true, no_callback = true);
		}
		execute_buffer_operation(window, .{
			kind = .INSERT_CHARS,
			y = window.lines.count-1,
			x = 0,
			count = window.lines[window.cursor.y].count,
			chars = window.lines[window.cursor.y].chars, // should be fine to pass this reference
		}, even_if_no_caps = true, no_callback = true);
		//array_ordered_remove_by_index(*window.lines, window.cursor.y); // @Leak
		execute_buffer_operation(window, .{
			kind = .ERASE_LINES,
			y = window.cursor.y,
			count = 1,
		}, even_if_no_caps = true, no_callback = true);
		move_cursor_y(window, window.lines.count - 1);
	} else if window.cursor.y > 0 {
		// if last command was the same as the second-last, remove it from history
		if window.lines[window.cursor.y].as_string == window.lines[window.cursor.y-1].as_string {
			execute_buffer_operation(window, .{
				kind = .ERASE_LINES,
				y = window.cursor.y,
				count = 1,
			}, even_if_no_caps = true, no_callback = true);
		}
	}
	if saved_window {
		select_window(saved_window);
		release(saved_window);
		saved_window = null;
	} else {
		// this only happens you get into some nonsense window-jumping
		select_normal_window();
	}
	change_edit_mode(.COMMAND);
	if state.execute
		state.execute(state);
}

string_commands_cancel :: (state: *String_Command_State) {
	using state;
	if window.cursor.y + 1 == window.lines.count {
		// *clear* last line! (it's fine if it exists as empty, i think)
		y := window.cursor.y;
		if window.lines[y].count > 0 {
			execute_buffer_operation(window, .{
				kind = .ERASE_CHARS,
				y = y,
				count = window.lines[y].count,
			}, even_if_no_caps = true, no_callback = true);
		}
	}
	if saved_window {
		select_window(saved_window);
		release(saved_window);
		saved_window = null;
	} else {
		// this only happens you get into some nonsense window-jumping
		select_normal_window();
	}
	change_edit_mode(.COMMAND);
}

string_commands_ensure_up_to_date :: (state: *String_Command_State) {
	using state;
	s := window.lines[window.cursor.y].as_string;
	if s != state.as_string {
		array_reset(*state.chars);
		array_adds(*state.chars, s);
		if state.update
			state.update(state);
	}
}

string_commands_init :: (state: *String_Command_State, title: string) {
	using state;
	//
	buffer = create_custom_buffer();
	buffer.flags |= .NO_SEARCH; // might want this later?
	buffer.caps |= .MODE_INSERT | .MODE_COMMAND;
	buffer.caps |= .INSERT_CHARS | .DELETE_CHARS;
	buffer.caps |= .MOVE;
	buffer.modify_buffer_operation = (win: *Window, op: *Buffer_Op) -> bool {
		// this if should be only if insert/delete chars, i think...
		if win.cursor.y != win.lines.count - 1 {
			line: *Line = *win.lines[win.lines.count-1];
			if line.count > 0 {
				//array_reset(*line.chars);
				execute_buffer_operation(win, .{
					kind = .ERASE_CHARS,
					y = win.lines.count - 1,
					x = 0,
					count = line.count,
				}, even_if_no_caps = true, no_callback = true);
			}
			execute_buffer_operation(win, .{
				kind = .INSERT_CHARS,
				y = win.lines.count - 1,
				x = 0,
				chars = win.lines[win.cursor.y].chars,
				count = win.lines[win.cursor.y].count,
			}, even_if_no_caps = true, no_callback = true);
			move_cursor_y(win, win.lines.count - 1);
			op.y = win.cursor.y;
		}
		return true;
	};
	add_command(*buffer.commands, 
		keybind = "\n",
		mode = .INSERT | .COMMAND,
		proc = (in: Command_In) -> Command_Res {
			state := context.buffer_window.buffer.user_data.(*String_Command_State);
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
	window.user_title = title;
	//
	buffer.user_data = state;
	window.user_data = state;
}