
//
// Thinking: some kind of enter-insert-mode command that doesn't reset running dot command
// ^ makes dot function as a macro 
// Same for leaving command mode without reseting running dot command.
// ...
// ? fast matching
// multiple clipboards + definition of a system clipboard
// more options for search/replace 
// file
// - fix filename normalization
// - directories
// properly freeing/destroying buffers & windows without leaking
// more-generalized indentation?
// OTHER TODO: (i need a list for this) pwn library for jai?

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

// This is temp allocated.. im not sure why i'd want it to be normally allocated!
// If it's in an error message, it's used as an argument.
keybind_to_string :: (kb: $T/.[Keybind, []s32, [..]s32]) -> string {
	chars := #ifx T == Keybind then kb.chars else kb;
	ret: [..]u8;
	ret.allocator = temp;
	for chars {
		s := to_string(keyname(it),, allocator=temp);
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
	LOGFILE :: "/dev/pts/2";
	f := New(File); // leak
	f.* = file_open(LOGFILE, for_writing = true);
	assert(is_valid(f));
	context.logger = file_logger;
	context.logger_data = f;
}

Edit_Mode :: enum int {
	NONE :: 0;
	INSERT;
	COMMAND;
	NOP; // different to none
}

Clipboard :: struct {
	lines: []string; // count > 0 when valid
}

Editime :: #type,distinct int;

Editool :: struct {
	Flags :: enum_flags {
		RELATIVE_LINES;
		GOOFY_COLORS;
	}
	// system
	flags: Flags = .RELATIVE_LINES;
	should_quit: bool;
	should_reset_edit_mode: bool;
	added_chars: [..]s32; // synthentic input
	time: Editime; // time in relation to user input
	mode: Edit_Mode = .NONE;
	// WINDOWS
	buffer_window: *Window; // current buffer window
	container_window: *Window; // might be null? if floating is active
	next_window: *Window = null;
	windows: [..]*Window;
	floating_windows: [..]*Window;
	root: *Window; // .CONTAINER
	second_root: *Window = null; // also .CONTAINER
	windows_to_destroy: [..]*Window;
	windows_to_force_destroy: [..]*Window;
	// BUFFERS
	buffers: [..]*Buffer;
	// commands n shit
	motions: [..]Motion;
	commands: [..]Command;
	exec_commands: [..]Exec_Command;
	// commands n shit 2
	command_state: Command_State;
	search: Search_State;
	#overlay(search) search_state: Search_State;
	exec: Exec;
	// TESTING
	alerts: [..]string; // cleared after window draw !
	//
	current_dot_command: [..]s32;
	next_dot_command: [..]s32;
	clipboard: Clipboard;
	//collecting_next_dot_command := false; // if mode == .INSERT
}

// internal ! and very bad
edit_error :: (fmt: string, args: .. Any) {
	edit_alert(fmt, .. args, is_internal = true);
} @PrintLike

// assumed to be a warning
edit_alert :: (fmt: string, args: .. Any, is_internal := false) {
	s := sprint(fmt, .. args);
	log_error("ALERT: %", s);
	array_add(*context.edit.alerts, s);
} @PrintLike

#add_context edit: Editool;
#add_context using,only(command_state, container_window, buffer_window, search, exec) edit;

insert_tty_input :: (chars: $T/.[ []s32, string ]) {
	for chars
		array_add(*context.edit.added_chars, it);
}

is_printable_char :: (ch: s32) -> bool {
	// 0x20: space, 0x7f: del
	return 0x20 <= ch && ch < 0x7f;
}

is_alnum :: (ch: s32) -> bool {
	return is_printable_char(ch) && is_alnum(cast(u8)ch);
}

reset_edit_mode :: () {
	context.edit.should_reset_edit_mode = true;
}

change_edit_mode :: (mode: Edit_Mode) {
	_change_edit_mode(mode, _force = false);
}

_change_edit_mode :: (mode: Edit_Mode, _force: bool) {
	if !_force && context.edit.mode == mode
		return;
	// reset
	if context.edit.mode == .COMMAND
		exit_command_mode();
	//if context.edit.mode == .EXEC
		//exit_exec_mode();
	if context.buffer_window != null {
		// hacky...
		if mode == .INSERT && get_current_buffer().caps & .MODE_INSERT == 0 {
			mode = .COMMAND;
		}
		if mode == .COMMAND && get_current_buffer().caps & .MODE_COMMAND == 0 {
			mode = .INSERT;
		}
		if mode == .INSERT && get_current_buffer().caps & .MODE_INSERT == 0 {
			mode = .NOP;
		}
	}
	context.edit.mode = mode;
	// start
	if context.edit.mode == .COMMAND
		enter_command_mode();
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

do_some_extra_stuff_to_the_buffer_colors :: (win: *Window) {
	buf: *Buffer = win.buffer;
	{
		//using context.edit.search_state;
		maybe_update_search_matches(win);
		for buf.search_matches.matches {
			y := it.position.y;
			if it.position.y >= buf.lines.count {
				log_error("Ruh roh, something went wrong with search y (%)", it);
				continue;
			}
			line := *buf.lines[it.position.y];
			if it.position.x + it.count > line.count {
				log_error("Ruh roh, something went wrong with search x (%)", it);
				continue;
			}
			for it.position.x..min(line.count, it.position.x + it.count)-1 {
				line.modifiers[it].bg_color = 2;
			}
		}
	}
	if win.kind == .BUFFER && win.buffer == context.buffer_window.buffer {
		using,except(cursor) win;
		cursor := context.buffer_window.cursor;
		line := *lines[cursor.y];
		if cursor.x < line.count {
			ch := line.chars[cursor.x];
			pos: Position = .{ -1, -1 };
			if ch == #char "(" {
				pos = find_char_in_window(win, ")", "(",  1);
			} else if ch == #char ")" {
				pos = find_char_in_window(win, "(", ")", -1);
			} else if ch == #char "{" {
				pos = find_char_in_window(win, "}", "{",  1);
			} else if ch == #char "}" {
				pos = find_char_in_window(win, "{", "}", -1);
			} else if ch == #char "[" {
				pos = find_char_in_window(win, "]", "[",  1);
			} else if ch == #char "]" {
				pos = find_char_in_window(win, "[", "]", -1);
			}
			if pos.y >= 0 {
				mod := *lines[pos.y].modifiers[pos.x];
				mod.fg_color = 7;
				mod.bg_color = 0;
				//fg, bg := uncolor_fg_bg(lines[pos.y].colors[pos.x]);
				//fg = 7; // this seems to be black?
				//bg = 0;
				//lines[pos.y].colors[pos.x] = color_fg_bg(fg, bg);
			}
		}
	}
	{
		using buf;
		for buf.marks {
			if it.position.y >= lines.count {
				log_error("fucky wucky mark (y)");
				continue;
			}
			line := *lines[it.position.y];
			if it.position.x > line.count {
				log_error("fucky wucky mark (x)");
				continue;
			}
			mod := *line.modifiers[it.position.x];
			mod.fg_color = 7;
			mod.bg_color = 0;
			//fg, bg := uncolor_fg_bg(line.colors[it.position.x]);
			//fg = 7; // this seems to be black?
			//bg = 0;
			//line.colors[it.position.x] = color_fg_bg(fg, bg);
		}
	}
}

