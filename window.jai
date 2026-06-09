
// There are certain windows you can query
// 1. .BUFFER:
// 1.1 '.buffer_window': all commands go towards it. Should rename to buffer_window?.
// 1.2 'get_normal_window()': also a buffer window, but not floating and not special.
// 1.3 '<not implemented>': kinda like get_normal_window(), but includes floating windows?
//
// 2. .CONTAINER:
// 2.1 root
// 2.2 second root <not fully implemented>: container for non-normal windows
// 2.3 get_selected_window_of_type(.CONTAINER): returns whatever container holds the current window
// 2.4 '<not implemented>': 
//
// 3. floating_window: whatever is floating
// 
// Maybe should implement second root as a floating container window?
// A floating window is something that doesn't directly belong to the root.
// Right now it's position/size are constant, relative to screen size.
// Having more information with floating windows could make them more flexible.
//
// Also, windows wanting to change size (e.g. if i wanna see entire search history),
// and propogating that to parent window would be nice.
// That would require the root window to be a single fixed window.
// ^ Seems like the play. 


// NOW, how do i have a window that does something else
// than display a file?
// maybe have some flags to what commands it can accept?
// (or commands have flags on what kinds of windows they can execute?)
Window :: struct {
	Kind :: enum {
		NONE :: 0;
		BUFFER; // contains buffer
		CONTAINER; // contains more windows
	}
	Flags :: enum_flags {
		BORDER; // maybe this should belong to buffer? <- or propogate somehow
		BUFFER_MARKS; // same with this
		BUFFER_STATUS_LINE; // eh..
		CONTAINER_TABS; // should container display tab names?
		NONE :: 0;
	}
	flags: Flags;
	kind: Kind;
	nwindow: *WINDOW;
	nsize: Vec2i;
	is_root: bool = false; // if parent != null
	is_second_root: bool = false;
	is_any_root: bool = false;
	is_hidden: bool = false; // it doesn't belong to any container, and instead will be drawn on demand!!
	parent: *Window; // if exists, always .CONTAINER !!!!
	is_floating: bool; // feels hacky
	#overlay(nsize) ncurses_size: Vec2i;
	user_message: string;
	// BUFFER
	using,only(lines) buffer: *Buffer;
	size: Vec2i;
	begin: Vec2i = .{0, 0};
	cursor: Cursor; // should belong to window, not buffer?
	scroll: int = 0;
	buffer_status_line_position: Vec2i = .{-1, -1};
	buffer_mark_position: int = -1; // y
	second_root_position: int = -1; // if .is_root
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
	cursor_marks: [..]Mark;
	_in_cursor_op: bool; // trying to undo or redo
	user_title: string;
}

/// DRAWING

