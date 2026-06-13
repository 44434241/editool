
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
		// Internal:
		_NOT_A_RESULT;
	}
	Flags :: enum_flags {
		NONE :: 0;
	}
	flags: Flags = .NONE;
	status: Status = .OK;
	error_message: string; // this will be tprinted or allocated !!
	continue_no_number := false; // whatever continues, don't give it a number?
	modifies_dot := false;
	inserted_chars := false;
}

Command_Input :: struct {
	window: *Window; // .BUFFER 
	number: int = 1; // > 0
}

Command_Res :: Command_Result;
Command_In :: Command_Input;

// this could recurse, actually..
make_command_alias :: ($chars: $T/.[ []s32, string ]) -> Command.Proc {
	inner_proc :: (in: Command_In) -> Command_Result {
		
		inserted_input: [..]s32;
		for tprint("%", in.number)
			array_add(*inserted_input, it);
		for chars
			array_add(*inserted_input, it);
		insert_tty_input(inserted_input);
		return .{
			inserted_chars = true,
		};
	}
	return inner_proc;
}

command_quit :: (_: Command_In) -> Command_Result {
	editool_quit();
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
	//move_cursor(context.edit.buffer_window, motion_res.end);
	return .{ status = .OK };
}

wrap_command :: ($proc : #type () -> ()) -> Command.Proc {
	inner_proc :: (_: Command_In) -> Command_Result {
		proc();
		return .{};
	}
	return inner_proc;
}

wrap_command :: ($proc : #type () -> bool) -> Command.Proc {
	inner_proc :: (_: Command_In) -> Command_Result {
		ok := proc();
		if !ok {
			return .{
				status = .ERROR,
			};
		}
		return .{};
	}
	return inner_proc;
}

_command_continue_motion :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

_command_continue_char :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_CHAR };
}

command_delete :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

command_delete_motion :: (in: Command_In, motion: Motion_Result, enter_insert_mode: bool) -> Command_Result {
	if enter_insert_mode
		change_edit_mode(.INSERT);
	win := in.window;
	copy_motion(win, motion);
	if motion.start.y != motion.end.y {
		delete_line_range(win, motion.start.y, motion.start.y + (motion.end.y - motion.start.y) * in.number);
	} else {
		delete_range_in_line(win, motion.start.y, motion.start.x, motion.start.x + (motion.end.x - motion.start.x) * in.number);
	}
	return .{
		modifies_dot = true,
	};
}

command_delete_line :: (in: Command_In) -> Command_Result {
	using win := in.window;
	copy_line_range(win, cursor.y, cursor.y + in.number - 1); // assumed to not fail?
	delete_lines(win, cursor.y, in.number);
	return .{
		modifies_dot = true,
	};
}

command_yank :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

command_yank_motion :: (in: Command_In, motion: Motion_Result) -> Command_Result {
	win := in.window;
	ok := copy_motion(win, motion);
	if !ok {
		return .{
			status = .ERROR,
		};
	}
	return .{};
}

command_yank_line :: (in: Command_In) -> Command_Result {
	using win := in.window;
	ok := copy_line_range(win, cursor.y, cursor.y + in.number - 1); 
	if !ok {
		return .{
			status = .ERROR,
			error_message = "Cannot yank lines",
		};
	}
	return .{};
}

command_paste :: (in: Command_In, on_next_char: bool) -> Command_Result {
	ok := true;
	for 1..in.number {
		ok &&= _paste(in.window, on_next_char);
		if !ok
			break;
	}
	if !ok {
		return .{
			status = .ERROR,
			error_message = "Can't paste",
		};
	}
	return .{};
}

// this one is only used by commands
_buffer_operations_can_be_merged :: (prev: Buffer_Op, next: Buffer_Op) -> bool {
	if prev.kind == next.kind {
		if (prev.kind == .INSERT_CHARS || prev.kind == .DELETE_CHARS) {
			if prev.y == next.y && abs(prev.x - next.x) <= 1
				return true;
		}
	}
	if prev.begin_time == next.begin_time
		return true;
	if prev.kind == .NOP
		return true;
	return false;
}

command_undo :: (in: Command_In) -> Command_Result {
	win := in.window;
	iter_count := 0;
	for iter: 1..in.number {
		prev_ok, prev_op := peek_last_operation(win.buffer);
		if !prev_ok
			break;
		ok1, _ := buffer_undo(win);
		if !ok1
			break;
		while true {
			next_ok, next_op := peek_last_operation(win.buffer);
			if !next_ok
				break iter;
			if !_buffer_operations_can_be_merged(prev_op, next_op)
				break;
			ok2, _ := buffer_undo(win);
			if !ok2
				break iter;
			prev_op = next_op;
		}
		iter_count += 1;
	}
	if iter_count == 0 {
		return command_error("Can't undo");
	}
	return .{};
}