handle_insert_char :: (ch: s32) {
	win := context.buffer_window;
	for * win.buffer.insert_commands {
		if keybind_matches(it.keybind, .[ch]) {
			// calling bad commands here might mess up !!
			in: Command_In = .{
				window = context.buffer_window,
			};
			assert(it.proc != null);
			res := it.proc(in);
			_handle_command_result(it, in, res);
		}
	}
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
				res := execute_motion(motion);
				move_cursor(res);
			} else {
				edit_alert("Unhandled insert char: %\n", keybind_to_string(.[ ch ],, allocator=temp));
			}
	}
}


handle_char :: (ch: s32) {
	win := context.edit.buffer_window;
	{ 
		// do something independant of mode?
		if ch == {
			case KEY_RESIZE;
				refresh_window_size(context.edit.root, force = true);
				return;
		}
		if context.edit.mode == .COMMAND || 
				(context.edit.mode == .INSERT && context.edit.next_dot_command.count > 0) {
			array_add(*context.edit.next_dot_command, ch);
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
			case .NOP;
				// pass
			case .INSERT;
				handle_insert_char(ch);
			case .COMMAND;
				handle_command_char(ch);
			case;
				edit_alert("Unhandled edit mode: %", context.edit.mode);
				was_handled = false;
		}
		if was_handled
			return;
	}
	edit_alert("Unhandled char %\n", ch);
}

// these 3 add_* are in main instead of their files...
// thats fine?

//select_window :: (win
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

editool_assertion_failed :: (loc: Source_Code_Location, message: string) -> bool {
	editool_deinit();
	return runtime_support_assertion_failed(loc, message);
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
	add_all_execs();
	create_container_window(null, stdscr); // root!
	editool_search_init();
	editool_exec_init();
	change_edit_mode(.COMMAND);
	context.edit.time = 1;
	context.assertion_failed = editool_assertion_failed;
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
		assert(args.count <= 2);
		if args.count > 1
			filename = args[1];
		//parent := create_container_window(context.edit.root);
		parent := context.edit.root;
		buf := get_file_buffer(filename);
		assert(buf != null);
		//
		win1 := create_buffer_window(parent, buf);
		select_window(win1);
		{
			//p := FLOATING_PADDING;
			//context.edit.floating_nwindow =
					//derwin(stdscr, LINES - xx (p.y * 2), xx(COLS - p.x * 2), xx p.y, xx p.x);
		}
	}
	//
	while true {
		edit := *context.edit;
		{
			// housekeeping here + before drawing
			if edit.should_reset_edit_mode {
				_change_edit_mode(edit.mode, _force = true);
				edit.should_reset_edit_mode = false;
			}
			windows_to_destroy := edit.windows_to_destroy;
			windows_to_force_destroy := edit.windows_to_force_destroy;
			edit.windows_to_destroy = default_of([..]*Window);
			edit.windows_to_force_destroy = default_of([..]*Window);
			for windows_to_destroy {
				_destroy_window(it);
			}
			for windows_to_force_destroy {
				_destroy_window(it, _force = true);
			}
			array_reset(*windows_to_destroy);
			array_reset(*windows_to_force_destroy);
		}
		ch: s32 = ---;
		if context.edit.added_chars.count == 0 {
			// Old: If a floating window exists, and the current buffer is not the floating window, then stop floating it.
			// New: If the current buffer is not floating, unfloat all floating windows.
			/*
			if !edit.buffer_window.is_floating {
				for array_copy(edit.floating_windows,, allocator=temp) {
					set_floating(it, false);
				}
			}*/
			draw_windows_recursive(context.edit.root);
			for context.edit.alerts
				free(it);
			array_reset(*context.edit.alerts);
			//refresh();
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
#load "command_mode.jai";
#load "buffer.jai";
#load "syntax.jai";
#load "window.jai";
#load "window_ext.jai";
#load "exec.jai";
#load "search.jai";
#load "fzf.jai";

#import "Basic";
#import "File";
#import "String";
#import "ncurses";
#import "jaison";
Uniform :: #import "uniform";
