
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
// ^ But first, proper nested windows.


Vec2i :: struct {
	x, y: int;
}

// @CompilerBug can't use with interface, NOT A STRUCT
//Position :: #type,isa Vec2i;
Position :: struct {
	x, y: int;
	#overlay(x) vec2: Vec2i;
}

operator + :: (l: $T/.[Vec2i, Position] , r: T) -> T {
	return .{ l.x + r.x, l.y + r.y };
}

operator - :: (l: $T/.[Vec2i, Position] , r: T) -> T {
	return .{ l.x - r.x, l.y - r.y };
}

operator * :: (l: $T/.[Vec2i, Position], r: int) -> T #symmetric {
	return .{ l.x * r, l.y * r };
}

operator == :: (l: $T/.[Vec2i, Position], r: T) -> bool {
	return l.x == r.x && l.y == r.y;
}

operator < :: (l: Position, r: Position) -> bool {
	return l.y < r.y || (l.y == r.y && l.x < r.x);
}

operator <= :: (l: Position, r: Position) -> bool {
	return l.y < r.y || (l.y == r.y && l.x <= r.x);
}

operator >= :: (l: Position, r: Position) -> bool {
	return r <= l;
}

Mark :: struct {
	position: Position = .{-1, -1};
	scroll: int = -1;
	name: u8 = 0; // Not all marks are named.
	buffer_id: BufId = BUF_ID_NULL;
	time: Editime = -1;
}

// name has to be explicitly set
create_mark :: (using win: *Window) -> Mark {
	return .{
		position = cursor.position,
		scroll = scroll,
		buffer_id = buffer.id,
		time = context.edit.time,
	};
}

go_to_mark :: (win: *Window, mark: Mark, is_jump := true) -> bool {
	if !change_buffer(win, mark.buffer_id)
		return false;
	move_cursor(win, mark.position, jump = is_jump);
	set_scroll(win, mark.scroll);
	return true;
}

find_mark :: (using buf: *Buffer, name: s32) -> bool, Mark {
	for marks {
		if it.name == name {
			return true, it;
		}
	}
	return false, .{};
}

// assumes ok name
set_mark :: (using buf: *Buffer, mark: Mark) {
	for * marks {
		if it.name == mark.name {
			it.* = mark;
			return;
		}
	}
	array_add(*marks, mark);
}

// there might be more than one! 
get_mark_at_y :: (using buf: *Buffer, y: int) -> bool, Mark {
	for marks {
		if it.position.y == y {
			return true, it;
		}
	}
	return false, .{};
}


// starts from 0/0
Cursor :: struct {
	using position: Position;
	virtual_real_x: int; // this is real x, and *not* in terms of char index
}

