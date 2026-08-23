
// 
// Maybe should implement second root as a floating container window?
// A floating window is something that doesn't directly belong to the root.
// Right now it's position/size are constant, relative to screen size.
// Having more information with floating windows could make them more flexible.
// ^ I think second root will be just a sibling of root, and i'll add a true root
// 
//
// Also, windows wanting to change size (e.g. if i wanna see entire search history),
// and propogating that to parent window would be nice.
// That would require the root window to be a single fixed window.
// ^ Seems like the play. 

//I_WANT_THE_BORDERS :: true; // not implemented

Container_Item :: struct {
	fixed_size: int = -1;
	weighted_size: float = -1;
	_calculated_size: int;
}

Anchor :: enum {
	NONE :: 0;
	BEGIN;
	END;
	MIDDLE;
}

Anchored :: struct {
	anchor: Anchor = .MIDDLE;
	value: int;
}

//
Floating_Position :: struct {
	lx: Anchored;
	rx: Anchored;
	ly: Anchored;
	ry: Anchored;
}

_eval_anchored :: (a: Anchored, begin: int, size: int) -> int {
	return _eval_anchor(a.anchor, begin, size) + a.value;
}

_eval_anchor :: (a: Anchor, begin: int, size: int) -> int {
	if a == {
		case .BEGIN;
			return begin;
		case .MIDDLE;
			return begin + size / 2;
		case .END;
			return begin + size;
		case;
			edit_error("Bad anchor");
			return -1;
	}
}

WinId :: #type,distinct s64;
WIN_ID_NULL :: 0;
_running_window_id: WinId = 1;

next_window_id :: () -> WinId {
	ret := _running_window_id;
	_running_window_id += 1;
	return ret;
}

// NOW, how do i have a window that does something else
// than display a file?
// maybe have some flags to what commands it can accept?
// (or commands have flags on what kinds of windows they can execute?)
Window :: struct {
	Kind :: enum {
		NONE :: 0;
		BUFFER; // contains buffer
		CONTAINER; // contains more windows
		PLACEHOLDER; // doesn't have anything, will be replaced with a different window soon?
	}
	Flags :: enum_flags {
		BORDER; // maybe this should belong to buffer? <- or propogate somehow
		BUFFER_MARKS; // same with this
		BUFFER_LINE_NO; // could have some enum for what type of line no is drawn...
		BUFFER_STATUS_LINE; // eh..
		CONTAINER_TABS; // should container display tab names?
		TEMP_FLOATING; // MUST BE PASSED ON INIT. It starts as floating, and if it's no longer selected, then destroy it.
		NONE :: 0;
	}
	id: WinId;
	pool: Pool; // released on destroy
	flags: Flags;
	kind: Kind;
	nwindow: *WINDOW;
	nsize: Vec2i;
	#overlay(nsize) ncurses_size: Vec2i;
	is_root: bool = false; // if parent != null
	is_second_root: bool = false;
	is_any_root: bool = false;
	// It doesn't belong to any container, and instead will be drawn on demand!!
	// (doesn't change)
	is_hidden: bool = false; 
	parent: *Window; // if exists, always .CONTAINER !!!!
	is_floating: bool; // feels hacky
	user_message: string;
	// BUFFER
	using,only(lines) buffer: *Buffer;
	size: Vec2i;
	begin: Vec2i = .{0, 0};
	cursor: Cursor; // should belong to window, not buffer?
	scroll: int = 0;
	buffer_status_line_position: Vec2i = .{-1, -1};
	buffer_mark_position: int = -1; // y
	buffer_line_no_position: int = -1; // y
	second_root_position: int = -1; // if .is_root
	floating_position: Floating_Position; // if is floating
	container_item: Container_Item; // .parent is .CONTAINER
	// CONTAINER
	Container_Mode :: enum {
		NONE :: 0;
		VERTICAL;
		HORIZONTAL;
		TABBED;
		// aliases for exec
		TAB :: TABBED;
		T :: TAB;
		V :: VERTICAL;
		H :: HORIZONTAL;
	}
	Container_Mode_Bits :: enum_flags {
		VERTICAL :: (1 << Container_Mode.VERTICAL);
		HORIZONTAL :: (1 << Container_Mode.HORIZONTAL);
		TABBED :: (1 << Container_Mode.TABBED);
	}
	container_mode: Container_Mode = .NONE;
	children: [..]*Window;
	active_child: int = 0; // maybe should be -1 by default?
	root_status_line_position: Vec2i = .{ -1, -1 }; // root is always container
	//root_search_line_position: Vec2i = .{ -1, -1 }; 
	//root_exec_line_position: Vec2i = .{ -1, -1 };
	root_second_line_position: Vec2i = .{ -1, -1 };
	tab_info_position: Vec2i =.{ -1, -1 };
	// last cursor operation that was executed
	// ALWAYS -1 <=  x < cursor_marks.count
	cursor_mark_index: int = -1;
	cursor_marks: [..]Mark; // cursor undo/redo !
	_in_cursor_op: bool; // trying to undo or redo
	_is_being_destroyed: bool = false;
	// callbacks ... should be careful
	// 
	before_draw: #type (*Window) -> ();
	apply_mods: #type (*Window, []*Line) -> ();
	motion_proc: #type (*Window, Motion_Result) -> bool; // unused
	on_destroy: #type (*Window) -> (); // must not do anything funny !
	//
	map_window_for_motion: #type (*Window, *Motion) -> *Window;
	user_data: *void;
	ref_count: int; // hold/release
	//real_size_y: int = -1; // only valid for buffer windows
	commands: [..]Command;
}

// not used as a constant everywhere
BUFFER_LINE_NO_SIZE_X :: 5;
BUFFER_MARKS_SIZE_X :: 2;
/// DRAWING

