
// hmm..
Keybind :: struct {
	chars: []s32;
}

to_keybind :: inline (kb: $T/.[string, []s32]) -> Keybind {
	// this should get put in constant data?
	chars: [..]s32;
	for kb
		array_add(*chars, it);
	return .{
		chars = chars,
	};
}

keybind_to_string :: (kb: $T/.[Keybind, []s32, [..]s32]) -> string {
	chars := #ifx T == Keybind then kb.chars else kb;
	ret: [..]u8;
	for chars {
		s := to_string(keyname(it));
		if s.count > 1
			array_add(*ret, "<");
		for s
			array_add(*ret, it);
		if s.count > 1
			array_add(*ret, ">");
	}
	return cast(string)ret;
}

file_logger :: (message: string, data: *void, info: Log_Info) {
	assert(data != null);
	f: *File = data;
	file_write(f, message);
	if message.count == 0 || message[message.count-1] != #char "\n" {
		file_write(f, "\n");
	}
	file_flush(f);
}

init_logger :: () {
	LOGFILE :: "/dev/pts/0";
	f := New(File); // leak
	f.* = file_open(LOGFILE, for_writing = true);
	assert(is_valid(f));
	context.logger = file_logger;
	context.logger_data = f;
}

Waiting_Chars :: struct {
	number: int = 0;
	chars: [..]s32;
	no_number := false;
}

waiting_chars_reset :: (waiting: *Waiting_Chars) {
	waiting.number = 0;
	array_reset(*waiting.chars);
}

