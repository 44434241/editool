//
// Thinking: some kind of enter-insert-mode command that doesn't reset running dot command
// ^ makes dot function as a macro 
// ^ didn't find myself think about it too much
// ^ i need more flags to define what commands support (eg .NUMBER | .DOT | .MULTICURSOR)
// ...
// 
// OTHER TODO: (i need a list for this) pwn library for jai? 
// ^ honestly..
//
// - multiple clipboards ? idk
// ^ should i?
//
// - multiline syntax is supported, but nested syntax isn't. need to do more stuff.
// - ^ how would i do jai here string syntax? need to capture and re-match it?
// - multiline searching?
// - keybinds to undo/redo ff & fr (as in, see history??) (just make it proper !)
// - breaks clipboard image, when open ... <- ALSO NEED TO SAVE PATH ..
// - hook for moving cursor in window (or could have a last time for cursor change, could be cleaner)
// - for search replace, could mark the last search differently for readability !!
// - search probably supporting 'no' confirm <- maybe important
// - UPDATE HOW CURSOR MARKS WORK
// - ^ scroll still not working with jumps (need to look into them)
// - should have separate "should show line numbers/status bar/etc" flags for buffers, and windows can have the option to override them???
// - ^ also for compilation, i could mark the lines in the error output
// - Some way to save esc-ed search/exec?
// - - maybe just remember the last esc-ed, and have a keybind to start from it ig..
// - history files (search/exec/undo?), or some sort of session thing
// - when screen resolution is too small for floating windows, it crashes instead of just silently failing?.. <- fixed when lines_to_draw.count == 0, but still crashes if it's super smaller. maybe something in ncurses??
// - alert/warn/error history? could be just a buffer <- could name special buffers like "@search", "@exec"...
// - cursor in long lines, in the second actual line is a bit off... (or not? seems like the problem is the border existing..)
// - could highlight escape sequences in string with a lil different color/ < - very hard
// - '^[A-Z]' search regex fails - because of how start-of-line thing works...
// - clipbord buffer, similiar to search...
// - search find to end of match... need to figure out some way to way to create a command for that? maybe a motion for the current "search match"?
// - way to delete marks...
// - having proper multiple-line tab names, or maybe find a way to shorten them?
// - could make --no-x11 and --std-tty flags auto-detectable !
// - utf-8 viewing works, but not editing. whatever, just keeping a note of that!
// - wouldn't be that difficult to make search preview even those who are not part of the motion !
//
//
// I want these a lil more
// - kinda like "go to previous jump" thing, but instead go to latest jump that is in a different file!
// - it would be useful to have some way to say what undo happened...
// - man pager
// - proper threading search...
// - when closing the last copy if a buffer, the undo history is gone and that might sometimes be bad.... maybe normal buffers ar .PERM_ISH
//
// These seem really interesting
// - embedded buffer stuff? (fzf command, shell, whatever else...)
//
// Things for ff (mostly for debugging idk)
// - windows
// - jump & undo history 
//
// dir stuff:
// - more info for files (size, is dir, permissions..)
// - rename files/dirs loaded in editool !
// - copying/cutting directories to move
// - creating multiple/nested directories?
// - ^ could have a different syntax for that.. actually think about directories more.
//
// Try implementing language server
// Try implementing multiple cursors
//
// thinking...:
// - i need to have multiple previous-jump lists, for short and long jumps..
// - should i rename command_delete* -> command_erase* ?
// - Markdown?
// - MAN PAGES...
//
// NEEDS OF THE MIRROR
//
// - FR IS SLOW 
// - ^ 1. blacklist certain directories for 'fr' based on where i am? 
// - ^ 2. make rg search also not-waiting <- working on it..
//
// Folds
// - Not all motions supports folds, need fo fix them up...
// - Need a better way to visualize them.. maybe mark the line number differently?
// - Nested ones not supported rn
// - 'qq' marking all messes up with top level #if's 
// - folds marker things, e.g '/// thing start' '/// thing end'
//
// Laptop shit
// - push i3 status caps thing
// - should either commit compile scripts or make a first for compiling it 