command_redo :: (in: Command_In) -> Command_Result {
	win := in.window;
	iter_count := 0;
	for iter: 1..in.number {
		prev_ok, prev_op := peek_next_operation(win.buffer);
		if !prev_ok
			break;
		ok1, _ := buffer_redo(win);
		if !ok1
			break;
		while true {
			next_ok, next_op := peek_next_operation(win.buffer);
			if !next_ok
				break iter;
			if !_buffer_operations_can_be_merged(prev_op, next_op)
				break;
			ok2, _ := buffer_redo(win);
			if !ok2
				break iter;
			prev_op = next_op;
		}
		iter_count += 1;
	}
	if iter_count == 0 {
		return command_error("Can't redo");
	}
	return .{};
}

command_search :: (in: Command_In) -> Command_Result {
	//return .{ status = .CONTINUE_MOTION };
	return command_search_motion(in, execute_motion(get_motion("iw")));
}

command_search_motion :: (in: Command_In, motion: Motion_Res) -> Command_Result {
	if motion.status != .OK
		return command_error();
	if !(motion.flags & .X_ONLY) {
		return command_error("Expected x motion");
	}
	start := normalize_position(in.window, motion.start, .COMMAND);
	end := normalize_position(in.window, motion.end, .COMMAND);
	line := *in.window.lines[start.y];
	// need some normalize_motion_result() ?
	if !line.count
		return command_error();
	if end.x < start.x
		return command_error();
	s := string.{ data = line.chars.data + start.x, count = (end.x - start.x) + 1};
	start_search(s);
	return .{};
}

command_jump_search :: (in: Command_In, step: int) -> Command_Result {
	assert(step != 0);
	ok := go_to_search_match_offset(step * in.number, jump = true);
	if !ok {
		return .{
			status = .ERROR,
			error_message = "Can't jump to search!",
		};
	}
	return .{};
}

// replace a *single* character under the cursor
command_replace :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_CHAR, continue_no_number = true };
}

command_replace_char :: (in: Command_In, char: s32) -> Command_Result {
	if !is_printable_char(char) {
		return .{
			status = .ERROR,
			error_message = tprint("Not printable char: %", keybind_to_string(.[ char ])),
		};
	}
	win := in.window;
	pos := win.cursor.position;
	delete_chars(win, pos, 1);
	write_char(win, pos, xx char);
	move_cursor(win, pos);
	return .{
		modifies_dot = true,
	};
}

// not used
command_nop :: (_: Command_In) -> Command_Result {
	return .{ status = .OK };
}

command_indent :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_MOTION };
}

command_indent_indent :: (in: Command_In, step: int) -> Command_Result {
	assert(step == 1 || step == -1);
	using win := in.window;
	_do_indent(in.window, cursor.y, cursor.y + in.number - 1, step);
	return .{
		modifies_dot = true,
	};
}

// this is kinda specific
command_go_to_indent_start :: (in: Command_In, enter_insert_mode: bool) -> Command_Result {
	using win := in.window;
	line := *lines[cursor.y];
	for 0..line.count {
		if it < line.count && line.chars[it] == #char "\t"
			continue;
		if enter_insert_mode {
			change_edit_mode(.INSERT);
		}
		move_cursor_x(win, it);
		return .{
			modifies_dot = enter_insert_mode,
		};
	}
	assert(false);
	return .{ status = .ERROR };
}

command_indent_motion :: (in: Command_In, motion: Motion_Result, step: int) -> Command_Result {
	assert(step == 1 || step == -1);
	using win := in.window;
	if motion.start.x == motion.start.x {
		ly := motion.start.y;
		ry := motion.end.y;
		if ly > ry
			ly, ry = ry, ly;
		_do_indent(in.window, ly, ry, step * in.number);
		return .{
			modifies_dot = true,
		};
	} 
	return .{
		status = .ERROR,
		error_message = "Expected line-wise motion"
	};
}