// NOW, how do i have a window that does something else
// than display a file?
// maybe have some flags to what commands it can accept?
// (or commands have flags on what kinds of windows they can execute?)
Window :: struct {
	Kind :: enum {
		BUFFER; // contains buffer
		CONTAINER; // contains more windows
		NONE :: 0;
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
	root_search_line_position: Vec2i = .{ -1, -1 }; 
	root_exec_line_position: Vec2i = .{ -1, -1 };
	tab_info_position: Vec2i =.{ -1, -1 };
	// last cursor operation that was executed
	// ALWAYS -1 <=  x < cursor_marks.count
	cursor_mark_index: int = -1;
	cursor_marks: [..]Mark;
	_in_cursor_op: bool; // trying to undo or redo
}

_child_index_of_window :: (win: *Window) -> int {
	assert(win.parent != null);
	for win.parent.children {
		if it == win
			return it_index;
	}
	assert(false);
	return -1;
}

// do i name this active? or selected? or current ???
_find_active_buffer_window_in_container :: (win: *Window) -> *Window {
	while win.kind != .BUFFER {
		assert(win.kind == .CONTAINER);
		win = win.children[win.active_child];
	}
	return win;
}

get_active_non_floating_window :: () -> *Window {
	return _find_active_buffer_window_in_container(context.edit.root);
}

// buffers get leaked
destroy_window :: (win: *Window, _force := false) {
	if !_force
		array_add(*context.edit.windows_to_destroy, win);
	else
		array_add(*context.edit.windows_to_force_destroy, win);
}

// when leaving floating windows
select_normal_window :: () {
	select_window(_find_active_buffer_window_in_container(context.edit.root));
}

// when leaving floating windows
get_normal_window :: () -> *Window {
	return _find_active_buffer_window_in_container(context.edit.root);
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
			context.buffer_window = _find_active_buffer_window_in_container(context.edit.root);
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


// should be used with temp alloc?
// also, maybe should be set instead of queried
get_window_title :: (using win: *Window) -> string {
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
	if win.buffer == context.search.buffer || win.buffer == context.exec.buffer
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
		{
			SIZE_Y :: 1;
			size.y -= SIZE_Y;
			root_search_line_position = .{ begin.x,  begin.y + size.y };
			_ncurses_full_resize(context.search.window.nwindow,
					root_search_line_position, .{size.x, SIZE_Y });
			refresh_window_size(context.search.window);
		}
		{
			SIZE_Y :: 3;
			size.y -= SIZE_Y;
			root_exec_line_position = .{ begin.x,  begin.y + size.y };
			_ncurses_full_resize(context.exec.window.nwindow,
					root_exec_line_position, .{size.x, SIZE_Y });
			refresh_window_size(context.exec.window);
		}
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

_active_buffer_of :: (win: *Window) -> *Window {
	while win.kind != .BUFFER {
		win = win.children[win.active_child];
	}
	return win;
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
	if win.buffer.id == id
		return true;
	buf := find_buffer(id);
	if !buf
		return false;
	change_buffer(win, buf);
	return true;
}

change_buffer :: (win: *Window, new_buf: *Buffer) {
	assert(win.kind == .BUFFER);
	assert(new_buf != null);
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

// This should return whatever window of kind, depending on what you wanna do.. 
// Don't wanna do stuff just yet though
get_window :: (kind: Window.Kind, maybe_floating := true, not_special := false) {
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

_remake_nwindow :: (using win: *Window) {
	nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
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
	_remake_nwindow(child);
	refresh_window_size(parent);
	if select {
		select_window(new_container);
	}
	return true;
}

// U CREATE ROOT WITH THIS
create_container_window :: (parent: *Window, nwindow: *WINDOW = null, mode: Window.Container_Mode = .VERTICAL) -> *Window {
	win := New(Window);
	array_add(*context.edit.windows, win);
	win.kind = .CONTAINER;
	win.container_mode = mode;
	win.parent = parent;
	if parent == null {
		assert(context.edit.root == null);
		context.edit.root = win;
		win.is_root = true;
		win.is_any_root = true;
	}
	if nwindow == null {
		assert(parent != null);
		nwindow = derwin(parent.nwindow, 1, 1, 0, 0);
	}
	win.nwindow = nwindow;
	//
	if parent != null {
		array_add(*parent.children, win);
		refresh_window_size(parent);
	}
	if win.is_root {
		assert(context.edit.second_root == null);
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

change_container_mode :: (win: *Window, mode: Window.Container_Mode) {
	if win.kind != .CONTAINER {
		edit_alert("NOT A CONTAINER", is_internal = true);
		return;
	}
	win.container_mode = mode;
	refresh_window_size(win, force = true);
}

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
			draw_windows_recursive(win.children[win.active_child]);
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
		draw_windows_recursive(context.search.window);
		draw_windows_recursive(context.exec.window);
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
		if context.edit.mode == .EXEC {
			mode_s = tprint("% :%", mode_s, context.edit.exec.str);
		}
		{
			search_string := get_search_info_for_status_bar(get_normal_window());
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

// SCROLL BEGIN

normalize_scroll :: (using win: *Window) {
	//
	scroll = clamp(scroll, 0, max(0, lines.count - size.y));
	//
	scroll = max(cursor.y - size.y + 1, scroll);
	scroll = min(cursor.y, scroll);
	// kinda a hack?
	// TODO: doesn't work properly
	// _update_cursor_mark(win, false);
}

offset_scroll :: (using win: *Window, val: int) {
	scroll += val;
	normalize_scroll(win);
}

set_scroll :: (using win: *Window, val: int) {
	scroll = val;
	normalize_scroll(win);
}


// CURSOR START
// (should have less of these tbh)

cursor_undo :: (using win: *Window) -> bool {
	_in_cursor_op = true;
	defer _in_cursor_op = false;
	if cursor_mark_index <= 0 {
		return false; // heh :)
	}
	cursor_mark_index -= 1;
	ok := go_to_mark(win, cursor_marks[cursor_mark_index]);
	return ok;
}

cursor_redo :: (using win: *Window) -> bool {
	_in_cursor_op = true;
	defer _in_cursor_op = false;
	if cursor_mark_index + 1 >= cursor_marks.count {
		return false;
	}
	cursor_mark_index += 1;
	ok := go_to_mark(win, cursor_marks[cursor_mark_index]);
	return ok;
}

_update_cursor_mark :: (using win: *Window, create: bool) {
	if _in_cursor_op
		return;
	if cursor_mark_index >= 0 {
		last_mark := cursor_marks[cursor_mark_index];
		if last_mark.time == context.edit.time {
			create = false;
		}
		// Changing buffer overwrites multiple marks in a single tick.
		// Not sure if that's good, or if it even matters.
		if last_mark.buffer_id != buffer.id {
			create = true;
		}
	}
	if create {
		if cursor_mark_index >= 0 {
			cursor_marks.count = cursor_mark_index + 1; 
		}
		array_add(*cursor_marks, create_mark(win));
		cursor_mark_index = cursor_marks.count - 1;
	} else if cursor_mark_index >= 0 {
		// fully update the mark
		time := cursor_marks[cursor_mark_index].time;
		cursor_marks[cursor_mark_index] = create_mark(win);
		cursor_marks[cursor_mark_index].time = time;
	}
}

normalize_position :: (using win: *Window, pos: Position) -> Position {
	ret: Position = ---;
	ret.y = clamp(pos.y, 0, lines.count-1);
	ret.x = clamp(pos.x, 0, lines[ret.y].count);
	return ret;
}

normalize_cursor :: (using win: *Window, with_scroll: bool, force_jump := false) {
	cursor.position = normalize_position(win, cursor.position);
	if with_scroll
		normalize_scroll(win);
	should_create_mark := force_jump || cursor_mark_index < 0;
	_update_cursor_mark(win, should_create_mark);
}

// only these 3 call normalize_cursor, or change cursor position..
// 

move_cursor :: (using win: *Window, pos: Position, jump := false) {
	//cursor.position = pos;
	//normalize_cursor(win, with_scroll = true, force_jump = jump);
	move_cursor_y(win, pos.y);
	move_cursor_x(win, pos.x);
	normalize_cursor(win, with_scroll = false, force_jump = jump);
}

move_cursor_y :: (using win: *Window, y: int) {
	cursor.y = clamp(y, 0, lines.count-1); // normalizes self, because needs to get virtual x
	virtual_x := _from_real_x_in_line(*win.lines[cursor.y], cursor.virtual_real_x);
	cursor.x = virtual_x;
	normalize_cursor(win, with_scroll = true);
}

move_cursor_x :: (using win: *Window, x: int) {
	cursor.x = clamp(x, 0, lines[cursor.y].count);
	refresh_cursor_virtual_x(win);
	normalize_cursor(win, with_scroll = false);
}

// these 2 are extras..

update_from_cursor_virtual_x :: (using win: *Window) {
	virtual_x := _from_real_x_in_line(*win.lines[cursor.y], cursor.virtual_real_x);
	move_cursor_x(win, virtual_x);
}

refresh_cursor_virtual_x :: (using win: *Window) {
	cursor.virtual_real_x = _get_real_x_in_line(*lines[cursor.y], cursor.x);
}

offset_cursor :: (using win: *Window, x: int, y: int) {
	move_cursor(win, .{ cursor.x + x, cursor.y + y });
	/*
	assert(x == 0 || y == 0);
	if y != 0 {
		move_cursor_y(win, cursor.y + y);
	}
	if x != 0 {
		move_cursor_x(win, cursor.x + x);
	}*/
}

// this is kinda a helper
// (count is number)
// this also moves scroll !!
move_cursor :: (res: Motion_Result, count: int = 1) {
	if res.status != .OK
		return;
	win := context.buffer_window;
	if res.is_jump {
		move_cursor(win, res.end, jump = true);
	} else if res.start.x == res.end.x || (res.flags & .Y_ONLY) {
		y := win.cursor.y + (res.end.y - win.cursor.y) * count;
		move_cursor_y(win, y);
	} else if res.start.y == res.end.y {
		x := win.cursor.x + (res.end.x - win.cursor.x) * count;
		move_cursor_x(win, x);
	} else {
		// count not supported
		move_cursor(win, res.end);
	}
	if res.scroll >= 0
		set_scroll(win, res.scroll); // set scroll first, incase its a jump
}

// CURSOR END

_get_real_x_in_line :: (line: *Line, x: int) -> int {
	if x == 0
		return 0;
	ret: int = 0;
	for 0..min(x-1, line.count-1) {
		ret += _get_char_info(line.chars[it]).size;
	}
	//ret += 1; // the NEXT char counts as size 1
	return ret;
}

_from_real_x_in_line :: (line: *Line, real_x: int) -> int {
	for line.chars {
		if real_x <= 0
			return it_index;
		real_x -= _get_char_info(it).size;
		if real_x < 0
			return it_index;
	}
	return line.chars.count;
}
// SCROLL END

// EDITING WINDOW (BUFFER) COMMANDS

/*
write_string :: (using buf: *Buffer, s: string) {
	str := s;
	while str != "" {
		for str {
			if it == #char "\n" || it_index + 1 == str.count {
				cut := string.{ data = str.data, count = it_index };
				_write_normal_string(buf, cut);
				if it == #char "\n"
					write_char(buf, #char "\n");
				str = advance(str, it_index+1);
				break;
			}
		}
	}
}
*/

// no funky characters!
_write_normal_string :: (using win: *Window, s: string) {
	_write_normal_string(win, cursor.position, s);
}

// no funky characters!
_write_normal_string :: (using win: *Window, pos: Position, s: string) {
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = pos.y,
		x = pos.x,
		count = s.count,
		chars = cast([]u8)s,
	});
}

write_char :: (using win: *Window, ch: u8) {
	if ch == #char "\n" {
		split_line(win, cursor.position);
		return;
	} 
	execute_buffer_operation(win, .{
		kind = .INSERT_CHARS,
		y = cursor.y,
		x = cursor.x,
		count = 1,
		chars = .[ ch ],
	});
}

merge_lines_after :: (using win: *Window, line_y: int) {
	if line_y < 0
		return;
	if line_y + 1 >= lines.count
		return;
	execute_buffer_operation(win, .{
		kind = .MERGE_LINES,
		y = line_y,
		count = 1, // not used
	});
}

delete_chars :: (using win: *Window, count: int) -> bool {
	return delete_chars(win, cursor.position, count);
}

// this is different to delete_at_x_offset, because it doesn't mess with lines
delete_chars :: (using win: *Window, pos: Position, count: int) -> bool {
	line := *lines[pos.y];
	count = min(line.count - pos.x, count);
	if count <= 0
		return false;
	execute_buffer_operation(win, .{
		kind = .DELETE_CHARS,
		y = pos.y,
		x = pos.x,
		count = count,
	});
	return true;
}

// this should change to something else (x_offset argument is akward)
delete_at_x_offset :: (using win: *Window, x_offset: int) {
	assert(x_offset == 0 || x_offset == -1);
	x := cursor.x + x_offset;
	if x < 0 {
		if cursor.y == 0
			return;
		merge_lines_after(win, cursor.y-1);
	} else if x >= lines[cursor.y].count {
		merge_lines_after(win, cursor.y);
	} else {
		execute_buffer_operation(win, .{
			kind = .DELETE_CHARS,
			y = cursor.y,
			x = x,
			count = 1,
		});
	}
}

delete_range_in_line :: (using win: *Window, y: int, lx: int, rx: int) {
	if clamp(y, 0, lines.count-1) != y
		return;
	if lx > rx
		lx, rx = rx, lx;
	line := *lines[y];
	lx = clamp(lx, 0, line.count-1);
	rx = clamp(rx, 0, line.count-1);
	if lx < 0
		return;
	execute_buffer_operation(win, .{
		kind = .DELETE_CHARS,
		y = y,
		x = lx,
		count = rx - lx + 1,
	});
}

delete_line_range :: (using win: *Window, l: int, r: int) {
	if l > r
		l, r = r, l;
	delete_lines(win, l, r - l + 1);
}

delete_lines :: (using win: *Window, y: int, count: int = 1) {
	y = clamp(y, 0, lines.count-1);
	count = min(count, lines.count - y + 1);
	execute_buffer_operation(win, .{
		kind = .DELETE_LINES,
		y = y,
		count = count,
	});
}

split_line :: (using win: *Window) {
	split_line(win, cursor.position);
}

split_line :: (using win: *Window, pos: Position) {
	// probably validated...
	execute_buffer_operation(win, .{
		kind = .SPLIT_LINE,
		y = pos.y,
		x = pos.x,
	});
}

// EDITING BUFFER COMMANDS END

// other stuff

// TODO: maybe rename to undo_text or something...
// Still not sure if i wanna but anything else in buffer operation
// i dont like these operations being shared between buffer and window files..

buffer_undo :: (win: *Window) -> bool, Buffer_Op {
	reverse_operation :: inline (op: *Buffer_Op) -> bool {
		if op.kind == {
			case .DELETE_LINES;
				op.kind = .INSERT_LINES;
			case .INSERT_LINES;
				op.kind = .DELETE_LINES;
			//
			case .DELETE_CHARS;
				op.kind = .INSERT_CHARS;
			case .INSERT_CHARS;
				op.kind = .DELETE_CHARS;
			//
			case .SPLIT_LINE;
				op.kind = .MERGE_LINES;
				op.count = 1;
			case .MERGE_LINES;
				assert(op.count == 1);
				op.kind = .SPLIT_LINE;
			case;
				return false;
		}
		return true;
	}
	using buf: *Buffer = win.buffer;
	if buf.operation_index < 0
		return false, .{};
	op := buf.operations[buf.operation_index];
	if op.flags & .NO_UNDO {
		return false, op;
	}
	if !reverse_operation(*op) {
		edit_alert("Can't undo? %\n", op.kind, is_internal = true);
		return false, op; // this is a panic
	}
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		buf.operation_index -= 1;
	}
	return ok, op;
}

buffer_redo :: (win: *Window) -> bool, Buffer_Op {
	using buf: *Buffer = win.buffer;
	if operation_index + 1 >= operations.count
		return false, .{};
	op := buf.operations[buf.operation_index+1];
	ok := _execute_buffer_operation(win, buf, *op, .MOVE_CURSOR);
	if ok {
		operation_index += 1;
	}
	return ok, op;
}

_ncurses_full_resize :: (w: *WINDOW, begin: Vec2i, size: Vec2i) {
	// stupid ass shit:
	mvderwin(w, 0, 0);
	wresize(w, 1, 1);
	resize_res := wresize(w, xx size.y, xx size.x);
	move_res := mvderwin(w, xx begin.y, xx begin.x);
	#if 1 {
		if move_res == ERR {
			edit_error("move res is err\n");
		}
		if resize_res == ERR {
			edit_error("resize res is err\n");
		}
	}
}