X11_ENABLE :: true;

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

_1984_logger :: (message: string, data: *void, info: Log_Info) {
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

init_file_logger :: (filename: string) {
	f := New(File); // leak
	f.* = file_open(filename, for_writing = true);
	assert(is_valid(f));
	context.logger = file_logger;
	context.logger_data = f;
}

Edit_Mode :: enum int {
	NONE :: 0;
	INSERT;
	COMMAND;
	ASK;
	NOP; // different to none
}

Edit_Mode_Bits :: enum_flags {
	INSERT :: 1 << Edit_Mode.INSERT;
	COMMAND :: 1 << Edit_Mode.COMMAND;
	ASK :: 1 << Edit_Mode.ASK;
	// don't have one for .NOP !
	NONE :: 0;
}

Clipboard :: struct {
	lines: []string; // count > 0 when valid
}

Editime :: #type,distinct int;

Editool :: struct {
	Flags :: enum_flags {
		RELATIVE_LINES; // i don't know why this is here.. should be with window or buffer
		GOOFY_COLORS;
	}
	// system
	flags: Flags = .RELATIVE_LINES | .GOOFY_COLORS;
	flags = .RELATIVE_LINES;
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
	//
	marks: [..]Mark; // i want global marks !
	window_select_mode: Window_Select_Mode = .NONE;
	//
	#if X11_ENABLE {
		x11_window: X11.Window;
	} 
	not_os_clipboard: string; // for when x11 is disabled
	syntaxes: [..]*Syntax;
	ask: Ask_State;
	// arg related stuff
	should_print_path: bool = false;
	tty_file: *FILE;
	use_stdout_as_tty_fd: bool = false;
	dont_mess_with_tty: bool = false;
	no_x11: bool = false;
}

#if X11_ENABLE {
	edit_get_os_clipboard :: () -> string {
		if context.edit.no_x11
			return context.edit.not_os_clipboard;
		return os_clipboard_get_text(context.edit.x11_window,, allocator=temp);
	}
	
	edit_set_os_clipboard :: (s: string) {
		if context.edit.no_x11 {
			context.edit.not_os_clipboard = string_copy(s); // leak
			return;
		}
		os_clipboard_set_text(context.edit.x11_window, s);
	}
	
	is_caps_lock :: () -> bool {
		if context.edit.no_x11 {
			return false;
		}
		state: u32;
		status: X11.Status = XkbGetIndicatorState(X11.x_global_display, XkbUseCoreKbd, *state);
		if status != X11.Success {
			edit_alert("is_caps_lock() failed (%)", status);
			return false;
		}
		return state & 1 != 0;
	}
} else {
	edit_get_os_clipboard :: () -> string {
		return context.edit.not_os_clipboard;
	}
	
	edit_set_os_clipboard :: (s: string) {
		context.edit.not_os_clipboard = string_copy(s); // leak
	}
}

// internal ! and very bad
edit_error :: (fmt: string, args: .. Any) {
	edit_alert(fmt, .. args, is_internal = true);
} @PrintLike

edit_warn :: edit_error;

// assumed to be a warning
// (it isn't actually.. )
edit_alert :: (fmt: string, args: .. Any, is_internal := false) {
	s := sprint(fmt, .. args);
	log_error("ALERT: %", s);
	array_add(*context.edit.alerts, s);
} @PrintLike

#add_context edit: Editool;
#add_context using,only(command_state, container_window, buffer_window, search, exec, ask) edit;

insert_tty_input :: (chars: $T/.[ []s32, string ]) {
	for chars
		array_add(*context.edit.added_chars, it);
}

is_printable_char :: (ch: s32) -> bool {
	// 0x20: space, 0x7f: del
	return 0x20 <= ch && ch < 0x7f;
}

