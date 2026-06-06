
Command :: struct {
	Proc :: #type (Command_In) -> Command_Result;
	Motion_Proc :: #type (Command_In, Motion_Result) -> Command_Result;
	Char_Proc :: #type (Command_In, s32) -> Command_Result;
	name: string;
	keybind: Keybind;
	proc: Proc;
	motion_proc: Motion_Proc;
	char_proc: Char_Proc;
}

Command_Result :: struct {
	Status :: enum {
		OK;
		CONTINUE_MOTION; // this command expects a motion?
		CONTINUE_CHAR; // this command expects a printable char
		ERROR; // something went wrong?
	}
	status: Status = .OK;
	error_message: string;
	continue_no_number := false; // whatever continues, don't give it a number?
}

Command_Input :: struct {
	number: int = 1; // > 0
}

Command_In :: Command_Input;

/*
// maybe dont return pointer?
get_command :: (keybind: string) -> *Command {
	if !keybind
		return null;
	for * context.edit.commands {
		if keybind_matches(it.keybind, keybind)
			return it;
	}
	return null;
}
*/

// this could recurse, actually..
make_command_alias :: ($chars: $T/.[ []s32, string ]) -> Command.Proc {
	inner_proc :: (in: Command_In) -> Command_Result {
		
		inserted_input: [..]s32;
		for tprint("%", in.number)
			array_add(*inserted_input, it);
		for chars
			array_add(*inserted_input, it);
		insert_tty_input(inserted_input);
		return .{};
	}
	return inner_proc;
}

command_quit :: (_: Command_In) -> Command_Result {
	context.edit.should_quit = true;
	return .{};
}

command_motion :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

command_motion_motion :: (in: Command_In, motion_res: Motion_Result) -> Command_Result {
	if motion_res.status != .OK  {
		return .{
			status = .ERROR,
			error_message = "Why did you pass me a failed motion result",
		};
	}
	move_cursor(motion_res, in.number);
	//move_cursor(context.edit.current_buffer, motion_res.end);
	return .{ status = .OK };
}

wrap_command :: ($proc : #type () -> ()) -> Command.Proc {
	inner_proc :: (_: Command_In) -> Command_Result {
		proc();
		return .{};
	}
	return inner_proc;
}

command_delete_line :: (in: Command_In) -> Command_Result {
	delete_lines(context.current_buffer, context.current_buffer.cursor.y, in.number);
	return .{};
}

command_delete :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

command_delete_motion :: (in: Command_In, motion: Motion_Result, enter_insert_mode: bool) -> Command_Result {
	buf := context.current_buffer;
	if motion.start.y != motion.end.y {
		delete_line_range(buf, motion.start.y, motion.start.y + (motion.end.y - motion.start.y) * in.number);
	} else {
		delete_range_in_line(buf, motion.start.y, motion.start.x, motion.start.x + (motion.end.x - motion.start.x) * in.number);
	}
	if enter_insert_mode
		change_edit_mode(.INSERT);
	return .{};
}

command_scroll_offset :: (in: Command_In, step: int) -> Command_Result {
	assert(step == -1 || step == 1);
	buf := context.current_buffer;
	offset_scroll(buf, step * in.number);
	return .{};
}

command_scroll_center :: (in: Command_In) -> Command_Result {
	buf := context.current_buffer;
	scroll := buf.cursor.y - buf.size.y / 2;
	set_scroll(buf, scroll);
	return .{};
}

command_undo :: (in: Command_In) -> Command_Result {
	buf := context.current_buffer;
	for iter: 1..in.number {
		last_op := peek_last_operation(buf);
		if last_op == null
			break;
		ok, op := undo(buf);
		if !ok
			break;
		while true {
			op := peek_last_operation(buf);
			if op == null
				break;
			if !_buffer_operations_can_be_merged(last_op, op)
				break;
			ok := undo(buf);
			if !ok
				break;
			// last_op = op; // ?
		}
	}
	return .{};
}

command_redo :: (in: Command_In) -> Command_Result {
	buf := context.current_buffer;
	for iter: 1..in.number {
		next_op := peek_next_operation(buf);
		if next_op == null
			break;
		ok, op := redo(buf);
		if !ok
			break;
		while true {
			op := peek_next_operation(buf);
			if op == null
				break;
			if !_buffer_operations_can_be_merged(next_op, op)
				break;
			ok := redo(buf);
			if !ok
				break;
			// next_op = op; // ?
		}
	}
	return .{};
}

command_replace :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_CHAR, continue_no_number = true };
}

command_replace_char :: (in: Command_In, char: s32) -> Command_Result {
	if !is_printable_char(char) {
		return .{ status = .ERROR, error_message = "Not printable char" };
	}
	buf := context.current_buffer;
	pos := buf.cursor.position;
	delete_at_x_offset(buf, 0);
	write_char(buf, xx char);
	move_cursor(buf, pos);
	return .{ status = .OK };
}

_buffer_operations_can_be_merged :: (l: Buffer_Op, r: Buffer_Op) -> bool {
	if l.kind == r.kind {
		if (l.kind == .INSERT_CHARS || l.kind == .DELETE_CHARS) && l.begin_cursor_position.y == r.begin_cursor_position.y {
			return true;
		}
	}
	if l.begin_time == r.begin_time
		return true;
	return false;
}