// returns true if chars was added
update_waiting_chars :: (waiting: *Waiting_Chars, ch: s32) -> bool {
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

Search_State :: struct {
	regex_chars: [..]u8;
	#overlay(regex_chars) regex_string: string;
	Match :: struct {
		index: Position;
		count: int;
	}
	matches: [..]Match;
	match_time: Editime = -1;
	selected_match: int = 0;
}

Exec_State :: struct {
	chars: [..]u8;
	#overlay(chars) str: string;
}

Edit_Mode :: enum {
	NONE :: 0;
	INSERT;
	COMMAND;
	SEARCH;
	EXEC;
}

/*
Any_Status :: enum {
	OK :: 0,
	ERROR,
	CONTINUE_CHAR,
	CONTINUE_MOTION,
}
*/

Editime :: #type,distinct int;

Editool :: struct {
	Flags :: enum_flags {
		RELATIVE_LINES;
		GOOFY_COLORS;
	}
	flags: Flags = .RELATIVE_LINES;
	// ...
	main_buffer: Buffer;
	//current_buffer: *Buffer;
	current_window: *Window;
	mode: Edit_Mode = .NONE;
	should_quit: bool;
	motions: [..]Motion;
	commands: [..]Command;
	command_state: Command_State;
	search_state: Search_State;
	exec_state: Exec_State;
	added_chars: [..]s32; // synthentic input
	time: Editime; // time in relation to user input
}

#add_context edit: Editool;
#add_context using,only(command_state, current_window) edit;

insert_tty_input :: (chars: $T/.[ []s32, string ]) {
	for chars
		array_add(*context.edit.added_chars, it);
}

is_printable_char :: (ch: s32) -> bool {
	// 0x20: space, 0x7f: del
	return 0x20 <= ch && ch < 0x7f;
}

change_edit_mode :: (mode: Edit_Mode) {
	if context.edit.mode == mode
		return;
	// reset
	if context.edit.mode == .COMMAND
		reset_command_mode();
	if context.edit.mode == .SEARCH
		reset_search_mode();
	if context.edit.mode == .EXEC
		reset_exec_mode();
	// set
	context.edit.mode = mode;
	// start
	if mode == .COMMAND
		enter_command_mode();
	if mode == .SEARCH
		enter_search_mode();
}

reset_command_mode :: () {
	log("resetting command mode");
	using context.command_state;
	array_reset(*waiting_for_char);
	array_reset(*waiting_for_motion); // @Leak
	array_reset(*all_chars); 
	waiting_chars_reset(*context.command_state); 
	if context.edit.mode == .COMMAND {
		enter_command_mode();
	}
}

enter_command_mode :: () {
	handle_command_step();
}

keybind_matches :: (keybind: Keybind, chars: $T/.[[]s32, string]) -> bool {
	if keybind.chars.count != chars.count
		return false;
	for keybind.chars {
		if it != chars[it_index]
			return false;
	}
	return true;
}

keybind_matches_start :: (keybind: Keybind, chars: []s32) -> bool {
	if chars.count > keybind.chars.count
		return false;
	for chars {
		if it != keybind.chars[it_index]
			return false;
	}
	return true;
}


_handle_motion_result :: (motion: *Motion, in: Motion_In, res: Motion_Result, waiting: *Waiting_For_Motion,
		waiting_idx: int, can_char := false) -> (should_reset: bool) {
	if res.status == {
		case .OK;
			assert(waiting.command != null);
			assert(waiting.command.motion_proc != null);
			command_res := waiting.command.motion_proc(waiting.command_in, res);
			return _handle_command_result(waiting.command, waiting.command_in, command_res, can_char = can_char);
		case .CONTINUE_CHAR;
			if !can_char {
				log_error("Motion cannot continue char!\n");
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
			log_error("Motion failed: %\n", res.error_message);
			return true;
	}
	log_error("BAD motion status: %\n", res.status);
	return true;
}

_handle_command_result :: (command: *Command, in: Command_In, res: Command_Result, can_motion := false, can_char := false) -> (should_reset: bool) {
	if res.status == {
		case .OK;
			return true;
		case .ERROR;
			log_error("Command failed: %\n", res.error_message);
			return true;
		case .CONTINUE_MOTION;
			if !can_motion {
				log_error("Command cannot continue motion!");
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
				log_error("Command cannot continue char!");
				return true;
			}
			array_add(*context.command_state.waiting_for_char, .{
				no_number = res.continue_no_number,
				command = command,
				command_in = in,
			});
			return false;
	}
	log_error("BAD command status: %\n", res.status);
	return true;
}

// handles command step but only for commands (not waiting motions or chars or anything else)
// returns true if it should continue
handle_command_step :: () -> (should_reset: bool, found_command: bool) {
	found_command := false;
	should_reset := true;
	for * context.edit.commands {
		if keybind_matches(it.keybind, context.command_state.chars) {
			in := Command_In.{ number = max(1, context.command_state.number) };
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

reset_search_mode :: () {
}

enter_search_mode :: () {
	using context.edit.search_state;
	array_reset(*regex_chars);
	array_reset(*matches);
	selected_match = 0;
}

// updates matches only when you jump actually
// what do i name this??
jump_to_search_match_offset :: (offset: int) {
	using context.edit.search_state;
	win := context.current_window;
	buf := win.buffer;
	if match_time < buf.modify_time {
		_update_search_matches();
	}
	if matches.count == 0
		return;
	y := win.cursor.y;
	log("selected match: %\n", selected_match);
	selected_match = matches.count - 1;
	for matches {
		if it.index <= win.cursor.position {
			selected_match = it_index;
		} else {
			break;
		}
	}
	if win.cursor.position != matches[selected_match].index && offset < 0 {
		selected_match += 1;
	}
	log("selected match: %\n", selected_match);
	selected_match = (selected_match + offset) % matches.count;
	selected_match = (selected_match + matches.count) % matches.count;
	move_cursor(win, matches[selected_match].index, jump = true);
}

// returns true if match was *valid*
_update_search_matches :: () -> bool {
	using context.edit.search_state;
	array_reset(*matches);
	selected_match = -1;
	if regex_string.count == 0
		return false;
	time_this("Search");
	full_regex_string := tprint("(.*+)(%)", regex_string); // non-greedy whatever
	// @UniformBug with how .NonGreedy works, i think? (inverts instead of choosing a default)
	//compile_flags := (.LikePerl | .NonGreedy | .MatchNL) & ~.OneLine;
	compile_flags: Uniform.ParseFlags = (.LikePerl | .NonGreedy);
	re, ok := Uniform.compile(full_regex_string, compile_flags,, allocator=temp);
	if !ok {
		log_error("Regex compile failed");
		return false;
	}
	match_time = context.edit.time;
	defer Uniform.uninit(*re,,allocator=temp);
	//text: [..]u8;
	//indices: [..]Position;
	//text.allocator, indices.allocator = temp;
	MAX_MATCHES :: 10000;
	for line, y: context.current_window.lines {
		if matches.count >= MAX_MATCHES
			break;
		//array_add(*text, it);
		//array_add(*indices, it_index);
		s: string = cast(string)line.chars;
		idx := 0;
		while matches.count < MAX_MATCHES { // limit 
			ok, m := Uniform.match(s, re, .ANCHOR_START);
			if !ok
				break;
			prefix_str := m[1];
			match_str := m[2];
			if match_str.count == 0 {
				log_error("what");
				break;
			}
			idx += prefix_str.count;
			defer idx += match_str.count;
			vec2_idx := Position.{ idx, y};
			array_add(*matches, .{
				index = vec2_idx,
				count = match_str.count,
			});
			log("Found match at %: %", vec2_idx, match_str);
			s = advance(s, prefix_str.count + match_str.count);
		}
	}
	return true;
}

do_some_extra_stuff_to_the_buffer_colors :: () {
	win := context.current_window;
	buf: *Buffer = win.buffer;
	{
		using context.edit.search_state;
		if match_time < buf.modify_time {
			_update_search_matches();
		}
		for matches {
			y := it.index.y;
			line := *buf.lines[it.index.y];
			if it.index.x + it.count > line.count {
				log_error("Ruh roh, something went wrong with search (%)", it);
			}
			for it.index.x..min(line.count, it.index.x + it.count)-1 {
				fg, bg := uncolor_fg_bg(line.colors[it]);
				bg = 2;
				line.colors[it] = color_fg_bg(fg, bg);
			}
		}
	}
	{
		using win;
		line := *lines[cursor.y];
		if cursor.x < line.count {
			ch := line.chars[cursor.x];
			pos: Position = .{ -1, -1 };
			if ch == #char "(" {
				pos = find_char_in_window(")", "(",  1);
			} else if ch == #char ")" {
				pos = find_char_in_window("(", ")", -1);
			} else if ch == #char "{" {
				pos = find_char_in_window("}", "{",  1);
			} else if ch == #char "}" {
				pos = find_char_in_window("{", "}", -1);
			} else if ch == #char "[" {
				pos = find_char_in_window("]", "[",  1);
			} else if ch == #char "]" {
				pos = find_char_in_window("[", "]", -1);
			}
			if pos.y >= 0 {
				log("found match at %\n", pos);
				fg, bg := uncolor_fg_bg(lines[pos.y].colors[pos.x]);
				fg = 7; // this seems to be black?
				bg = 0;
				lines[pos.y].colors[pos.x] = color_fg_bg(fg, bg);
			}
		}
	}
}