is_ascii :: (ch: u32) -> bool {
	// 0x20: space, 0x7f: del
	return 0x00 <= ch && ch <= 0x7f;
}

is_alnum :: (ch: s32) -> bool {
	return ch & 0xff == ch && is_alnum(cast(u8)ch);
}

reset_edit_mode :: () {
	context.edit.should_reset_edit_mode = true;
}

change_edit_mode :: (mode: Edit_Mode) {
	_change_edit_mode(mode, force = false);
}

_change_edit_mode :: (mode: Edit_Mode, force: bool) {
	if !force && context.edit.mode == mode
		return;
	edit_alert("changing to mode: %", mode);
	// reset
	if context.edit.mode == .ASK
		exit_ask_mode();
	if context.edit.mode == .COMMAND
		exit_command_mode();
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
	//if context.edit.mode == .ASK
		//enter_confirm_mode();
	if context.buffer_window
		normalize_cursor(context.buffer_window, with_scroll = false);
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
				if it >= Line.user_mods.count
					break;
				line.user_mods[it].bg = 6;
				line.user_mods[it].fg = 1;
			}
		}
	}
	if win.kind == .BUFFER && win.buffer == context.buffer_window.buffer {
		using,except(cursor) win;
		cursor := context.buffer_window.cursor;
		line := *lines[cursor.y];
		if cursor.x < line.count {
			w := context.buffer_window;
			ch := line.chars[cursor.x];
			pos: Position = .{ -1, -1 };
			if ch == #char "(" {
				pos = find_char_in_window(w, ")", "(",  1);
			} else if ch == #char ")" {
				pos = find_char_in_window(w, "(", ")", -1);
			} else if ch == #char "{" {
				pos = find_char_in_window(w, "}", "{",  1);
			} else if ch == #char "}" {
				pos = find_char_in_window(w, "{", "}", -1);
			} else if ch == #char "[" {
				pos = find_char_in_window(w, "]", "[",  1);
			} else if ch == #char "]" {
				pos = find_char_in_window(w, "[", "]", -1);
			}
			if pos.y >= 0 && pos.x < Line.user_mods.count {
				line := *lines[pos.y];
				mod := *lines[pos.y].user_mods[pos.x];
				mod.attributes ^= A_STANDOUT;
			}
		}
		if cursor.x < line.user_mods.count && is_caps_lock() {
			line.user_mods[cursor.x].fg = 8;
		}
	}
}

// they'll be in the correct order (first commands will have more priority)
get_current_valid_commands :: (mode: Edit_Mode = .NONE) -> []*Command {
	if mode == .NONE
		mode = context.edit.mode;
	mode_bits := cast(Edit_Mode_Bits)(1 << mode);
	ret: [..]*Command;
	ret.allocator = temp;
	if context.buffer_window != null {
		for * context.buffer_window.commands {
			if it.mode & mode_bits {
				array_add(*ret, it);
			}
		}
		for * context.buffer_window.buffer.commands {
			if it.mode & mode_bits {
				array_add(*ret, it);
			}
		}
	}
	for * context.edit.commands {
		if it.mode & mode_bits {
			array_add(*ret, it);
		}
	}
	return ret;
}