// TODO: doesn't have any logic for interpreting tabs as spaces!!
// count can be negative?
_do_indent :: (using win: *Window, ly: int, ry: int, count: int) {
	TABS :: #run -> string {
		chars: [..]u8;
		for 1..256
			array_add(*chars, #char "\t");
		return cast(string)chars; // jai copies this, right??
	};
	if count > TABS.count {
		log_error("why are you indenting so much???");
		count = TABS.count;
	}
	ly = clamp(ly, 0, win.lines.count-1);
	ry = clamp(ry, 0, win.lines.count-1);
	for y: ly..ry {
		if count > 0 {
			extra_spaces := 0;
			for win.lines[y].chars {
				if it != #char " "
					break;
				extra_spaces += 1;
			}
			here_count := count;
			if extra_spaces > 0 {
				// i don't care about this but it should probably work for << too..
				here_count += (extra_spaces) / 4;
				delete_range_in_line(win, y, 0, extra_spaces);
			}
			here_count = min(TABS.count, here_count);
			_write_normal_string(win, .{0, y}, string.{ data = TABS.data, count = here_count });
		} else {
			// THINK: might wanna have some logic, where if it can't currently un-indent all, it doesn't indent?
			// Though that's kinda annoying since there'd be no proper visual feedback on what went wrong.
			cnt := 0;
			for x: 0..(-count)-1 {
				if x >= lines[y].count
					break;
				if lines[y].chars[x] != #char "\t"
					break;
				cnt += 1;
			}
			if cnt > 0
				delete_range_in_line(win, y, 0, cnt-1);
		}
	}
}

command_mark_create :: (_: Command_In) -> Command_Result {
	return .{ status = .CONTINUE_CHAR, continue_no_number = true };
}

command_mark_create_char :: (in: Command_In, char: s32) -> Command_Result {
	// logic for mark names happens here...
	if !is_alnum(char) {
		return .{
			status = .ERROR,
			error_message = "Invalid mark name",
		};
	}
	win := in.window;
	m := create_mark(win);
	m.name = xx char;
	set_mark(win.buffer, m);
	return .{};
}

command_cursor_undo :: (in: Command_In) -> Command_Result {
	ok: bool = false;
	for 1..in.number {
		here_ok := cursor_undo(in.window);
		if !here_ok
			break;
		ok = true;
	}
	if !ok return .{
		status = .ERROR,
		error_message = "Cannot jump back",
	};
	return .{};
}

command_cursor_redo :: (in: Command_In) -> Command_Result {
	ok: bool = false;
	for 1..in.number {
		here_ok := cursor_redo(in.window);
		if !here_ok
			break;
		ok = true;
	}
	if !ok return .{
		status = .ERROR,
		error_message = "Cannot jump forward",
	};
	return .{};
}

command_change_edit_mode :: (in: Command_In, mode: Edit_Mode) -> Command_Res {
	change_edit_mode(mode);
	return .{
		modifies_dot = mode == .INSERT,
	};
}

command_delete_chars :: (in: Command_In) -> Command_Result {
	win := in.window;
	if !delete_chars(win, in.number) {
		return .{
			status = .ERROR,
		};
	}
	return .{
		modifies_dot = true,
	};
}

// Messes up if one of the repeated commands fails !!
command_dot :: (in: Command_In) -> Command_Result {
	if !context.edit.current_dot_command {
		return .{
			status = .ERROR,
			error_message = "No dot command",
		};
	}
	tmp: [..]s32;
	tmp.allocator = temp;
	for 1..in.number {
		array_add(*tmp, .. context.edit.current_dot_command);
	}
	edit_alert("Executing dot: '%'", keybind_to_string(tmp));
	insert_tty_input(tmp);
	return .{
		modifies_dot = false, // explicit
		inserted_chars = true,
	};
}

command_relative_window :: (in: Command_In, step: int, mode: Window.Container_Mode) -> Command_Result {
	ok := select_relative_window(step * in.number, mode);
	if !ok {
		return .{ status = .ERROR };
	}
	return .{};
}