handle_search_char :: (ch: s32) {
	using context.edit.search_state;
	if ch == {
		case KEY_ESCAPE; #through;
		case #char "\n";
			change_edit_mode(.COMMAND);
			return;
		case KEY_BACKSPACE;
			if regex_chars.count > 0 {
				pop(*regex_chars);
			} else {
				change_edit_mode(.COMMAND);
				return;
			}
		case;
			if is_printable_char(ch)
				array_add(*regex_chars, xx ch);
	}
	_update_search_matches();
}

reset_exec_mode :: () {
	using context.edit.exec_state;
	array_reset(*chars);
}

handle_exec_char :: (ch: s32) {
	using context.edit.exec_state;
	if ch == {
		case KEY_ESCAPE; 
			change_edit_mode(.COMMAND);
			return;
		case #char "\n";
			change_edit_mode(.COMMAND);
			return;
		case KEY_BACKSPACE;
			if chars.count > 0 {
				pop(*chars);
			} else {
				change_edit_mode(.COMMAND);
				return;
			}
		case;
			if is_printable_char(ch)
				array_add(*chars, xx ch);
	}
}

handle_command_char :: (ch: s32) {
	// printable ch!
	should_reset := true;
	found_command := false;
	if context.command_state.waiting_for_char.count > 1 {
		log_error("too much waiting for char?");
	}
	for *waiting: context.command_state.waiting_for_char {
		if !update_waiting_chars(waiting, ch) {
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
			assert(waiting.motion.char_proc != null);
			res := waiting.motion.char_proc(in, xx ch);
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
		if !update_waiting_chars(waiting, ch) {
			should_reset = false;
			continue;
		}
		// thisis slow ?
		for * context.edit.motions {
			if keybind_matches(it.keybind, waiting.chars) {
				in := Motion_In.{ number = max(waiting.number, 1) };
				res := it.proc(in);
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
	if update_waiting_chars(*context.command_state, ch) {
		step_reset, step_command := handle_command_step();
		should_reset &= step_reset;
		found_command |= step_command;
	} else {
		should_reset = false;
	}
	if should_reset {
		if !found_command
			log("Didn't find command: %\n", keybind_to_string(context.command_state.chars,, allocator=temp));
		reset_command_mode();
		return;
	}
}

handle_insert_char :: (ch: s32) {
	win := context.current_window;
	if is_printable_char(ch) {
		write_char(win, xx ch);
	} else if ch == {
		case #char "\t"; #through; 
		case #char "\n";
			write_char(win, xx ch);
		case KEY_ESCAPE; // escape
			change_edit_mode(.COMMAND);
		case KEY_SR;
			offset_scroll(win, -1);
		case KEY_SF;
			offset_scroll(win, 1);
		case;
			motion: *Motion = get_motion(.[ ch ]);
			if motion != null {
				move_cursor(motion.proc(.{}));
			} else {
				log("Unhandled insert char: %\n", keybind_to_string(.[ ch ],, allocator=temp));
			}
	}
}

handle_char :: (ch: s32) {
	win := context.edit.current_window;
	{ 
		// do something independant of mode?
		if ch == {
			case KEY_RESIZE;
				refresh_window_size(win);
				return;
		}
		// special case rn for these!!
		if context.edit.mode == .INSERT || context.edit.mode == .COMMAND {
			if ch == {
				// auto handled
				case KEY_DC; // delete
					delete_at_x_offset(win, 0);
					return;
				case KEY_BACKSPACE;
					delete_at_x_offset(win, -1);
					return;
			}
		}
	}
	{
		was_handled := true;
		if context.edit.mode == {
			case .INSERT;
				handle_insert_char(ch);
			case .COMMAND;
				handle_command_char(ch);
			case .SEARCH;
				handle_search_char(ch);
			case .EXEC;
				handle_exec_char(ch);
			case;
				log("what? %", context.edit.mode);
				was_handled = false;
		}
		if was_handled
			return;
	}
	log("Unhandled char %\n", ch);
}

add_motion :: inline ($keybind: $T/.[string, []s32], proc: Motion.Proc, char_proc: Motion.Char_Proc = null) {
	array_add(*context.edit.motions, .{
		keybind = to_keybind(keybind),
		proc = proc,
		char_proc = char_proc,
	});
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

add_all_motions :: () {
	// MOTIONS
	add_motion(
		keybind = "w",
		proc = #bake_arguments(motion_word(step = 1, flags = .NONE)),
	);
	add_motion(
		keybind = "W",
		proc = #bake_arguments(motion_word(step = 1, flags = .FULL)),
	);
	add_motion(
		keybind = "b",
		proc = #bake_arguments(motion_word(step = -1, flags = .NONE)),
	);
	add_motion(
		keybind = "B",
		proc = #bake_arguments(motion_word(step = -1, flags = .FULL)),
	);
	add_motion(
		keybind = "i]",
		proc = #bake_arguments(motion_inner(ch = #char "]", inclusive = false)),
	);
	add_motion(
		keybind = "i)",
		proc = #bake_arguments(motion_inner(ch = #char ")", inclusive = false)),
	);
	add_motion(
		keybind = "i\"",
		proc = #bake_arguments(motion_inner(ch = #char "\"", inclusive = false)),
	);
	add_motion(
		keybind = "iw",
		proc = #bake_arguments(motion_inner(ch = #char "w", inclusive = false)),
	);
	add_motion(
		keybind = "iW",
		proc = #bake_arguments(motion_inner(ch = #char "W", inclusive = false)),
	);
	add_motion(
		keybind = "a]",
		proc = #bake_arguments(motion_inner(ch = #char "]", inclusive = true)),
	);
	add_motion(
		keybind = "a)",
		proc = #bake_arguments(motion_inner(ch = #char ")", inclusive = true)),
	);
	add_motion(
		keybind = "a\"",
		proc = #bake_arguments(motion_inner(ch = #char "\"", inclusive = true)),
	);
	/*
	add_motion(
		keybind = "aw",
		proc = #bake_arguments(motion_inner(ch = #char "w", inclusive = true)),
	});
	add_motion(
		keybind = "aW",
		proc = #bake_arguments(motion_inner(ch = #char "W", inclusive = true)),
	);
	*/
	add_motion(
		keybind = "j",
		proc = #bake_arguments(motion_step(step = .{ y = 1 })),
	);
	add_motion(
		keybind = "k",
		proc = #bake_arguments(motion_step(step = .{ y = -1 })),
	);
	add_motion(
		keybind = .[ KEY_LEFT ],
		proc = #bake_arguments(motion_step(step = .{ x = -1 })),
	);
	add_motion(
		keybind = .[ KEY_RIGHT ],
		proc = #bake_arguments(motion_step(step = .{ x = 1 })),
	);
	add_motion(
		keybind = .[ KEY_UP ],
		proc = #bake_arguments(motion_step(step = .{ y = -1 })),
	);
	add_motion(
		keybind = .[ KEY_DOWN ],
		proc = #bake_arguments(motion_step(step = .{ y = 1 })),
	);
	add_motion(
		keybind = .[ KEY_HOME ],
		proc = #bake_arguments(motion_end_of_line(step = -1)),
	);
	add_motion(
		keybind = .[ KEY_END ],
		proc = #bake_arguments(motion_end_of_line(step = 1)),
	);
	add_motion(
		keybind = "f",
		proc = motion_find_char,
		char_proc = #bake_arguments motion_find_char_char(step = 1, inclusive = true),
	);
	add_motion(
		keybind = "F",
		proc = motion_find_char,
		char_proc = #bake_arguments motion_find_char_char(step = -1, inclusive = true),
	);
	add_motion(
		keybind = "t",
		proc = motion_find_char,
		char_proc = #bake_arguments motion_find_char_char(step = 1, inclusive = false),
	);
	add_motion(
		keybind = "T",
		proc = motion_find_char,
		char_proc = #bake_arguments motion_find_char_char(step = -1, inclusive = false),
	);
	add_motion(
		keybind = .[ KEY_CRIGHT ],
		proc = make_motion_alias("W"),
	);
	add_motion(
		keybind = .[ KEY_CLEFT ],
		proc = make_motion_alias("B"),
	);
	add_motion(
		keybind = "gg",
		proc = #bake_arguments motion_end_of_file(step = -1),
	);
	add_motion(
		keybind = "G",
		proc = #bake_arguments motion_end_of_file(step = 1),
	);
	add_motion(
		keybind = .[ KEY_NPAGE ],
		proc = #bake_arguments motion_page_step(step = 1),
	);
	add_motion(
		keybind = .[ KEY_PPAGE ],
		proc = #bake_arguments motion_page_step(step = -1),
	);
	add_motion(
		keybind = "{",
		proc = #bake_arguments motion_empty_line(step = -1),
	);
	add_motion(
		keybind = "}",
		proc = #bake_arguments motion_empty_line(step = 1),
	);
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
		keybind = "dd",
		proc = command_delete_line,
	);
	add_command(
		keybind = "i",
		proc = #run wrap_command(#bake_arguments(change_edit_mode(mode = .INSERT))),
	);
	add_command(
		keybind = "/",
		proc = #run wrap_command(#bake_arguments(change_edit_mode(mode = .SEARCH))),
	);
	add_command(
		keybind = ":",
		proc = #run wrap_command(#bake_arguments(change_edit_mode(mode = .EXEC))),
	);
	add_command(
		keybind = "A",
		proc = make_command_alias(.[ KEY_END, #char "i" ]),
	);
	add_command(
		keybind = "I",
		proc = make_command_alias(.[ KEY_HOME, #char "i" ]),
	);
	add_command(
		keybind = "d",
		proc = command_delete,
		motion_proc = #bake_arguments command_delete_motion(enter_insert_mode = false),
	);
	add_command(
		keybind = "c",
		proc = command_delete,
		motion_proc = #bake_arguments command_delete_motion(enter_insert_mode = true),
	);
	add_command(
		keybind = "D",
		proc = make_command_alias(.[ #char "d", KEY_END ]),
	);
	add_command(
		keybind = "C",
		proc = make_command_alias(.[ #char "c", KEY_END ]),
	);
	add_command(
		keybind = .[ KEY_SR ],
		proc = #bake_arguments command_scroll_offset(step = -1),
	);
	add_command(
		keybind = .[ KEY_SF ],
		proc = #bake_arguments command_scroll_offset(step = 1),
	);
	add_command(
		keybind = "Z",
		proc = command_scroll_center,
	);
	add_command(
		keybind = "zz",
		proc = command_scroll_center,
	);
	add_command(
		keybind = "u",
		proc = command_undo,
	);
	add_command(
		keybind = "r",
		proc = command_redo,
	);
	add_command(
		keybind = "R",
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
		keybind = "?",
		proc = (_: Command_In) -> Command_Result {
			using win := context.current_window;
			line := *lines[cursor.y];
			if cursor.x < line.count {
				log("Under cursor:\n");
				fg, bg := uncolor_fg_bg(line.colors[cursor.x]);
				char := line.chars[cursor.x];
				log("char: '%' (%), fg: %, bg: %\n", string.{ data = *char, count = 1 }, char, fg, bg);
			}
			return .{};
		}
	);
}

COLOR_COUNT :: 16;

// returns pair index, still need to call COLOR_PAIR
color_fg_bg :: (fg: int, bg: int) -> (pair: s32) {
	idx := (fg + 1) + (bg + 1) * (COLOR_COUNT+1);
	return xx idx;
}

uncolor_fg_bg :: (col: s32) -> (fg: int, bg: int) {
	fg, bg := col % (COLOR_COUNT+1) - 1, col / (COLOR_COUNT+1) - 1;
	return fg, bg;
	//return COLOR_PAIR(xx ((fg + 1) + (bg + 1) * COLOR_COUNT));
}

// doesn't init any buffers!!
editool_init :: () {
	// logger
	init_logger();
	time_this("Editool init");
	// ncurses
	initscr();
	noecho(); 
	keypad(stdscr, true); // use all keys
	set_escdelay(10); // ms
	if !has_colors() || !can_change_color() {
		log_error("no colors...");
		editool_deinit();
		exit(1);
	}
	start_color();
	use_default_colors(); // use terminals colors..
	#if 0 {
		for i: 0..7 {
			if i < 2 {
				init_color(xx i, 0, 0, 0);
			} else if i < 4 {
				init_color(xx i, 500, 500, 500);
			} else if i < 6 {
				init_color(xx i, 1000, 1000, 1000);
			} else {
				init_color(xx i, 2000, 2000, 2000);
			}
		}
	}
	#if 1 {
		for i: -1..COLOR_COUNT-1 {
			for j: -1..COLOR_COUNT-1 {
				idx := color_fg_bg(i, j);
				ret := init_pair(xx idx, xx i, xx j);
				if ret == ERR {
					log_error("can't init color % (%, %)", idx, i, j);
					editool_deinit();
					exit(1);
				}
			}
		}
	}
	#if 0 {
		for i: 0..COLOR_COUNT-1 {
			for j: 0..COLOR_COUNT-1 {
				init_pair(xx (i + j * COLOR_COUNT), xx (i-1), xx (j-1));
				init_pair(xx (i + j * COLOR_COUNT), xx (i-1), -1);
			}
		}
	}
	// editool
	add_all_motions();
	add_all_commands();
	change_edit_mode(.COMMAND);
	context.edit.time = 1;
}

editool_deinit :: () {
	endwin();
}

main :: () {
	editool_init();
	{
		// init buffer
		filename: string = "";
		args := get_command_line_arguments();
		if args.count > 1
			filename = args[1];
		context.edit.main_buffer = create_buffer_from_filename(filename);
		context.edit.current_window = create_window_from_buffer(*context.edit.main_buffer);
	}
	//
	while true {
		ch: s32 = ---;
		if context.edit.added_chars.count == 0 {
			draw_window(context.edit.current_window);
			ch = getch();
			context.edit.time += 1;
		} else {
			ch = context.edit.added_chars[0];
			array_ordered_remove_by_index(*context.edit.added_chars, 0);
		}
		if is_printable_char(ch)
			log("got ch: % (%)\n", ch, string.{ data = cast(*u8)*ch, count = 1 });
		else
			log("got ch: % ((%))\n", ch, to_string(keyname(ch)));
		handle_char(ch);
		reset_temporary_storage();
		if context.edit.should_quit
			break;
	}
	editool_deinit();
}

#load "utils.jai";
#load "motions.jai";
#load "commands.jai";
#load "buffer.jai";
#load "syntax.jai";
#load "window.jai";

#import "Basic";
#import "File";
#import "String";
#import "ncurses";
Uniform :: #import "uniform";