handle_insert_char :: (ch: s32) {
	win := context.buffer_window;
	for get_current_valid_commands(.INSERT) {
		//log("testing % (%)", s32.[ ch ], it.keybind);
		if keybind_matches(it.keybind, .[ch]) {
			// calling bad commands here might mess up !!
			in: Command_In = .{
				window = context.buffer_window,
			};
			assert(it.proc != null);
			res := it.proc(in);
			_handle_command_result(it, in, res, dont_touch_dot = true);
			return;
		}
	}
	if is_printable_char(ch) {
		write_char(win, xx ch); // crashed here somewhere ???
	} else if ch == {
		case #char "\t"; #through; 
		case #char "\n";
			write_char(win, xx ch);
		case 5; #through; // ctrl + e
		case KEY_ESCAPE; // escape
			change_edit_mode(.COMMAND);
		case;
			motion: *Motion = find_motion(.[ ch ]);
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
				for context.edit.floating_windows
					refresh_window_size(it, force = true);
				wclear(stdscr);
				return;
		}
		if context.edit.mode == .COMMAND || 
				(context.edit.mode == .INSERT && context.edit.next_dot_command.count > 0) {
			log("adding % to dot command (%)", ch, context.edit.next_dot_command);
			array_add(*context.edit.next_dot_command, ch);
		} else {
			log("NOT adding adding % to dot command (%)", ch, context.edit.next_dot_command);
		}
	}
	{
		was_handled := true;
		if context.edit.mode == {
			case .NOP;
				// pass
			case .ASK;
				handle_ask_char(ch);
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

// still dont get colors, but this is stable for now 
// alright, this looks ok.. 6 + 1 bg colors
COLOR_BG_LAST :: 6; // some nonsense happens when bg color > 8
COLOR_FG_LAST :: 20;
COLOR_BG_COUNT :: COLOR_BG_LAST + 2;
COLOR_FG_COUNT :: COLOR_FG_LAST + 2;


// returns pair index, still need to call COLOR_PAIR
color_fg_bg :: (fg: int, bg: int) -> (pair: s32) {
	idx := (fg + 1) + (bg + 1) * (COLOR_FG_COUNT);
	return xx idx;
}

uncolor_fg_bg :: (col: s32) -> (fg: s8, bg: s8) {
	fg, bg := col % (COLOR_FG_COUNT) - 1, col / (COLOR_FG_COUNT) - 1;
	assert(-1 <= fg);
	assert(-1 <= bg);
	assert(fg <= COLOR_FG_LAST);
	assert(bg <= COLOR_BG_LAST);
	return xx fg, xx bg;
	//return COLOR_PAIR(xx ((fg + 1) + (bg + 1) * COLOR_COUNT));
}

editool_assertion_failed :: (loc: Source_Code_Location, message: string) -> bool {
	editool_deinit();
	return runtime_support_assertion_failed(loc, message);
}

editool_quit :: (force: bool = false) -> bool {
	can_quit := true;
	if !force {
		for context.edit.buffers {
			if it.kind != .FILE && it.kind != .DIRECTORY
				continue;
			if it.path == ""
				continue;
			if !is_dirty(it)
				continue;
			edit_alert("File '%' is still dirty!", it.path);
			win := get_window(.BUFFER, not_floating = true);
			change_buffer(win, it);
			can_quit = false;
		}
	}
	if can_quit
		context.edit.should_quit = true;
	return can_quit;
}

// doesn't init any buffers!!
editool_init :: (logfile := "") {
	// logger
	if logfile
		init_file_logger(logfile);
	else
		context.logger = _1984_logger;
	time_this("Editool init");
	// ncurses
	if context.edit.dont_mess_with_tty {
		initscr();
		context.edit.tty_file = stdout;
	} else {
		fd := ifx !context.edit.use_stdout_as_tty_fd then STDIN_FILENO else STDOUT_FILENO;
		tty_name := ttyname(xx fd);
		f := fopen(tty_name, "r+b");
		context.edit.tty_file = f;
		assert(f != null);
		term := newterm(null, f, f);
		assert(term != null);
		set_term(term);
	}
	noecho(); 
	nodelay(stdscr, true);
	keypad(stdscr, true); // use all keys
	set_escdelay(1); // ms.. better to be as small as possible without being zero?!
	if !has_colors() || !can_change_color() {
		log_error("no colors...");
		editool_deinit();
		exit(1);
	}
	start_color();
	use_default_colors(); // use terminals colors..
	log("COLOR PAIRS: %", COLOR_PAIRS);
	#if 1 {
		for fg: -1..COLOR_FG_LAST {
			for bg: -1..COLOR_BG_LAST {
				idx := color_fg_bg(fg, bg);
				fg2, bg2 := uncolor_fg_bg(idx);
				assert(fg2 == fg);
				assert(bg2 == bg);
				//log_error("init color % (%, %) (% %)", idx, fg, bg, fg2, bg2);
				ret := init_pair(xx idx, xx fg, xx bg);
				if ret == ERR {
					log_error("can't init color % (%, %)", idx, fg, bg);
					editool_deinit();
					exit(1);
				}
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
	// x11
	#if X11_ENABLE {
		if !context.edit.no_x11 {
			X11.init_global_display();
			// invisible window for clipboard ..
			context.edit.x11_window = X11.XCreateSimpleWindow(
					X11.x_global_display, X11.DefaultRootWindow(X11.x_global_display),
					0, 0, 1, 1, 0, 0, 0);
			array_add(*X11.x_global_windows, context.edit.x11_window);
		}
	}
	context.print_style.default_format_struct.use_newlines_if_long_form = true;
}

// ...
update_cursor_thing :: (normal: bool) {
	s := ifx normal then "\x1b[2 q" else "\x1b[6 q";
	//print(s);
	cnt := fwrite(s.data, 1, xx s.count, context.edit.tty_file);
	fflush(context.edit.tty_file); // looks like i need to do this..
	log("cnt = %\n", cnt);
}

editool_deinit :: () {
	update_cursor_thing(true);
	endwin();
	if context.edit.should_print_path {
		print("%\n", context.edit.buffer_window.buffer.path);
	}
}

do_the_image_color_thing :: () {
	file_bytes, ok := read_entire_file("/tmp/screenshot.png");
	assert(ok);
	desired_channels := 3;
	image_width, image_height, channels: s32;
	_image_bytes: *u8 = stbi_load_from_memory(file_bytes.data, xx file_bytes.count,
				*image_width, *image_height, *channels, desired_channels = 3);
	image_bytes := []u8.{ data = _image_bytes, count = image_width * image_height * channels };
	assert(channels == desired_channels);
	Color :: struct {
		x, y, z: float;
	}
	dp: []Color = NewArray((image_width+1) * (image_height+1), Color, initialized = false,, allocator=temp);
	{
		// calculate dp
		operator - :: (l: Color, r: Color) -> Color {
			return .{
				l.x - r.x,
				l.y - r.y,
				l.z - r.z,
			};
		}
		operator + :: (l: Color, r: Color) -> Color {
			return .{
				l.x + r.x,
				l.y + r.y,
				l.z + r.z,
			};
		}
		at_dp :: (x: int, y: int) -> *Color #expand {
			return *dp[x*(image_height+1)+y];
		}
		at_image :: (x: int, y: int) -> Color #expand {
			byte_offset := (x*image_height+y) * channels;
			here_bytes: []u8 = advance(image_bytes, byte_offset);
			return .{
				cast(float)here_bytes[0] / 255.0,
				cast(float)here_bytes[1] / 255.0,
				cast(float)here_bytes[2] / 255.0,
			};
		}
		for x: 0..image_width {
			for y: 0..image_height {
				if x == 0 && y == 0 {
					at_dp(x, y).* = .{0, 0, 0};
				} else if x == 0 {
					at_dp(x, y).* = at_dp(x, y-1).* + at_image(x, y-1);
				} else if y == 0 {
					at_dp(x, y).* = at_dp(x-1, y).* + at_image(x-1, y);
				} else {
					at_dp(x, y).* = at_dp(x-1, y).* + at_dp(x, y-1).* - at_dp(x-1, y-1).* + at_image(x-1, y-1);
				}
			}
		}
	}
	//
	WANTED_WIDTH :: 232;
	WANTED_HEIGHT :: 50;
	ratio_x := cast(float)image_width / cast(float)WANTED_WIDTH;
	ratio_y := cast(float)image_height / cast(float)WANTED_HEIGHT;
	ratio := min(ratio_x, ratio_y);
	assert(ratio < 1);
	width := cast(int)(cast(float)WANTED_WIDTH * ratio);
	height := cast(int)(cast(float)WANTED_HEIGHT * ratio);
	//
}

main :: () {
	#if 0 {
		// cbf, maybe later
		do_the_image_color_thing();
		return;
	}
	{
		// yeeted
		// need this shit for utf8
		libc :: #library,system "libc";
		LC_ALL : s32 : 6;
		setlocale :: (what: s32, loc: *u8) -> *u8 #foreign libc;
		setlocale(LC_ALL, "");
	}
	//here_edit: Editool;
	//context.edit = *here_edit;
	filenames: [..]string;
	filenames.allocator = temp;
	logfile := "";
	is_archer := false;
	{
		args := get_command_line_arguments();
		idx := 1;
		should_cd := false;
		while idx < args.count {
			if args[idx] == {
				case "-";
					context.edit.use_stdout_as_tty_fd = true;
					array_add(*filenames, "-");
					idx += 1;
				case "--archer";
					is_archer = true;
					idx += 1;
				case "--print-path";
					context.edit.should_print_path = true;
					idx += 1;
				case "--no-x11";
					context.edit.no_x11 = true;
					idx += 1;
				case "--std-tty";
					context.edit.dont_mess_with_tty = true;
					idx += 1;
				case "--log-file";
					idx += 1;
					if idx >= args.count {
						print("Missing --log-file argument\n", to_standard_error = true);
						exit(1);
					}
					logfile = args[idx];
					idx += 1;
				case "--cd";
					should_cd = true;
					idx += 1;
				case "--dir";
					idx += 1;
					if idx >= args.count {
						print("Missing --dir argument\n", to_standard_error = true);
						exit(1);
					}
					dir := args[idx];
					idx += 1;
					set_working_directory(dir);
				case;
					array_add(*filenames, args[idx]);
					idx += 1;
			}
		}
		if should_cd && filenames.count > 0 {
			fn := filenames[0];
			path := normalize_path(filenames[0],, allocator=temp);
			if !is_directory(path) {
				ok, left, right := split_from_right(path, #char "/");
				if ok
					path = left;
			}
				set_working_directory(path);
		} 
		if !filenames {
			if context.edit.should_print_path
				array_add(*filenames, "./"); 
			else
				array_add(*filenames, ""); // default is empty buffer
		}
	}
	editool_init(logfile = logfile);
	{
		log("filenames: %", filenames);
		parent := context.edit.root;
		if is_archer && filenames.count != 1 {
			editool_deinit();
			print("Error: --archer must have at most 1 directory", to_standard_error = true);
			return;
		}
		for filenames {
			if is_archer {
				win := make_archer_window(it);
				continue;
			}
			if it != "-" {
				buf: *Buffer = get_path_buffer(it);
				win := create_buffer_window(parent, buf, flags = .BUFFER_LINE_NO);
			} else {
				buf: *Buffer = get_path_buffer("");
				all_chars: [..]u8;
				all_chars.allocator = temp;
				while true {
					bytes: [1024]u8 = ---;
					cnt := fread(bytes.data, 1, bytes.count, stdin);
					if !cnt
						break;
					array_adds(*all_chars, slice(cast(string)bytes, 0, xx cnt));
				}
				_insert_string_into_buffer_as_from_file(buf, cast(string)all_chars, this_has_escape_sequences = true);
				log("chars: %\n", cast(string)all_chars);
				win := create_buffer_window(parent, buf, flags = .BUFFER_LINE_NO);
			}
		}
		select_window(parent.children[0]);
		change_container_mode(parent, .TABBED);
	}
	//
	while true {
		using,only(edit) context;
		{
			// housekeeping here + before drawing
			if edit.should_reset_edit_mode {
				_change_edit_mode(edit.mode, force = true);
				edit.should_reset_edit_mode = false;
			}
			for edit.floating_windows {
				if it.flags & .TEMP_FLOATING && _root_of(get_selected_window_of_kind(it.kind)) != it {
					destroy_window(it, force = true);
				}
			}
			windows_to_destroy := edit.windows_to_destroy;
			windows_to_force_destroy := edit.windows_to_force_destroy;
			edit.windows_to_destroy = default_of([..]*Window);
			edit.windows_to_force_destroy = default_of([..]*Window);
			// CRASH: when destroying a window and then buffer, something in buffers pool reset() fails (null pointer)
			for windows_to_destroy {
				_destroy_window(it);
			}
			for windows_to_force_destroy {
				_destroy_window(it, force = true);
			}
			array_reset(*windows_to_destroy);
			array_reset(*windows_to_force_destroy);
			{
				buffers_to_destroy: [..]BufId;
				buffers_to_destroy.allocator = temp;
				for context.edit.buffers {
					if can_destroy_buffer(it)
						array_add(*buffers_to_destroy, it.id);
				}
				for buffers_to_destroy {
					buf := find_buffer(it);
					if buf {
						destroy_buffer(buf);
					}
				}
			}
		}
		ch: s32 = ERR;
		if context.edit.added_chars.count != 0 {
			ch = context.edit.added_chars[0];
			array_ordered_remove_by_index(*context.edit.added_chars, 0);
		} else {
			// If there's a ch ready, we don't bother redrawing, to make shit faster
			ch = getch(); 
			if ch == ERR {
				// But if there's no ch, we redraw and then wait..
				// This makes some things faster ! like pasting or fzf searching
				draw_windows_recursive(context.edit.root);
				//update_cursor_thing(normal = edit.mode != .INSERT); // thin
				update_cursor_thing(normal = edit.mode != .INSERT); // thin
				// Old: If a floating window exists, and the current buffer is not the floating window, then stop floating it.
				// New: If the current buffer is not floating, unfloat all floating windows.
				// New New: idk, neither?
				/*
				if !edit.buffer_window.is_floating {
					for array_copy(edit.floating_windows,, allocator=temp) {
						set_floating(it, false);
					}
				}*/
				#if X11_ENABLE {
					last_is_caps := is_caps_lock();
				}
				while true {
					#if X11_ENABLE {
						if !context.edit.no_x11 {
							Input.update_window_events();
						}
						if last_is_caps != is_caps_lock() {
							// when caps lock changes, we force redraw ..
							break;
						}
					}
					ch = getch();
					//log("queried ch");
					if ch != ERR {
						break;
					}
					sleep_milliseconds(1);
				}
				context.edit.time += 1;
			}
		} 
		if is_printable_char(ch)
			log("got ch: % (%)\n", ch, string.{ data = cast(*u8)*ch, count = 1 });
		else
			log("got ch: % ((%))\n", ch, to_string(keyname(ch)));
		if ch != ERR
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
#load "buffer_creation.jai";
#load "syntax.jai";
#load "window.jai";
#load "window_ext.jai";
#load "exec.jai";
#load "search.jai";
#load "fzf.jai";
#load "ask.jai";
#load "string_commands.jai";

#import "Basic";
#import "File";
#import "String";
#import "ncurses";
#import "fson";
#import "POSIX";
#import "Unicode";
#import "stb_image";

Uniform :: #import "uniform";

#if X11_ENABLE {
	X11 :: #import "X11";
	Input :: #import "Input";
	#import "Clipboard";
	//XkbKeycodeToKeysym :: (dpy: *Display, kc: KeyCode, group: u32, level: u32) -> KeySym #foreign libX11;
	libX11 :: #library,system "libX11";
	XkbUseCoreKbd :: 0x0100;
	XkbLockModifiers :: (dpy: *X11.Display, spec: u32, affect: u32, values: u32) -> X11.Bool #foreign libX11;
	// retarded-shit man pages are wrong, state_return is a pointer!!
	XkbGetIndicatorState :: (dpy: *X11.Display, spec: u32, state_return: *u32) -> X11.Status #foreign libX11;
}