// this is this only drawing proc allowed to be call rn
draw_windows_recursive :: (win: *Window, this_is_the_floating_call := false) {
	if win.is_floating {
		refresh_window_size(win); // uhh actually
		//if !this_is_the_floating_call
			//return;
	}
	time_this("Draw all windows", really_time = win.is_root);
	wclear(win.nwindow); // clear before children update?
	if win.kind == .CONTAINER {
		if win.container_mode == .TABBED {
			if win.children.count != 0 {
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
	if win.is_root && context.edit.floating_window != null {
		floating_win := context.edit.floating_window;
		// swap and revert
		old_nwindow := floating_win.nwindow;
		floating_win.nwindow = context.edit.floating_nwindow;
		refresh_window_size(floating_win); 
		defer {
			floating_win.nwindow = old_nwindow;
			//refresh_window_size(floating_win); // uhh actually dont
		}
		//
		draw_windows_recursive(floating_win, this_is_the_floating_call = true);
	}
	if win.is_root {
		//draw_windows_recursive(context.search.window);
		//draw_windows_recursive(context.exec.window);
		draw_windows_recursive(context.edit.second_root);
	}
	_draw_window(win);
}

_draw_window :: (using win: *Window) {
	log("drawing window % (current is %), message: %\n", win, context.buffer_window, user_message);
	begin_cursor := Position.{
		getcurx(nwindow),
		getcury(nwindow),
	};
	defer {
		wsyncup(nwindow); // give window content to parents
		if win.is_root {
			// looks like the order of these 2 don't matter
			wrefresh(nwindow);
			wmove(nwindow, xx begin_cursor.y, xx begin_cursor.x);
		}
		//syncok(nwindow, true);
		if context.buffer_window == win
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
		//width, height := getmaxx(stdscr)+1, getmaxy(stdscr)+1;
		lines_to_draw_count := min(lines.count - scroll, size.y);
		lines_to_draw := []Line.{ data = lines.data + scroll, count = lines_to_draw_count };
		_refresh_buffer_modifiers(win, buffer, scroll, scroll + lines_to_draw_count);
		//
		time_this("Draw buffer");
		wclear(nwindow);
		for lines_to_draw {
			true_line_no := it_index + scroll;
			line_no := true_line_no;
			if context.edit.flags & .RELATIVE_LINES {
				if line_no != cursor.y
					line_no = abs(line_no - cursor.y);
			}
			wattrset(nwindow, A_BOLD);
			if win.flags & .BUFFER_MARKS {
				ok, mark := get_mark_at_y(win.buffer, true_line_no);
				if ok {
					log("mark at % %\n", it_index + begin.y, buffer_mark_position + 1);
					mvwaddch(nwindow, xx (it_index + begin.y), xx (buffer_mark_position + 1), mark.name);
				}
			}
			line_no_str := tprint(ifx cursor.y == it_index + scroll then "%   " else " %  ", formatInt(line_no, padding = #char " ", minimum_digits = 3));
			mvwaddnstr(nwindow, xx (it_index + begin.y), xx begin.x, line_no_str.data, xx line_no_str.count);
			wattrset(nwindow, 0);
			wmove(nwindow, xx (it_index + begin.y), xx (5 + begin.x));
			using,only(mods) it;
			assert (it.count <= mods.count);
			for it.chars {
				info := _get_char_info(it);
				// doing goofy colors here.. whatever !!
				if context.edit.flags & .GOOFY_COLORS {
					mods[it_index].bg = xx (it_index / 1 - 1);
				}
				mod := *mods[it_index];
				// matches are color 2
				attr := as_ncurses_attribute(mod);
				wattron(nwindow, attr);
				if mod.replaced.count > 0 {
					waddch(nwindow, mod.replaced[0]);
				} else if info.replaced {
					assert(info.replaced.count == info.size);
					waddnstr(nwindow, info.replaced.data, xx info.replaced.count);
				} else {
					assert(info.size == 1);
					waddch(nwindow, it);
				}
				wattrset(nwindow, 0);
			}
			attr := as_ncurses_attribute(mods[it.chars.count]);
			wattrset(nwindow, attr);
			// to have the correct color at the last position
			waddch(nwindow, #char " "); // to have normal color
			wattrset(nwindow, 0);
		}
		if win.flags & .BUFFER_STATUS_LINE {
			// draw buffer status line at `buffer_status_line_position`
			using,except(lines) win.buffer;
			fn := get_window_title(win,, allocator=temp);
			file_info := tprint(" %  FILE FLAGS: %, BUFFER CAPS: %", fn, file_flags, win.buffer.caps);
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
		wmove(nwindow, xx (cursor.y - scroll + begin.y), xx (real_x + 5 + begin.x));
	} // .BUFFER
	if win.is_root {
		// draw root status line at `root_status_line_y`
		mode_s := tprint("%", context.edit.mode);
		if context.edit.mode == .COMMAND {
			mode_s = tprint("%: '%'", mode_s, keybind_to_string(context.command_state.all_chars,, allocator=temp));
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
		}
		wattrset(nwindow, A_BOLD);
		p := root_status_line_position;
		mvwaddnstr(nwindow, xx p.y, xx p.x, mode_s.data, xx mode_s.count);
		wattrset(nwindow, 0);
		// DRAW SEARCH LINE
	} // .is_root
	if win.container_mode == .TABBED && win.flags & .CONTAINER_TABS {
		count := 0;
		wmove(nwindow, xx tab_info_position.y, xx tab_info_position.x); // top
		//wmove(nwindow, 0, 0);
		for children {
			if it_index == win.active_child {
				wattron(nwindow, COLOR_PAIR(color_fg_bg(2, 7)));
				wattron(nwindow, A_BOLD);
			} else {
				wattron(nwindow, COLOR_PAIR(color_fg_bg(0, 7)));
				wattron(nwindow, A_UNDERLINE);
			}
			title := tprint(" % ", get_window_title(it,, allocator=temp));
			waddnstr(nwindow, title.data, xx title.count);
			count += title.count;
			wattrset(nwindow, 0);
		}
		wattron(nwindow, COLOR_PAIR(color_fg_bg(0, 7)));
		wattron(nwindow, A_STANDOUT);
		for count..size.x-1 {
			waddch(nwindow, #char " ");
		}
		wattrset(nwindow, 0);
	}
}


/// WINDOWING

SECOND_ROOT :: true;

// U CREATE ROOT WITH THIS
create_container_window :: (parent: *Window, nwindow: *WINDOW = null, mode: Window.Container_Mode = .VERTICAL) -> *Window {
	win := New(Window);
	array_add(*context.edit.windows, win);
	win.kind = .CONTAINER;
	win.container_mode = mode;
	win.parent = parent;
	if parent == null {
		if context.edit.root == null {
			context.edit.root = win;
			win.is_root = true;
			win.is_any_root = true;
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
		assert(parent != null);
		nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
	}
	win.nwindow = nwindow;
	//
	if win.is_root {
		#if SECOND_ROOT {
			assert(context.edit.second_root == null);
			tmp := create_container_window(null, null, mode = .TABBED);
			assert(tmp == context.edit.second_root);
		}
	}
	if parent != null {
		array_add(*parent.children, win);
		refresh_window_size(parent);
	}
	return win;
}

// screen is explicitly initialized i guess?
create_buffer_window :: (parent: *Window, buf: *Buffer, flags: Window.Flags = .NONE, nwindow: *WINDOW = null,
			select := true, is_hidden := false) -> *Window {
	if !is_hidden {
		assert(parent != null, "Only container window can be root");
	} else {
		// hidden window might have a parent?? idk
		assert(parent == null);
	}
	win := New(Window);
	array_add(*context.edit.windows, win);
	win.is_hidden = is_hidden;
	win.flags = flags;
	if buf.kind == .FILE {
		win.flags |= .BUFFER_MARKS;
		win.flags |= .BUFFER_STATUS_LINE;
	}
	win.kind = .BUFFER;
	win.buffer = buf;
	win.parent = parent;
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
	//
	array_add(*buf.windows, win); // HMMMM
	move_cursor(win, .{0, 0});
	if parent != null {
		array_add(*parent.children, win);
		refresh_window_size(parent);
	}
	if select {
		select_window(win);
	}
	return win;
}

// buffers get leaked-ish
// Doesn't bother to check if it can destroy !!
destroy_window :: (win: *Window, _force := false) {
	if !_force
		array_add(*context.edit.windows_to_destroy, win);
	else
		array_add(*context.edit.windows_to_force_destroy, win);
}

// this gets called at the right time!
// Pass `_force = true` flag, if destroying a hidden window. 
_destroy_window :: (win: *Window, _force: bool = false) -> bool {
	assert(win.kind == .BUFFER);
	if win.is_root {
		edit_error("NOT DESTROYING ROOT");
		return false;
	}
	// if it doesn't have a
	if win.parent {
		if win.parent.children.count == 1 {
			edit_error("NOT SUPPORTED REMOVING THE ONLY CHILD WINDOW");
			return false;
		}
	} else {
		assert(win.is_hidden);
		if !_force {
			edit_error("Must force to destroy a hidden window");
			return false;
		}
	}
	is_selected := get_selected_window_of_kind(win.kind) == win;
	should_unselect := is_selected;
	if win.is_floating {
		set_floating(win, false);
	}
	if win.parent != null {
		idx := _child_index_of_window(win);
		if idx < win.parent.active_child || idx + 1 == win.parent.children.count {
			win.parent.active_child -= 1;
		}
		array_ordered_remove_by_index(*win.parent.children, idx);
		if context.buffer_window == win {
		}
	} else {
		if context.buffer_window == win {
			context.buffer_window = _active_buffer_of(context.edit.root);
		}
	}
	{
		ok, idx := array_find(context.edit.windows, win);
		assert(ok);
		// doesn't have to be ordered remove, i think
		array_ordered_remove_by_index(*context.edit.windows, idx);
	}
	{
		ok, idx := array_find(win.buffer.windows, win);
		assert(ok);
		// doesn't have to be ordered remove, i think
		array_ordered_remove_by_index(*win.buffer.windows, idx);
	}
	parent := win.parent;
	if should_unselect {
		if win.parent != null {
			select_window(parent.children[win.parent.active_child]);
		} else {
			select_window(context.edit.root);
		}
	}
	free(win);
	if parent != null
		refresh_window_size(parent);
	return true;
}

// This is the most messy proc, unclear when it is or when it should be called...
// But works! Just slow.
refresh_window_size :: (using win: *Window, force := false) {
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
		win.flags &= ~(.BUFFER_STATUS_LINE | .BUFFER_MARKS);
	}
	// this and initialization are the only place window flags are touched !!!
	if win.kind == .BUFFER && (win.buffer.kind == .FILE || win.is_floating)
		win.flags |= .BORDER;
	if win.kind != .BUFFER 
		win.flags |= .BORDER;
	if win.buffer == context.search.buffer || win.buffer == context.exec.buffer || win == context.edit.second_root
		win.flags &= ~.BORDER;
	if win.kind == .CONTAINER {
		win.flags |= .CONTAINER_TABS;
	}
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
			SIZE_Y :: 3;
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
		begin.x += 2;
		size.x -= 2;
	}
	if win.flags & .CONTAINER_TABS && win.container_mode == .TABBED {
		// tabbed window has a info thing at the top
		// might want it to optionally be multiple lines??
		tab_info_position = .{ begin.x, begin.y };
		begin.y += 1;
		size.y -= 1;
	}
	log("win % is now of size %\n", win, size);
	if win.kind == {
		case .BUFFER;
			normalize_scroll(win);
		case .CONTAINER;
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
	}
}

set_floating :: (win: *Window, flag: bool) -> bool {
	if win.is_floating == flag {
		return true;
	}
	if flag {
		if win.kind != .BUFFER
			return false;
		if context.edit.floating_window != null {
			return false;
		}
		context.edit.floating_window = win;
		win.is_floating = true;
	} else {
		assert(context.edit.floating_window == win);
		context.edit.floating_window = null;
		win.is_floating = false;
		refresh_window_size(win);
	}
	return true;
}

// this is the only proc that changes context.buffer_window
// This assumes that current container/buffer windows are invalid !
// Maybe in the future there should be some un_unselect callback?
select_window :: (win: *Window) {
	reset_edit_mode();
	// win.parent might be null !!
	context.container_window = ifx win.kind == .CONTAINER then win else win.parent;
	context.buffer_window = _active_buffer_of(win);
	while win.parent != null {
		win.parent.active_child = _child_index_of_window(win);
		win = win.parent;
	}
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

nest_window :: (parent: *Window, child: *Window, select := true) -> bool {
	if parent == null {
		return false;
	}
	if child.parent != parent {
		return false;
	}
	idx := _child_index_of_window(child);
	// Create new container
	new_container := create_container_window(parent, mode = ifx parent.container_mode != .VERTICAL then .VERTICAL else .HORIZONTAL);
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
	return true;
}

change_container_mode :: (win: *Window, mode: Window.Container_Mode) {
	if win.kind != .CONTAINER {
		edit_alert("NOT A CONTAINER", is_internal = true);
		return;
	}
	win.container_mode = mode;
	refresh_window_size(win, force = true);
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
			win = context.edit.root; // this will never float
	}
	if not_floating {
		if win.is_floating
			win = context.edit.root;
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

// should be used with temp alloc?
// also, maybe should be set instead of queried
get_window_title :: (using win: *Window) -> string {
	if win.user_title
		return win.user_title;
	if win.kind == {
		case .BUFFER;
			if buffer.kind == {
				case .FILE;
					return ifx buffer.filename else "<none>"; 
				case .CUSTOM;
					return "<custom>";
				case;
					return "<UNKNOWN BUFFER>";
			}
		case .CONTAINER;
			return "<container>";
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

select_relative_window :: (rel: int) -> bool {
	parent := context.container_window;
	if !parent
		return false;
	sibling_count := parent.children.count;
	idx := parent.active_child;
	idx = (idx + rel) % sibling_count;
	idx = (idx + sibling_count) % sibling_count;
	select_window(parent.children[idx]);
	return true;
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

// there might be cases where this is null
_root_of :: (win: *Window) -> *Window {
	if !win
		return null;
	while win.parent != null
		win = win.parent;
	return win;
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
	#if 1 {
		if move_res == ERR {
			edit_error("move res is err");
			log_stack_trace(context.stack_trace);
		}
		if resize_res == ERR {
			edit_error("resize res is err");
			log_stack_trace(context.stack_trace);
		}
	}
}

// when parent has changed !
_ncurses_remake :: (using win: *Window) {
	delwin(nwindow);
	nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
}