add_all_commands :: () {
	// COMMANDS
	add_command(
		keybind = "",
		proc = command_motion,
		motion_proc = command_motion_motion,
	);
	add_command(
		keybind = "q",
		proc = command_quit,
	);
	add_command(
		keybind = "i",
		proc = #bake_arguments command_change_edit_mode(mode = .INSERT),
	);
	add_command(
		keybind = "/",
		proc = #run wrap_command(#bake_arguments start_search(start = "")),
	);
	add_command(
		keybind = ":",
		proc = #run wrap_command(start_exec),
	);
	add_command(
		keybind = "A",
		proc = make_command_alias(.[ #char "i", KEY_END ]),
	);
	add_command(
		keybind = "I",
		//proc = make_command_alias(.[ KEY_HOME, #char "i" ]),
		proc = #bake_arguments command_go_to_indent_start(enter_insert_mode = true),
	);
	add_command(
		keybind = "d",
		proc = command_delete,
		motion_proc = #bake_arguments command_delete_motion(enter_insert_mode = false),
	);
	add_command(
		keybind = "dd",
		proc = command_delete_line,
	);
	add_command(
		keybind = "y",
		proc = command_yank,
		motion_proc = command_yank_motion,
	);
	add_command(
		keybind = "yy",
		proc = command_yank_line,
	);
	add_command(
		keybind = "p",
		proc = #bake_arguments command_paste(on_next_char = true),
	);
	add_command(
		keybind = "P",
		proc = #bake_arguments command_paste(on_next_char = false),
	);
	add_command(
		keybind = "c",
		proc = command_delete,
		motion_proc = #bake_arguments command_delete_motion(enter_insert_mode = true),
	);
	add_command(
		keybind = "D",
		proc = make_command_alias(.[ #char "d", #char "$" ]),
	);
	add_command(
		keybind = "C",
		proc = make_command_alias(.[ #char "c", #char "$" ]),
	);
	add_command(
		keybind = "Y",
		proc = make_command_alias(.[ #char "y", #char "$" ]),
	);
	add_command(
		keybind = "u",
		proc = command_undo,
	);
	add_command(
		keybind = .[ 18 ], // ctrl + r
		proc = command_redo,
	);
	add_command(
		keybind = "r",
		proc = command_replace,
		char_proc = command_replace_char,
	);
	add_command(
		keybind = "n",
		proc = #bake_arguments command_jump_search(step = 1),
	);
	add_command(
		keybind = "N",
		proc = #bake_arguments command_jump_search(step = -1),
	);
	add_command(
		keybind = ">",
		proc = command_indent,
		motion_proc = #bake_arguments command_indent_motion(step = 1),
	);
	add_command(
		keybind = "<",
		proc = command_indent,
		motion_proc = #bake_arguments command_indent_motion(step = -1),
	);
	add_command(
		keybind = ">>",
		proc = #bake_arguments command_indent_indent(step = 1),
	);
	add_command(
		keybind = "<<",
		proc = #bake_arguments command_indent_indent(step = -1),
	);
	add_command(
		keybind = "M",
		proc = command_mark_create,
		char_proc = command_mark_create_char,
	);
	add_command(
		keybind = "\t", // ctrl + i
		proc = command_cursor_redo,
	);
	add_command(
		keybind = ".",
		proc = command_dot,
	);
	add_command(
		keybind = .[ 15 ], // ctrl + o, means "SI (shift out)" ??
		proc = command_cursor_undo,
	);
	add_command(
		keybind = "x",
		proc = command_delete_chars,
	);
	add_command(
		keybind = "?",
		proc = (in: Command_In) -> Command_Result {
			log("=================== INFO START ===============================================");
			{
				using win := in.window;
				line := *lines[cursor.y];
				if cursor.x < line.count {
					log("Under cursor:\n");
					mod := line.mods[cursor.x];
					user_mod := line.user_mods[cursor.x];
					char := line.chars[cursor.x];
					//log("char: '%' (%), fg: %, bg: %\n", string.{ data = *char, count = 1 }, char, fg, bg);
					log("char: '%', mod: %, user_mod: %\n", string.{ data = *char, count = 1 }, mod, user_mod);
				}
				log("Cursor marks (idx: %):\n", cursor_mark_index);
				for cursor_marks {
					log("%: %\n", it_index, it);
				}
			}
			using context.edit;
			log("Root window has % children\n", root.children.count);
			log("Window counts: %, buffer count: %, floating count: %\n", windows.count, buffers.count, floating_windows.count);
			log("Windows: root: %, container: %, buffer: % ('%'), from in: %", root, container_window, buffer_window, buffer_window.user_title, in.window);
			log("window id: %, buffer id: %", context.buffer_window.id, context.buffer_window.buffer.id);
			log("Current dot: %\n", keybind_to_string(context.edit.current_dot_command));
			log("DUMPING BUFFERS:");
			for buffers {
				log("%: flags: % windows: %", it_index, it.flags, it.windows);
			}
			log("=================== INFO END ===============================================");
			return .{};
		}
	);
	add_command(
		keybind = .[ KEY_ARIGHT ],
		proc = #bake_arguments command_relative_window(step = 1, mode = .VERTICAL),
	);
	add_command(
		keybind = .[ KEY_ALEFT ],
		proc = #bake_arguments command_relative_window(step = -1, mode = .VERTICAL),
	);
	add_command(
		keybind = .[ KEY_ESCAPE ],
		proc = (in: Command_In) -> Command_Res {
			win := get_window(.NONE, not_floating = true, not_special = true);
			if win
				select_window(win);
			return .{};
		}
	);
	add_command(
		keybind = .[ KEY_ADOWN ],
		proc = #bake_arguments command_relative_window(step = 1, mode = .TABBED),
	);
	add_command(
		keybind = .[ KEY_AUP ],
		proc = #bake_arguments command_relative_window(step = -1, mode = .TABBED),
	);
	add_command(
		keybind = .[ 6 ], // ctrl + f
		proc = command_search,
		motion_proc = command_search_motion,
	);
}

copy_motion :: (using win: *Window, motion: Motion_Result) -> bool {
	if motion.status != .OK
		return false;
	clipboard: *Clipboard = *context.edit.clipboard;
	start := normalize_position(win, motion.start, .INSERT);
	end := normalize_position(win, motion.end, .INSERT);
	if start >= end
		start, end = end, start;
	if motion.flags & .Y_ONLY {
		start.x = 0;
		end.x = lines[end.y].count;
	}
	ok := _copy_range(win, clipboard, start, end);
	return ok;
}

copy_line_range :: (using win: *Window, ly: int, ry: int) -> bool {
	if ly > ry
		ly, ry = ry, ly;
	ly = clamp(ly, 0, lines.count-1);
	ry = clamp(ry, 0, lines.count-1);
	clipboard: *Clipboard = *context.edit.clipboard;
	ok := _copy_range(win, clipboard, .{0, ly}, .{lines[ry].count, ry});
	return ok;
}

// doesn't validate if ranges are valid !
_copy_range :: (using win: *Window, clipboard: *Clipboard, start: Position, end: Position) -> bool {
	copied_lines: [..]string;
	for y: start.y..end.y {
		line := *lines[y];
		lx := 0;
		rx := line.count;
		if y == start.y
			lx = start.x;
		if y == end.y
			rx = end.x;
		add_newline: bool = false;
		if rx == line.count {
			add_newline = true;
			rx -= 1;
		}
		s := string.{ data = line.chars.data + lx, count = (rx - lx) + 1 };
		array_add(*copied_lines, copy_string(s)); // alloc
		if y == end.y {
			if add_newline
				array_add(*copied_lines, "");
		}
	}
	if copied_lines.count == 0 {
		return false;
	}
	clipboard.lines = copied_lines; // @Leak leaks old lines
	// TODO: jai linux clipboard is not working
	edit_set_os_clipboard(join(.. clipboard.lines, separator = "\n"));
	return true;
}

_paste :: (using win: *Window, on_next_char: bool) -> bool {
	clipboard := context.edit.clipboard;
	// TODO: jai linux clipboard is not working
	clipboard.lines = split(edit_get_os_clipboard(), #char "\n"); // @Leak leaks old lines, os_clipboard_get_text_allocates
	if clipboard.lines.count == 0
		return false;
	//preserve_cursor :: true;
	cursor_pos := cursor.position;
	end_cursor_pos := cursor_pos;
	here_lines := clipboard.lines;
	pos := cursor.position;
	//log("%", here_lines);
	//is_line_wise := false;
	if peek(here_lines).count == 0 {
		//is_line_wise = true;
		if on_next_char {
			here_lines.count -= 1;
			split_line(win, .{ lines[cursor_pos.y].count, cursor_pos.y }, indent=false);
			pos = .{0, cursor_pos.y + 1};
			end_cursor_pos.y += 1;
		} else {
			here_lines.count -= 1;
			split_line(win, .{ 0, cursor_pos.y }, indent=false);
			pos = .{0, cursor_pos.y};
		}
	} else {
		if on_next_char {
			offset_cursor(win, 1, 0);
			pos.x += 1;
			end_cursor_pos.x += 1;
		}
	}
	pos = normalize_position(win, pos, .INSERT);
	for here_lines {
		_write_normal_string(win, pos, it); // these should be normal chars
		pos.x += it.count;
		if it_index + 1 != here_lines.count {
			split_line(win, pos, indent=false);
			pos = .{0, pos.y+1};
		}
	}
	move_cursor(win, end_cursor_pos);
	return true;
}

add_command :: inline (name: string = "", keybind: $T/.[string, []s32],
			proc: Command.Proc, motion_proc: Command.Motion_Proc = null, char_proc: Command.Char_Proc = null, loc := #caller_location) {
	actual_name := name;
	if !actual_name
		actual_name = sprint("%:%:%", loc.fully_pathed_filename, loc.line_number, loc.character_number);
	array_add(*context.edit.commands, .{
		name = actual_name,
		keybind = to_keybind(keybind),
		proc = proc,
		motion_proc = motion_proc,
		char_proc = char_proc,
	});
}

command_error :: (s: string = "") -> Command_Res {
	return .{
		status = .ERROR,
		error_message = s,
	};
}

#scope_file