// this is this only drawing proc allowed to be call rn
draw_windows_recursive :: (win: *Window) {
	if win.is_floating {
		//refresh_window_size(win); // uhh actually
	}
	time_this("Draw all windows", really_time = win.is_root);
	//wclear(win.nwindow); // clear before children update?
	// ^ only clearing buffer windows !!
	if win.kind == .CONTAINER {
		if win.container_mode == .TABBED {
			if win.children.count != 0 {
				log("active child: % (%)", win.active_child, win.children.count);
				draw_windows_recursive(win.children[win.active_child]);
			} else {
				edit_error("Tabbed container has no children..");
			}
		} else {
			for win.children {
				draw_windows_recursive(it);
			}
		}
	}
	if win.is_root {
		for context.edit.floating_windows {
			// expensive to resize !!
			{
				//FLOATING_PADDING :: Vec2i.{ 20, 10 };
			}
			//refresh_window_size(it); 
			draw_windows_recursive(it);
		}
	}
	if win.is_root {
		draw_windows_recursive(context.edit.second_root);
	}
	_draw_window(win);
}

_draw_window :: (using win: *Window) {
	if win.before_draw
		win.before_draw(win);
	begin_cursor := Position.{
		getcurx(nwindow),
		getcury(nwindow),
	};
	defer {
		if !win.is_root
			wsyncup(nwindow); // give window content to parents
		if win != context.buffer_window {
			// looks like the order of these 2 don't matter
			wmove(nwindow, xx begin_cursor.y, xx begin_cursor.x);
		}
		if win.is_root {
			wrefresh(nwindow);
		}
		//syncok(nwindow, true);
		if context.buffer_window == win && context.buffer_window.nwindow != stdscr
			wcursyncup(nwindow);
	}
	// akward to draw border like this...
	if win.kind != .BUFFER {
		if get_selected_window_of_kind(kind) == win {
			//wattrset(nwindow, A_BOLD);
			wattrset(nwindow, COLOR_PAIR(color_fg_bg(13, -1)));
		}
		if win.flags & .BORDER
			box(nwindow, 0, 0);
		wattrset(nwindow, 0);
	}
	defer {
		// could do just this case for drawing border?
		if win.kind == .BUFFER {
			if get_selected_window_of_kind(kind) == win {
				wattrset(nwindow, A_BOLD);
			}
			if win.flags & .BORDER
				box(nwindow, 0, 0);
			wattrset(nwindow, 0);
		}
	}
	if win.kind == .BUFFER {
		time_this("Draw buffer");
		lines_to_draw: [..]*Line;
		lines_to_draw.allocator = temp;
		cursor_actual_position: Position = .{
			0, 
			begin.y,
		};
		{
			y := scroll;
			found_cursor := false;
			if size.y <= 0 {
				edit_alert("Not enough size to draw something !! "); // still fucks up sometimes..
			}
			while y < lines.count && lines_to_draw.count < max(size.y, 1) {
				array_add(*lines_to_draw, *lines[y]);
				fold := get_fold_exact(win.buffer, y);
				//
				if y < cursor.y
					cursor_actual_position.y += get_line_real_size_as_y(win, *lines[y]);
				if cursor.y == y || (fold && fold.start <= cursor.y && cursor.y <= fold.end) {
					// this stuff (and line drawing) breaks with bordered windows i think
					x := begin.x + _get_real_x_in_line(*lines[y], cursor.x);
					cursor_actual_position.y += (x + begin.x + size.x) / (begin.x + size.x) - 1;
					cursor_actual_position.x = x % (begin.x + size.x);
				}
				//
				if fold {
					assert(fold.start <= fold.end);
					y = fold.end + 1;
				} else {
					y += 1;
				}
			}
			assert(lines_to_draw.count > 0, "scroll: %, line.count: %, size: %", scroll, lines.count, size.y);
		}
		_refresh_buffer_modifiers(win, buffer, scroll, peek(lines_to_draw) - lines.data + 1);
		// buf apply mods takes priority
		if buffer.apply_mods
			buffer.apply_mods(win, lines_to_draw);
		if win.apply_mods
			win.apply_mods(win, lines_to_draw);
		//
		wclear(nwindow); // ONLY CLEARING BUFFER WINDOWS !
		y_offset := 0;
		// cursor actual position might be overriden !
		for lines_to_draw {
			y := it - lines.data;
			ny := it_index + begin.y + y_offset; // ncurses y
			if it_index + y_offset > size.y
				break;
			line_no := y;
			if context.edit.flags & .RELATIVE_LINES {
				if line_no != cursor.y
					line_no = abs(line_no - cursor.y);
			}
			{
				wattrset(nwindow, COLOR_PAIR(color_fg_bg(2, -1) | A_BOLD));
				if win.flags & .BUFFER_MARKS {
					// buffer makr position was already taken into account when resizing window !
					ok, mark := get_mark_at_y(win.buffer, y);
					if ok {
						mvwaddch(nwindow, xx ny, xx (buffer_mark_position + 1), mark.name);
					}
				}
				wattrset(nwindow, 0);
				wattrset(nwindow, A_BOLD);
				// I don't know which one to pick !
				wattron(nwindow, COLOR_PAIR(color_fg_bg(3, -1)));
				wattron(nwindow, COLOR_PAIR(color_fg_bg(6, -1)));
				if win.flags & .BUFFER_LINE_NO {
					line_no_str := tprint(ifx cursor.y == y then "%   " else " %  ", formatInt(line_no, padding = #char " ", minimum_digits = 3));
					mvwaddnstr(nwindow, xx ny, xx buffer_line_no_position, line_no_str.data, xx line_no_str.count);
				}
				wattrset(nwindow, 0);
			}
			wmove(nwindow, xx ny, xx (begin.x));
			using,only(mods, user_mods) it;
			//assert (it.count <= mods.count);
			line_str := it.as_string;
			while line_str {
				ch_idx := it.chars.count - line_str.count;
				ch, res := utf8_next_character(*line_str);
				if res != .CONVERSION_OK
					break;
				info := _get_char_info(ch);
				mod: Char_Mod = ---;
				if ch_idx < user_mods.count {
					mod = user_mods[ch_idx];
				} else {
					Initialize(*mod);
				}
				if info.override_color != -1
					mod.fg = info.override_color;
				// matches are color 2
				AA :: true;
				#if AA {
					char_mod_on(nwindow, mod);
				} else {
					attr := as_ncurses_attribute(mod);
					wattrset(nwindow, attr);
				}
				//if mod.replaced.count > 0
					//waddch(nwindow, mod.replaced[0]);
				if info.replaced {
					assert(info.replaced.count == info.size);
					waddnstr(nwindow, info.replaced.data, xx info.replaced.count);
				} else {
					if is_ascii(ch) {
						waddch(nwindow, ch);
					} else {
						// cringe
						wch: cchar_t;
						arr: [2]s32 = .[ xx ch, 0 ];
						setcchar(*wch, arr.data, A_NORMAL, 0, null);
						wadd_wch(nwindow, *wch);
					}
				}
				#if AA {
					char_mod_off(nwindow);
				} else {
					wattrset(nwindow, 0);
				}
			}
			if it.chars.count < user_mods.count {
				attr := as_ncurses_attribute(user_mods[it.chars.count]);
				wattrset(nwindow, attr);
				// to have the correct color at the last position
				waddch(nwindow, #char " "); // to have normal color
				wattrset(nwindow, 0);
			}
			final_y := getcury(nwindow);
			y_offset += get_line_real_size_as_y(win, it) - 1;
		}
		if win.flags & .BUFFER_STATUS_LINE {
			// draw buffer status line at `buffer_status_line_position`
			using,except(lines) win.buffer;
			fn := get_title(win,, allocator=temp);
			file_info := tprint(" %:%:%  FILE FLAGS: %", fn, cursor.y, cursor.x, file_flags);
			if win.user_message != "" {
				file_info = tprint("% | %\n", file_info, win.user_message);
			}
			wattron(nwindow, A_STANDOUT); // seems to swap fg/bg !!
			wattron(nwindow, A_BOLD);
			wattron(nwindow, COLOR_PAIR(color_fg_bg(3, -1)));
			p := buffer_status_line_position;
			mvwaddnstr(nwindow, xx p.y, xx p.x, file_info.data, xx file_info.count);
			for 1..ncurses_size.x-file_info.count
				waddch(nwindow, #char " ");
			wattrset(nwindow, 0);
		}
		real_x := _get_real_x_in_line(*lines[cursor.y], cursor.x);
		//
		//wmove(nwindow, xx (cursor.y - scroll + begin.y), xx (real_x + begin.x));
		wmove(nwindow, xx cursor_actual_position.y, xx cursor_actual_position.x);
	} // .BUFFER
	if win.is_root {
		// draw root status line at `root_status_line_y`
		mode_s := tprint("%", context.edit.mode);
		if context.edit.mode == .COMMAND {
			mode_s = tprint("% '%'", mode_s, keybind_to_string(context.command_state.all_chars,, allocator=temp));
		}
		if context.edit.mode == .ASK {
			mode_s = tprint("% I AM ASKING: '%'", mode_s, context.ask.request);
		}
		{
			exec_string := get_exec_info_for_status_bar();
			if exec_string
				mode_s = tprint("% %", mode_s, exec_string);
		}
		{
			search_string := get_search_info_for_status_bar(get_window(.BUFFER));
			if search_string
				mode_s = tprint("% | %", mode_s, search_string);
		}
		for context.edit.alerts {
			mode_s = tprint("% | %", mode_s, it);
			free(it);
		}
		array_reset(*context.edit.alerts);
		p := root_status_line_position;
		wmove(nwindow, xx p.y, xx p.x);
		if is_caps_lock() {
			wattrset(nwindow, A_BOLD);
			wattrset(nwindow, COLOR_PAIR(color_fg_bg(8, -1)));
			waddstr(nwindow, "CAPS ");
			wattrset(nwindow, 0);
		}
		wattrset(nwindow, A_BOLD);
		wattrset(nwindow, COLOR_PAIR(color_fg_bg(2, -1)));
		waddnstr(nwindow, mode_s.data, xx mode_s.count);
		wattrset(nwindow, 0);
		for mode_s.count..size.x-1 {
			waddch(nwindow, #char " ");
		}
		// DRAW SEARCH LINE
	} // .is_root
	if win.container_mode == .TABBED && win.flags & .CONTAINER_TABS {
		count := 0;
		wmove(nwindow, xx tab_info_position.y, xx tab_info_position.x); // top
		//wmove(nwindow, 0, 0);
		for children {
			if it_index == win.active_child {
				wattron(nwindow, COLOR_PAIR(color_fg_bg(2, -1)));
				wattron(nwindow, A_BOLD);
			} else {
				wattron(nwindow, COLOR_PAIR(color_fg_bg(0, -1)));
				wattron(nwindow, A_UNDERLINE);
			}
			title := tprint(" % ", get_title(it,, allocator=temp));
			waddnstr(nwindow, title.data, xx title.count);
			count += title.count;
			wattrset(nwindow, 0);
		}
		wattrset(nwindow, 0);
		wattron(nwindow, COLOR_PAIR(color_fg_bg(0, -1)));
		wattron(nwindow, A_STANDOUT);
		for count..size.x-1 {
			waddch(nwindow, #char " ");
		}
		wattrset(nwindow, 0);
	}
}

/// WINDOWING

SECOND_ROOT :: true;

// yes, this initializes root....
// (doesn't refresh window size !)
_new_window :: (kind: Window.Kind, parent: *Window, flags: Window.Flags,
			nwindow: *WINDOW, is_hidden: bool) -> *Window {
	if is_hidden {
		assert(parent == null);
	} 
	win := New(Window);
	array_add(*context.edit.windows, win);
	set_allocators(*win.pool);
	win.commands.allocator = allocator_of(*win.pool);
	win.id = next_window_id();
	win.is_hidden = is_hidden;
	win.flags = flags;
	win.kind = kind;
	win.parent = parent;
	//
	if !is_hidden && parent == null {
		assert(kind == .CONTAINER, "only container can be root");
		if context.edit.root == null {
			context.edit.root = win;
			win.is_root = true;
			win.is_any_root = true;
			assert(nwindow != null);
		} else if context.edit.second_root == null {
			context.edit.second_root = win;
			win.is_second_root = true;
			win.is_any_root = true;
			nwindow = derwin(stdscr, 1, 1, 0, 0);
		} else {
			assert(false);
		}
	}
	if nwindow == null {
		if parent != null {
			// just auto create nwindow..
			nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
		} else {
			// Assumes that it belongs to root, will need to remove this later..
			assert(context.edit.root != null);
			nwindow = derwin(context.edit.root.nwindow, 1, 1, 0, 0);
		}
	}
	win.nwindow = nwindow;
	if win.is_root {
		#if SECOND_ROOT { // true
			assert(context.edit.second_root == null);
			tmp := create_container_window(null, null, mode = .TABBED);
			//remove_flags(tmp, .CONTAINER_TABS);
			assert(tmp == context.edit.second_root);
		}
	}
	if parent != null {
		array_add(*parent.children, win);
	} 
	return win;
}

// U CREATE ROOT WITH THIS (in _new_window())
create_container_window :: (parent: *Window, nwindow: *WINDOW = null, flags: Window.Flags = .NONE, mode: Window.Container_Mode = .VERTICAL, is_hidden := false) -> *Window {
	win := _new_window(.CONTAINER, parent, flags | .CONTAINER_TABS, nwindow, is_hidden = is_hidden);
	win.container_mode = mode;
	if parent != null {
		refresh_window_size(parent);
	} else {
		refresh_window_size(win);
	}
	return win;
}

create_placeholder_window :: (parent: *Window, flags: Window.Flags = .NONE, is_hidden := false) -> *Window {
	win := _new_window(.PLACEHOLDER, parent, flags, null, is_hidden = is_hidden);
	if win.parent != null
		refresh_window_size(win.parent);
	return win;
}

// screen is explicitly initialized i guess?
create_buffer_window :: (parent: *Window, buf: *Buffer, flags: Window.Flags = .NONE, nwindow: *WINDOW = null,
			select := true, is_hidden := false) -> *Window {
	if buf.kind == .FILE || buf.kind == .DIRECTORY {
		flags |= .BUFFER_MARKS;
		flags |= .BUFFER_LINE_NO;
		flags |= .BUFFER_STATUS_LINE;
	}
	win := _new_window(.BUFFER, parent, flags, nwindow, is_hidden = is_hidden);
	win.buffer = buf;
	array_add(*buf.windows, win); // HMMMM
	if parent != null {
		refresh_window_size(parent);
	}
	if select {
		select_window(win);
	}
	return win;
}

select_or_create_buffer_window :: (buf: *Buffer, default_mode: Window_Select_Mode = .NONE) -> (win: *Window, error_message: string) {
	// overriding default mode..
	mode := context.edit.window_select_mode;
	{
		// buffer specific modes... for now !
		if mode == .NONE
			mode = default_mode;
		if mode == .WINDOW {
			for < buf.windows {
				if _root_of(it) == context.edit.root {
					return it, "";
				} 
			}
			mode = .OPEN;
		}
		if mode == .OPEN {
			win := get_window(.BUFFER, not_floating = true, not_special = true);
			change_buffer(win, buf);
			return win, "";
		}
	}
	win, msg := select_or_create_placeholder_window(mode);
	if win {
		convert_into_buffer_window(win, buf);
	}
	return win, msg;
}

select_or_create_placeholder_window :: (default_mode: Window_Select_Mode = .NONE) -> (win: *Window, error_message: string) {
	mode := context.edit.window_select_mode;
	if mode == .NONE || mode == .WINDOW || mode == .OPEN
		mode = default_mode;
	if mode == .NONE || mode == .WINDOW || mode == .OPEN
		mode = .TAB;
	win: *Window;
	if mode == {
		case .FLOAT;
			#if 1 { // testing
				win = create_placeholder_window(null, .TEMP_FLOATING, is_hidden = true);
				set_floating(win);
				//convert_into_buffer_window(win, buf);
			} else {
				win = create_buffer_window(null, buf, flags = .TEMP_FLOATING, is_hidden = true);
				set_floating(win);
			}
		case .TAB; #through;
		case .VERTICAL;
			parent := get_window(.CONTAINER, not_floating = true);
			need_container: Window.Container_Mode = ifx mode == .TAB then .TABBED else .VERTICAL;
			while parent != null {
				if parent.container_mode == need_container
					break;
				parent = parent.parent;
			}
			if parent == null {
				if context.buffer_window != null {
					buf_win := get_window(.BUFFER, not_floating = true);
					parent = nest_window(buf_win.parent, buf_win, select = true, mode = need_container);
				}
			}
			if parent == null {
				return null, "Can't create container";
			}
			#if 1 { // testing
				win = create_placeholder_window(parent);
				//convert_into_buffer_window(win, buf);
			} else {
				win = create_buffer_window(parent, buf);
			}
		case;
			assert(false, "bad mode %", mode);
	}
	assert(win != null);
	return win, "";
}

// window select (or open) mode
Window_Select_Mode :: enum {
	NONE :: 0;
	OPEN;
	WINDOW_; // @CompilerBug whatever man, just make this normal and you'll see the problem
	WINDOW :: WINDOW_; // ctrl + b - maybe find a window with that buffer, and select that instead
	TAB;
	VERTICAL;
	FLOAT;
	// 
	O :: OPEN;
	T :: TAB;
	V :: VERTICAL;
	F :: FLOAT;
	B :: WINDOW; // WINDOW !!, @CompilerBug can't use just WINDOW, probably because of the curses import
}

push_pop_window_select_mode :: (mode: Window_Select_Mode) #expand {
	old := context.edit.window_select_mode;
	context.edit.window_select_mode = mode;
	`defer {
		context.edit.window_select_mode = old;
	}
}

add_flags :: (win: *Window, flags: Window.Flags) {
	assert(flags & .TEMP_FLOATING == 0);
	win.flags |= flags;
	refresh_window_size(win);
}

remove_flags :: (win: *Window, flags: Window.Flags) {
	win.flags &= ~flags;
	refresh_window_size(win);
}

// find implies that it might return null
find_window :: (id: WinId) -> *Window {
	for context.edit.windows {
		if it.id == id
			return it;
	}
	return null;
}

// buffers get leaked-ish
// Doesn't bother to check if it can destroy !!
destroy_window :: (win: *Window, force := false) {
	if win._is_being_destroyed
		return;
	ok, msg := can_destroy_window(win, force = force);
	if !ok {
		edit_alert("%", msg);
		return;
	}
	win._is_being_destroyed = true;
	if !force
		array_add(*context.edit.windows_to_destroy, win);
	else
		array_add(*context.edit.windows_to_force_destroy, win);
}

hold :: (thing: *$T/.[Window, Buffer]) {
	thing.ref_count += 1;
}

// not sure if i like the name "release", since it usually means memory..
release :: (thing: *$T/.[Window, Buffer]) {
	assert(thing.ref_count > 0);
	thing.ref_count -= 1;
}

// right now force only is relavant if the window is floating..
can_destroy_window :: (win: *Window, force: bool = false, even_if_only_child := false) -> bool, string {
	if win.is_root
		return false, "Can't destroy root";
	if win.ref_count > 0
		return false, "Window is referenced";
	if win.parent  {
		if win.parent.children.count == 1 && !even_if_only_child {
			return false, "Can't destroy child";
		}
	} else {
		assert(win.is_hidden); // sanity check?
		if !force {
			return false, "Must force to destroy a hidden window";
		}
	}
	if win.kind == .CONTAINER {
		for win.children {
			ok, msg := can_destroy_window(it);
			if !ok
				return ok, msg;
		}
	}
	return true, "";
}

// this gets called at the right time!
// Pass `force = true` flag, if destroying a hidden window. 
_destroy_window :: (win: *Window, force: bool = false, even_only_child := false) -> bool, string {
	ok, msg := can_destroy_window(win, force = force, even_if_only_child = even_only_child);
	if !ok {
		edit_alert("%", msg);
		return false, msg;
	}
	if win.on_destroy
		win.on_destroy(win);
	if win.kind == .CONTAINER {
		for array_copy(win.children,, allocator=temp) {
			// TODO: this might mess up if windows get destroyed in a certain order.
			// should use window ids when saving what to destroy
			_destroy_window(it, even_only_child = true);
		}
		array_reset(*win.children);
	}
	array_reset(*win.cursor_marks);
	if win.nwindow != stdscr {
		delwin(win.nwindow);
	}
	if win.is_floating {
		reset_floating(win);
	}
	is_selected := get_selected_window_of_kind(win.kind) == win;
	should_unselect := is_selected;
	if win.parent != null {
		idx := _child_index_of_window(win);
		assert(idx >= 0);
		//log("% % %", idx, win.parent.active_child, win.parent.children.count);
		if idx < win.parent.active_child || (idx == win.parent.active_child && idx + 1 == win.parent.children.count) {
			win.parent.active_child -= 1;
		}
		array_ordered_remove_by_index(*win.parent.children, idx);
		//log("% % %", idx, win.parent.active_child, win.parent.children.count);
	} 
	{
		ok, idx := array_find(context.edit.windows, win);
		assert(ok);
		// doesn't have to be ordered remove, i think
		array_ordered_remove_by_index(*context.edit.windows, idx);
	}
	if win.kind ==.BUFFER {
		ok, idx := array_find(win.buffer.windows, win);
		assert(ok);
		// doesn't have to be ordered remove, i think
		array_ordered_remove_by_index(*win.buffer.windows, idx);
	}
	parent := win.parent;
	if should_unselect {
		if win.parent != null && win.parent.active_child >= 0 {
			select_window(parent.children[win.parent.active_child]);
		} else {
			select_window(context.edit.root);
		}
	}
	release(*win.pool);
	free(win);
	if parent != null {
		{
			// If all siblings are fixed after getting destroyed,
			// we want them to be weighted instead so they fix the screen.
			all_are_fixed := true;
			for parent.children {
				if it.container_item.fixed_size == 0 {
					all_are_fixed = false;
					break;
				}
			}
			if all_are_fixed {
				for parent.children {
					it.container_item = .{ weighted_size = cast(float)it.container_item.fixed_size };
				}
			}
		}
		refresh_window_size(parent);
	}
	return true, "";
}

update_container_item :: (win: *Window, item: Container_Item) {
	win.container_item = item;
	if win.parent
		refresh_window_size(win.parent);
}


// This is the most messy proc, unclear when it is or when it should be called...
// But works! Just slow.
refresh_window_size :: (using win: *Window, force := false) {
	log("REFRESHING WINDOW SIZE");
	if is_floating {
		p := floating_position;
		root := context.edit.root;
		pos := Vec2i.{
			_eval_anchored(p.lx, root.begin.x, root.size.x),
			_eval_anchored(p.ly, root.begin.y, root.size.y),
		};
		sz := Vec2i.{
			_eval_anchored(p.rx, root.begin.x, root.size.x),
			_eval_anchored(p.ry, root.begin.y, root.size.y),
		};
		sz -= pos;
		_ncurses_full_resize(nwindow, pos, sz);
	}
	force = true; // WHATEVER MANNN
	new_nsize := Vec2i.{
		getmaxx(nwindow),
		getmaxy(nwindow),
	};
	if !force && nsize == new_nsize
		return;
	begin = .{0, 0};
	nsize = new_nsize;
	size = nsize;
	if win.kind != .BUFFER {
		win.flags &= ~(.BUFFER_STATUS_LINE | .BUFFER_MARKS | .BUFFER_LINE_NO);
	}
	// this and initialization are the only place window flags are touched !!!
	#if 0 {
		if win.kind == .BUFFER && (win.buffer.kind == .FILE || win.is_floating)
			win.flags |= .BORDER;
		if win.kind != .BUFFER 
			win.flags |= .BORDER;
	}
	if win == context.search.window || win == context.exec.window || win == context.edit.second_root || win.container_item.fixed_size > 0
		win.flags &= ~.BORDER;
	if win.flags & .BORDER {
		begin.y += 1;
		begin.x += 1;
		size.y -= 2;
		size.x -= 2;
	}
	if win.flags & .BUFFER_STATUS_LINE {
		// buffer has a status line at the bottom
		size.y -= 1; 
		buffer_status_line_position = .{ begin.x, begin.y + size.y };
	}
	if win.is_root {
		// root has a status line at the bottom
		{
			size.y -= 1;
			root_status_line_position = .{ begin.x,  begin.y + size.y };
		}
		// EXTRA THING
		#if SECOND_ROOT {{
			SIZE_Y :: 2;
			size.y -= SIZE_Y;
			pos := Vec2i.{ begin.x,  begin.y + size.y };
			sz := Vec2i.{size.x, SIZE_Y };
			_ncurses_full_resize(context.edit.second_root.nwindow,
					pos, sz);
			_ncurses_full_resize(context.edit.second_root.nwindow,
					pos, sz);
			refresh_window_size(context.edit.second_root);
		}}
	}
	if win.flags & .BUFFER_MARKS {
		buffer_mark_position = begin.x;
		begin.x += BUFFER_MARKS_SIZE_X;
		size.x -= BUFFER_MARKS_SIZE_X;
	}
	if win.flags & .BUFFER_LINE_NO {
		buffer_line_no_position = begin.x;
		begin.x += BUFFER_LINE_NO_SIZE_X;
		size.x -= BUFFER_LINE_NO_SIZE_X;
	}
	if win.flags & .CONTAINER_TABS && win.container_mode == .TABBED {
		// tabbed window has a info thing at the top
		// might want it to optionally be multiple lines??
		tab_info_position = .{ begin.x, begin.y };
		begin.y += 1;
		size.y -= 1;
	}
	if win.kind == {
		case .BUFFER;
			normalize_scroll(win);
		case .CONTAINER;
			if container_mode == .TABBED {
				for children {
					_ncurses_full_resize(it.nwindow, begin, size);
					refresh_window_size(it, force = force);
				}
			} else {
				total_weight: float = 0;
				total_fixed: int = 0;
				for children {
					using it.container_item;
					if fixed_size > 0 {
						total_fixed += fixed_size;
					} else {
						w := ifx weighted_size > 0 then weighted_size else 1.0;
						total_weight += w;
					}
				}
				total_size := ifx container_mode == .VERTICAL then size.x else size.y;
				total_weighted_size := max(total_size - total_fixed, 0);
				weight: float = 0;
				fixed: int = 0;
				next_child_begin := ifx container_mode == .VERTICAL then begin.x else begin.y;
				for children {
					child_begin: int = next_child_begin;
					child_size: int = ---;
					using it.container_item;
					if fixed_size > 0 {
						child_size = fixed_size;
					} else {
						w := ifx weighted_size > 0 then weighted_size else 1.0;
						new_weight := weight + w;
						child_size = (round_to_int((new_weight / total_weight) * total_weighted_size) - round_to_int((weight / total_weight) * total_weighted_size));
						weight = new_weight;
					}
					child_begin2: Vec2i = begin;
					child_size2: Vec2i = size;
					if container_mode == .VERTICAL {
						child_begin2.x = child_begin;
						child_size2.x = child_size;
					} else {
						child_begin2.y = child_begin;
						child_size2.y = child_size;
					}
					// ...
					next_child_begin += child_size;
					_ncurses_full_resize(it.nwindow, child_begin2, child_size2);
					refresh_window_size(it, force = force);
				}
			}
			/*
			for children {
				child_begin: Vec2i = begin;
				child_end: Vec2i = begin + size;
				if container_mode == {
					case .VERTICAL;
						b := child_begin.x;
						child_begin.x = b + (it_index     * size.x) / (children.count);
						child_end.x =   b + ((it_index+1) * size.x) / (children.count);
					case .HORIZONTAL;
						b := child_begin.y;
						child_begin.y = b + (it_index     * size.y) / (children.count);
						child_end.y =   b + ((it_index+1) * size.y) / (children.count);
					case .TABBED;
						//child_begin.y += 1;
						//child_end.y += 1;
						//
					case;
						log_error("BAD CONTAINER MODE %", container_mode);
				}
				// NCURSES SHIT
				child_size := child_end - child_begin;
				_ncurses_full_resize(it.nwindow, child_begin, child_size);
				refresh_window_size(it, force = force);
			}
			*/
	}
}

reset_floating :: (win: *Window) -> bool {
	return _set_floating(win, false, .{});
}

set_floating :: (win: *Window, pos: Floating_Position, border := true) -> bool {
	return _set_floating(win, true, pos, border);
}

set_floating :: (win: *Window) -> bool {
	return set_floating(win, .{
		lx = .{ .BEGIN, 10 },
		rx = .{ .END, -10 },
		ly = .{ .BEGIN, 5 },
		ry = .{ .END, -5 },
	});
}

_set_floating :: (win: *Window, flag: bool, pos: Floating_Position, border := true) -> bool {
	if !win.is_hidden {
		edit_alert("Tried to set a non-hidden as floating");
		return false;
	}
	if flag {
		if win._is_being_destroyed {
			edit_error("set_floating() on a destroyed window ?");
			return false;
		}
		if !win.is_floating {
			// this doesn't refresh window size?
			array_add(*context.edit.floating_windows, win);
			win.is_floating = true;
			if border
				win.flags |= .BORDER; 
		}
		win.floating_position = pos;
		refresh_window_size(win);
	} else { // !flag
		if win.is_floating {
			ok := array_ordered_remove_by_value(*context.edit.floating_windows, win);
			assert(ok);
			win.is_floating = false;
			refresh_window_size(win);
		}
		if win.flags & .TEMP_FLOATING {
			destroy_window(win);
		}
	}
	return true;
}

// this is the only proc that changes context.buffer_window
// This assumes that current container/buffer windows are invalid !
// Maybe in the future there should be some un_unselect callback?
select_window :: (win: *Window) {
	//reset_edit_mode(); // actually let's not do this
	// win.parent might be null !!
	context.container_window = ifx win.kind == .CONTAINER then win else win.parent;
	context.buffer_window = _active_buffer_of(win);
	while win.parent != null {
		win.parent.active_child = _child_index_of_window(win);
		win = win.parent;
	}
}

convert_into_buffer_window :: (win: *Window, buf: *Buffer) {
	assert(win.kind == .PLACEHOLDER);
	if buf.kind == .FILE || buf.kind == .DIRECTORY {
		win.flags |= .BUFFER_MARKS;
		win.flags |= .BUFFER_LINE_NO;
		win.flags |= .BUFFER_STATUS_LINE;
	}
	win.kind = .BUFFER;
	win.buffer = buf;
	array_add(*buf.windows, win); 
	refresh_window_size(win);
}

convert_into_container_window :: (win: *Window, mode: Window.Container_Mode) {
	assert(win != null);
	assert(win.kind == .PLACEHOLDER);
	win.kind = .CONTAINER;
	win.container_mode = mode;
	refresh_window_size(win);
}

change_buffer :: (win: *Window, id: BufId) -> bool {
	buf := find_buffer(id);
	if !buf
		return false;
	change_buffer(win, buf);
	return true;
}

change_buffer :: (win: *Window, new_buf: *Buffer) {
	assert(win.kind == .BUFFER);
	assert(new_buf != null);
	if win.buffer == new_buf
		return;
	{
		ok, idx := array_find(win.buffer.windows, win);
		assert(ok);
		// doesn't have to be ordered remove, i think
		array_ordered_remove_by_index(*win.buffer.windows, idx);
	}
	win.buffer = new_buf;
	array_add(*new_buf.windows, win);
	move_cursor(win, .{0, 0} /* , jump = true */ );
	refresh_window_size(win); // the buffer might be of different kind..
}

// There might be some nonsense if one of these windows is selected.
// So call select_window(...) right after this.
swap_window_locations :: (win1: *Window, win2: *Window) -> bool, string {
	if win1 == win2
		return true, "";
	if win1.parent == null || win2.parent == null
		return false, "Can't swap locations with roots";
	p1 := win1.parent;
	p2 := win2.parent;
	idx1 := _child_index_of_window(win1);
	idx2 := _child_index_of_window(win2);
	p1.children[idx1] = win2;
	p2.children[idx2] = win1;
	win1.parent = p2;
	win2.parent = p1;
	refresh_window_size(p1);
	refresh_window_size(p2);
	return true, "";
}

nest_window :: (parent: *Window, child: *Window, mode: Window.Container_Mode = .NONE, select := true) -> (created: *Window) {
	if parent == null {
		return null;
	}
	if child.parent != parent {
		return null;
	}
	idx := _child_index_of_window(child);
	// Create new container
	if mode == .NONE
		mode = ifx parent.container_mode != .VERTICAL then .VERTICAL else .HORIZONTAL;
	new_container := create_container_window(parent, mode = mode);
	// Move child to new container
	array_add(*new_container.children, child);
	new_container.active_child = 0;
	child.parent = new_container;
	// Move container to the childs position, and remove child
	assert(parent.children[idx] == child);
	parent.children[idx] = new_container;
	assert(peek(parent.children) == new_container);
	pop(*parent.children);
	_ncurses_remake(child);
	refresh_window_size(parent);
	if select {
		select_window(new_container);
	}
	return new_container;
}

change_container_mode :: (win: *Window, mode: Window.Container_Mode) {
	if win.kind != .CONTAINER {
		edit_alert("NOT A CONTAINER", is_internal = true);
		return;
	}
	win.container_mode = mode;
	refresh_window_size(win, force = true);
}

_lowest_child_of :: (win: *Window) -> *Window {
	while win.kind == .CONTAINER && win.children.count > 0 {
		win = win.children[win.active_child];
	}
	return win;
}

// This should return whatever window of kind, depending on what you wanna do.. 
// Don't wanna do stuff just yet though
// `not_special` means it doesn't belong to second root
// `not_floating` is self explainatory
// `not_null` means it will ensure that it returns a proper window. Not sure how though...
get_window :: (kind: Window.Kind, $not_floating := false, not_special := true, $not_null := true) -> *Window {
	assert(kind == .CONTAINER || kind == .BUFFER || kind == .NONE);
	win := get_selected_window_of_kind(kind);
	if !win
		win = context.buffer_window;
	assert(win != null);
	// From here, win != null
	if not_special {
		if _root_of(win).is_second_root
			win = _lowest_child_of(context.edit.root); // this will never float
	}
	if not_floating {
		if _root_of(win).is_floating
			win = _lowest_child_of(context.edit.root);
	}
	assert(win != null);
	if kind == .NONE || win.kind == kind {
		return win;
	}
	if kind == {
		case .BUFFER;
			ret := _active_buffer_of(win);
			assert(ret != null);
			assert(ret.kind == kind);
			return ret;
		case .CONTAINER;
			ret := win.parent;
			assert(ret != null);
			assert(ret.kind == kind);
			return ret;
	}
	assert(false, "Can't find window...");
	return null;
}

/// WINDOWING HELPERS

get_title :: (using buf: *Buffer) -> string {
	if user_title
		return user_title;
	if kind == {
		case .DIRECTORY; #through;
		case .FILE;
			s := ifx path else "[NONE]";
			if path {
				pwd := get_working_directory(,,allocator = temp);
				if peek(pwd) != #char "/"
					pwd = tprint("%/", pwd);
				if starts_with(s, pwd) {
					s = advance(s, pwd.count);
					//if s.count && s[0] == #char "/"
						//s = advance(s, 1);
				}
			}
			if kind == .DIRECTORY {
				if s == ""
					s = "./";
				else if peek(s) != #char "/"
					s = tprint("%/", s);
				s = tprint("[D] %", s);
			}
			if path && is_dirty(buf)
				s = tprint("* %", s);
			return s;
		case .CUSTOM;
			return "[custom]";
		case;
			return "<UNKNOWN BUFFER>";
	}
}

// should be used with temp alloc?
// also, maybe should be set instead of queried
get_title :: (using win: *Window) -> string {
	if win.kind == {
		case .BUFFER;
			return get_title(buffer);
		case .CONTAINER;
			if win.children.count == 0
				return "<empty container>";
			if win.children.count == 1
				return get_title(win.children[win.active_child]);
			return tprint("[%] %", win.children.count, get_title(win.children[win.active_child]));
		case;
			return "<UNKNOWN WINDOW>";
	}
}

get_selected_window_of_kind :: (kind: Window.Kind) -> *Window {
	if kind == {
		case .BUFFER;
			return context.buffer_window;
		case .CONTAINER;
			return context.container_window;
		case;
			return null;
	}
}

// when leaving floating windows
select_normal_window :: () {
	select_window(get_window(.NONE, not_floating = true, not_special = true));
}

find_relative_window :: (rel: int, wanted_mode := Window.Container_Mode.NONE) -> *Window {
	return find_relative_window(context.buffer_window, rel, wanted_mode);
}

change_parent :: (win: *Window, new_parent: *Window) -> bool {
	if win.parent == new_parent
		return true;
	if new_parent.kind != .CONTAINER
		return false;
	if win.parent == null
		return false; // idk
	{
		idx := _child_index_of_window(win);
		array_ordered_remove_by_index(*win.parent.children, idx);
		if idx <= win.parent.active_child
			win.active_child -= 1;
	}
	{
		array_add(*new_parent.children, win);
		win.parent = new_parent;
	}
	refresh_window_size(win.parent);
	refresh_window_size(new_parent);
	return true;
}

find_relative_window :: (win: *Window, rel: int, wanted_mode := Window.Container_Mode.NONE) -> *Window {
	if !win 
		return null;
	while win.parent && (wanted_mode != .NONE && win.parent.container_mode != wanted_mode) {
		win = win.parent;
	}
	if !win.parent
		return null;
	sibling_count := win.parent.children.count;
	idx := _child_index_of_window(win);
	idx = (idx + rel) % sibling_count;
	idx = (idx + sibling_count) % sibling_count;
	return win.parent.children[idx];
}

select_relative_window :: (rel: int, wanted_mode := Window.Container_Mode.NONE) -> bool {
	win := find_relative_window(rel, wanted_mode);
	if !win
		return false;
	select_window(win);
	return true;
}

// there might be cases where this is null
_root_of :: (win: *Window) -> *Window {
	if !win
		return null;
	while win.parent != null
		win = win.parent;
	return win;
}


#scope_file

_child_index_of_window :: (win: *Window) -> int {
	assert(win.parent != null);
	for win.parent.children {
		if it == win
			return it_index;
	}
	assert(false);
	return -1;
}

_active_buffer_of :: (win: *Window) -> *Window {
	while win.kind != .BUFFER {
		win = win.children[win.active_child];
	}
	return win;
}


_ncurses_full_resize :: (w: *WINDOW, begin: Vec2i, size: Vec2i) {
	// stupid ass shit:
	mvderwin(w, 0, 0);
	wresize(w, 1, 1);
	resize_res := wresize(w, xx size.y, xx size.x);
	move_res := mvderwin(w, xx begin.y, xx begin.x);
	#if 0 {
		if move_res == ERR {
			edit_error("move res is err");
			log_stack_trace(context.stack_trace);
		}
		if resize_res == ERR {
			edit_error("resize res is err (%)", size);
			log_stack_trace(context.stack_trace);
		}
	}
}

// when parent has changed !
_ncurses_remake :: (using win: *Window) {
	delwin(nwindow);
	nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
}

// test