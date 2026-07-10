


Exec :: struct {
	#as using _: String_Command_State;
}

Exec_Command :: struct {
	name: string;
	Proc :: #type ([]string) -> Exec_Result;
	proc: Proc;
}

Exec_Result :: struct {
	Status :: enum {
		OK :: 0;
		ERROR;
	}
	status: Status = .OK;
	error_message: string; // error message is constant or temp allocated
}

start_exec :: () {
	string_commands_start(*context.exec, "");
}


editool_exec_init :: () {
	string_commands_init(*context.exec, "Exec");
	context.exec.execute = _execute_exec;
}

get_exec_info_for_status_bar :: () -> string {
	using context.exec;
	if !as_string
		return "";
	if context.buffer_window != window
		return "";
	return tprint("EXEC :%", as_string);
}

_execute_exec :: (__: *String_Command_State, ___: *Window) {
	using context.exec;
	args: [..]string;
	args.allocator = temp;
	s := as_string;
	while s.count {
		if s[0] == #char " " {
			s = advance(s, 1);
			continue;
		}
		idx := find_index_from_left(s, #char " ");
		if idx < 0
			idx = s.count;
		array_add(*args, string.{ data = s.data, count = idx });
		s = advance(s, idx);
	}
	if args.count == 0
		return;
	// exec commands should be part of Exec...
	for context.edit.exec_commands {
		if it.name == args[0] {
			res := it.proc(advance(args, 1));
			if res.status != .OK {
				edit_alert("Command '%' failed: %\n", args[0], res.error_message);
			}
			return;
		}
	}
	edit_alert("Command '%' not found", args[0]);
}

add_exec :: (name: string, $_proc: $T) {
	proc := #ifx type_of(_proc) == Exec_Command.Proc then _proc else make_exec_proc(_proc);
	array_add(*context.edit.exec_commands, .{
		name = name,
		proc = proc,
	});
}

// 
// lots of cut n pasting..
//

make_exec_proc :: ($proc: (_: $T) -> bool, $default_arg: T) -> Exec_Command.Proc {
	inner_proc :: (args: []string) -> Exec_Result {
		if args.count > 1 {
			return .{
				status = .ERROR,
				error_message = tprint("Argument count mismatch (% -> %-%)", args.count, 0, 1)
			};
		}
		arg0: T = ---;
		if args.count >= 1
			arg0 = _convert_arg(0, args[0], T);
		else
			arg0 = default_arg;
		ok := proc(arg0);
		if !ok {
			return .{
				status = .ERROR,
				error_message = "Something went wrong!",
			};
		} 
		return .{};
	}
	return inner_proc;
}

make_exec_proc :: ($proc: (_: $T) -> bool) -> Exec_Command.Proc {
	inner_proc :: (args: []string) -> Exec_Result {
		if args.count != 1 {
			return .{
				status = .ERROR,
				error_message = tprint("Argument count mismatch (% -> %)", args.count, 1)
			};
		}
		arg0 := _convert_arg(0, args[0], T);
		ok := proc(arg0);
		if !ok {
			return .{
				status = .ERROR,
				error_message = "Something went wrong!",
			};
		} 
		return .{};
	}
	return inner_proc;
}

make_exec_proc :: ($proc: (_: $T0, _: $T1) -> bool) -> Exec_Command.Proc {
	inner_proc :: (args: []string) -> Exec_Result {
		if args.count != 2 {
			return .{
				status = .ERROR,
				error_message = tprint("Argument count mismatch (% -> %)", args.count, 2)
			};
		}
		arg0 := _convert_arg(0, args[0], T0);
		arg1 := _convert_arg(1, args[1], T1);
		ok := proc(arg0, arg1);
		if !ok {
			return .{
				status = .ERROR,
				error_message = "Something went wrong!",
			};
		} 
		return .{};
	}
	return inner_proc;
}

make_exec_proc :: ($proc: () -> bool) -> Exec_Command.Proc {
	inner_proc :: (args: []string) -> Exec_Result {
		if args.count != 0 {
			return .{
				status = .ERROR,
				error_message = tprint("Argument count mismatch (% -> %)", args.count, 0)
			};
		}
		ok := proc();
		if !ok {
			return .{
				status = .ERROR,
				error_message = "Something went wrong!",
			};
		} 
		return .{};
	}
	return inner_proc;
}

// when rerunning the search, something leaks !!! not when creating buffers !!
make_fzf_window :: ($get_result: #type (*Fzf_Result, string, *void) -> (), user_data: *void = null, start_search := "") -> *Window {
	Fzf_State :: struct {
		// 1 is list of matches
		// 2 is search being typed
		match_buf: *Buffer;
		input_buf: *Buffer;
		match_win: *Window;
		input_win: *Window; 
		description_buf: *Buffer;
		description_win: *Window;
		preview_buf: *Buffer;
		preview_win: *Window;
		parent: *Window;
		using,only(items, search) res: Fzf_Result;
		user_data: *void;
		search_query: string;
	}
	maybe_update_state :: (state: *Fzf_State, force := false) {
		search := state.input_buf.lines[0].as_string;
		should_remake_lines := false;
		if search != state.search_query || force {
			should_remake_lines = true;
			if state.res.release // this is only true when force == true
				state.res.release(*state.res);
			Initialize(*state.res);
			get_result(*state.res, search, state.user_data);
			state.search_query = copy_string(search,, allocator = allocator_of(*state.res));
			edit_alert("Fr '%': %", state.search_query, state.res.ok);
		} else {
			count := state.res.items.count;
			if state.res.poll {
				state.res.poll(*state.res);
			}
			should_remake_lines = state.res.items.count != count; 
		}
		if should_remake_lines {
			time_this("Remake lines");
			erase_lines(state.description_win, 0, 1);
			_write_normal_string(state.description_win, .{0, 0}, tprint(" Total: %", state.items.count));
			{
				MAX_ALIGN_X :: 40;
				STEP_ALIGN_X :: 10;
				WHITESPACE :: #run -> string {
					arr: [..]u8;
					for 1..MAX_ALIGN_X {
						array_add(*arr, " ");
					}
					return cast(string)arr;
				}
				new_lines: [..]string;
				new_lines.allocator = temp;
				for * state.items {
					if it.line.count && peek(it.line) == #char "\n"
						it.line.count -= 1;
					it.line_prefix = sprint("%:% ", it.filename, it.line_number,, allocator=allocator_of(*state.res));
					#if 0 {
						if it.line_prefix.count < MAX_ALIGN_X {
							prefix_count := (STEP_ALIGN_X - it.line_prefix.count % STEP_ALIGN_X) % STEP_ALIGN_X;
							it.filename_start = prefix_count;
							it.line_prefix = sprint("%0%0", string.{ data = WHITESPACE.data, count = prefix_count }, it.line_prefix,, allocator=allocator_of(*state.res));
						}
					}
					array_add(*new_lines, tprint("%0%0", it.line_prefix, it.line));
				}
				if !state.items.count
					array_add(*new_lines, "");
				replace_buffer_lines_without_caps(state.match_win, new_lines);
			}
			if force
				move_cursor(state.match_win, .{0, state.res.start_line});
		}
		if state.match_win.cursor.y < state.res.items.count {
			item := state.res.items[state.match_win.cursor.y];
			if context.buffer_window == state.match_win || context.buffer_window == state.input_win {
				buf := state.res.get_buffer(item);
				if buf {
					change_buffer(state.preview_win, buf);
					move_cursor(state.preview_win, .{0, item.line_number});
					set_scroll(state.preview_win, item.line_number - 2);
				}
			}
		}
	}
	state := New(Fzf_State);
	state.user_data = user_data;
	using,except(user_data) state;
	{
		// assume none of this fails?
		match_buf = create_custom_buffer();
		match_buf.caps |= .MODE_COMMAND;
		match_buf.caps |= .MOVE_Y;
		match_buf.flags |= .NO_SEARCH;
		input_buf = create_custom_buffer();
		input_buf.flags |= .NO_SEARCH;
		input_buf.caps |= .MODE_ALL | .INSERT_CHARS | .ERASE_CHARS | .MOVE_X;
		description_buf = create_custom_buffer();
		description_buf.caps |= .ALL; // whatever lol
		preview_buf = create_custom_buffer();
		preview_buf.caps |= .ALL; // whatever lol
		// They won't get checked for destruction until any window they belong to gets destroyed.
		// That should be the intended behaviour.
		parent = create_container_window(null, mode = .VERTICAL, flags = .TEMP_FLOATING, is_hidden = true);
		search_parent := create_container_window(parent, mode = .HORIZONTAL);
		add_flags(search_parent, .BORDER);
		preview_win = create_buffer_window(parent, preview_buf, flags = .BUFFER_LINE_NO, select = false);
		preview_buf.user_title = "Preview";
		add_flags(preview_win, .BORDER);
		match_win = create_buffer_window(search_parent, match_buf, flags = .BUFFER_LINE_NO, select = false);
		match_buf.user_title = "Matches";
		description_win = create_buffer_window(search_parent, description_buf);
		description_buf.user_title = "Description";
		input_win = create_buffer_window(search_parent, input_buf, select = false);
		input_buf.user_title = "Input";
		update_container_item(input_win, .{ fixed_size = 1 });
		update_container_item(description_win, .{ fixed_size = 1 });
		// Not sure if i need all of these
		parent.user_data = state;
		match_win.user_data = state;
		input_win.user_data = state;
		match_buf.user_data = state;
		input_buf.user_data = state;
	}
	parent.on_destroy = (win: *Window) {
		state := win.user_data.(*Fzf_State);
		if state.res.release
			state.res.release(*state.res);
		edit_alert("release...");
		free(state);
	};
	input_win.map_window_for_motion = (win: *Window, motion: *Motion) -> *Window {
		log("map motion?");
		if motion.flags & (.Y_ONLY | .SCROLL_ONLY) {
			state := win.user_data.(*Fzf_State);
			return state.match_win;
		}
		return win;
	};
	match_win.before_draw = (win: *Window) {
		state := win.user_data.(*Fzf_State);
		maybe_update_state(state);
	}
	// modifiers directly affect the window, not the buffer. is that what i want?
	match_win.apply_mods = (win: *Window, lines: []*Line) {
		state := win.user_data.(*Fzf_State);
		for lines {
			y := it - win.lines.data;
		//for y: win.scroll..min(win.lines.count, win.scroll+win.size.y)-1 {
			if y >= state.res.items.count
				break;
			item := state.res.items[y];
			prefix_count := item.line_prefix.count;
			if item.flags & .SYNTAX {
				if it.dirty_flags & .USER1 && ends_with(item.filename, ".jai") {
					syntax := get_syntax_for_filename(item.filename);
					apply_syntax_mods(it, syntax, first_x = prefix_count);
					it.user_mods = it.mods;
					it.dirty_flags &= ~.USER1;
				}
			}
			if win.cursor.y == y {
				for * it.user_mods {
					//it.fg = 1;
					it.bg = 4;
					if it.fg == it.bg {
						it.fg = 7;
					}
					//it.attributes |= A_STANDOUT;
				}
			}
			for x: item.filename_start..item.filename_start+item.filename.count-1 {
				if x >= Line.user_mods.count
					break;
				if win.cursor.y != y {
					it.user_mods[x].fg = 5;
				} else {
					it.user_mods[x].fg = 2;
				}
			}
			for x: item.filename_start+item.filename.count..item.filename_start+item.filename.count+tprint("%", item.line_number).count {
				if x >= Line.user_mods.count
					break;
				if win.cursor.y != y {
					it.user_mods[x].fg = 1;
				} else {
					it.user_mods[x].fg = 1;
				}
			}
			for x: item.start+prefix_count..item.end+prefix_count {
				if x >= it.count
					continue;
				if x >= Line.user_mods.count
					continue;
				// these create a yellow color
				it.user_mods[x].attributes |= A_BOLD;
				it.user_mods[x].fg = 0; 
			}
		}
	};
	Select_Mode :: enum {
		OPEN;
		TAB;
		VERTICAL;
		FLOAT;
	}
	select_proc :: (in: Command_In, select_mode: Select_Mode) -> Command_Result {
		win := context.buffer_window;
		state := win.user_data.(*Fzf_State);
		if state.items.count == 0 {
			return .{ status = .ERROR };
		}
		item := state.items[state.match_win.cursor.y];
		assert(state.res.get_buffer != null);
		buf := state.res.get_buffer(item);
		if buf == null {
			return command_error("Null buffer...");
		}
		hold(buf);
		defer release(buf);
		//
		new_win: *Window = ---;
		if select_mode == .OPEN {
			new_win = get_window(.BUFFER, not_floating = true, not_special = true);
			change_buffer(new_win, buf);
		} else if select_mode == .FLOAT {
			new_win = create_buffer_window(null, buf, flags = .TEMP_FLOATING, is_hidden = true);
			set_floating(new_win);
		} else { // .TAB or .VERTICAL
			parent := get_window(.CONTAINER, not_floating = true);
			need_container: Window.Container_Mode = ifx select_mode == .TAB then .TABBED else .VERTICAL;
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
				return .{
					status = .ERROR,
					error_message = "Can't create container",
				};
			}
			new_win = create_buffer_window(parent, buf);
		}
		destroy_window(state.parent, force = true);
		//
		edit_alert("new_win: %\n", new_win.*);
		move_cursor(new_win, .{ 0, item.line_number }, jump = true);
		set_scroll(new_win, item.line_number - new_win.size.y / 2);
		change_edit_mode(.COMMAND);
		select_window(new_win);
		return .{};
	}
	add_command(*input_win.commands, 
		keybind = "\n",
		mode = .COMMAND | .INSERT,
		proc = #bake_arguments select_proc(select_mode = .OPEN),
	);
	add_command(*input_win.commands, 
		keybind = .[ 20 ], // ctrl + t
		mode = .COMMAND | .INSERT,
		proc = #bake_arguments select_proc(select_mode = .TAB),
	);
	add_command(*input_win.commands,
		keybind = .[ 22 ], // ctrl + v
		mode = .COMMAND | .INSERT,
		proc = #bake_arguments select_proc(select_mode = .VERTICAL),
	);
	add_command(*input_win.commands,
		keybind = .[ 6 ], // ctrl + f (not sure...)
		mode = .COMMAND | .INSERT,
		proc = #bake_arguments select_proc(select_mode = .FLOAT),
	);
	add_command(*input_win.commands, 
		keybind = .[ KEY_ESCAPE ],
		mode = .COMMAND | .INSERT,
		proc = (_: Command_In) -> Command_Result {
			state := context.buffer_window.user_data.(*Fzf_State);
			destroy_window(state.parent, force = true);
			change_edit_mode(.COMMAND);
			return .{};
		}
	);
	set_floating(parent, .{
		lx = .{ .BEGIN, 10 },
		rx = .{ .END, -10 },
		ly = .{ .BEGIN, 5 },
		ry = .{ .END, -5 },
	}, border = false);
	change_edit_mode(.INSERT);
	_write_normal_string(state.input_win, {0, 0}, start_search);
	maybe_update_state(state, force = true);
	select_window(input_win);
	// start search
	return parent;
}

add_all_execs :: () {
	add_exec("force_quit", () -> bool {
		editool_quit(force = true);
		return true;
	});
	add_exec("message", (s: string) -> bool {
		win := context.buffer_window;
		win.user_message = s;
		return true;
	});
	add_exec("nest", #run make_exec_proc(() -> bool {
		win := context.buffer_window;
		if win.parent == null
			return false;
		container := nest_window(win.parent, win);
		return container != null;
	}));
	add_exec("unnest", #run make_exec_proc(() -> bool {
		win := context.buffer_window;
		found := false;
		while win.parent != null && win.parent.parent != null && win.parent.children.count == 1 {
			p := win.parent;
			change_parent(win, win.parent.parent);
			destroy_window(p);
			found = true;
		}
		return found;
	}));
	add_exec("parent", #run make_exec_proc((count: int = 0) -> bool {
		win := context.container_window;
		if !win
			return false;
		if !win.parent
			return false;
		select_window(win.parent);
		return true;
	}, 0));
	add_exec("split", #run make_exec_proc((name: string) -> bool {
		parent := context.container_window;
		if !parent
			return false;
		buf := context.buffer_window.buffer;
		if name {
			buf = get_path_buffer(name);
		}
		if !buf
			return false;
		win := create_buffer_window(parent, buf);
		select_window(win);
		return true;
	}, ""));
	add_exec("mode", (mode: Window.Container_Mode) -> bool {
		win := get_selected_window_of_kind(.CONTAINER);
		if !win
			return false;
		change_container_mode(win, mode);
		return true;
	});
	add_exec("open", (filename: string) -> bool {
		buf := get_path_buffer(filename); // doesn't fail?
		if !buf
			return false;
		change_buffer(context.buffer_window, buf);
		return true;
	});
	// default argument is true here
	add_exec("caps", (caps: Buffer.Caps, add: bool) -> bool {
		win := get_selected_window_of_kind(.BUFFER);
		if !win
			return false;
		buf := win.buffer;
		if add
			buf.caps |= caps;
		else
			buf.caps &= ~caps;
		return true;
	});
	add_exec("c", () -> bool {
		destroy_window(context.buffer_window); // if it can't destroy, it will notify later?
		return true;
	});
	add_exec("close", () -> bool {
		destroy_window(context.buffer_window); // if it can't destroy, it will notify later?
		return true;
	});
	add_exec("force_close", () -> bool {
		destroy_window(context.buffer_window, force = true); // if it can't destroy, it will notify later?
		return true;
	});
	_save :: () -> bool {
		using win := context.buffer_window;
		ok, msg := save_buffer(buffer);
		if !ok
			edit_warn(msg);
		return ok;
	}
	_save_all :: () -> bool {
		count := 0;
		ok := true;
		for context.edit.buffers {
			if it.kind != .FILE
				continue; // ignore directory buffers
			if !is_dirty(it)
				continue;
			if it.file_flags & (.NO_FILE | .READ_ONLY)
				continue;
			count += 1;
			here_ok, msg := save_buffer(it);
			if !here_ok {
				ok = false;
				edit_warn("Failed to save '%': %", it.path, msg);
			}
		}
		edit_alert("Saved (%) % buffers", ok, count);
		return ok;
	}
	add_exec("save", _save);
	add_exec("s", _save);
	add_exec("save_all", _save_all);
	add_exec("sa", _save_all);
	add_exec("size_fixed", (v: int) -> bool {
		win := get_window(.NONE);
		item := Container_Item.{ fixed_size = v };
		update_container_item(win, item);
		return true;
	});
	add_exec("size_weighted", (v: float) -> bool {
		win := get_window(.NONE);
		item := Container_Item.{ weighted_size = v };
		update_container_item(win, item);
		return true;
	});
	add_exec("fr", #run make_exec_proc((start: string) -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			do_rg(res, s, ".");
		}, start_search = start);
		return win != null;
	}, ""));
	add_exec("fs", #run make_exec_proc(() -> bool {
		if context.buffer_window.buffer.kind != .FILE
			return false;
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			buf := data.(*Buffer);
			do_rg(res, s, buf.path);
		}, context.buffer_window.buffer, start_search = context.search.search_string);
		return win != null;
	}));
	add_exec("ff", #run make_exec_proc((start: string) -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			edit_alert("do fd '%'", s);
			do_fd(res, s);
		}, start_search = start);
		return win != null;
	}, ""));
	add_exec("fb", #run make_exec_proc((start: string) -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			edit_alert("do fb '%'", s);
			do_fzf_buffers(res, s);
		}, start_search = start);
		return win != null;
	}, ""));
	add_exec("fj", #run make_exec_proc((start: string) -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			window_id := cast(WinId)data;
			win := find_window(window_id);
			if !win
				return;
			if win {
				edit_alert("do fj '%'", s);
				do_fzf_jumps(win, res, s);
			}
		}, cast(*void)context.buffer_window.id, start_search = start);
		return win != null;
	}, ""));
	add_exec("search", () -> bool {
		buf := context.search.buffer;
		win := create_buffer_window(null, buf, flags = .TEMP_FLOATING | .BUFFER_LINE_NO | .BORDER, is_hidden = true, select = false);
		ok := set_floating(win);
		if ok 
			select_window(win);
		return ok;
	});
	add_exec("norm", (path: string) -> bool {
		arr := normalize_path(path,, allocator=temp);
		edit_alert("normalized: %", arr);
		return true;
	});
	add_exec("colors", () -> bool {
		#if 1 {
			alphabet :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
		} else {
			alphabet :: #run -> string {
				s: [64]u8;
				for * s
					it.* = #char " ";
				return cast(string)s;
			}
		}
		#assert alphabet.count == 64;
		#assert COLOR_BG_LAST < alphabet.count;
		#assert COLOR_FG_LAST < alphabet.count;
		buf := create_custom_buffer();
		buf.caps = .ALL;
		win := create_buffer_window(null, buf, flags = .TEMP_FLOATING, is_hidden = true);
		add_flags(win, .BUFFER_LINE_NO | .BUFFER_STATUS_LINE);
		for y: 0..63 {
			_write_normal_string(win, .{0, y}, alphabet);
			split_line(win, .{64, y});
		}
		move_cursor(win, .{0, 0});
		set_floating(win);
		win.floating_position.ly.value -= 10;
		win.floating_position.ry.value += 10;
		refresh_window_size(win);
		win.apply_mods = (win: *Window, lines: []*Line) {
			for lines {
				y := it - win.lines.data;
				for x: 0..it.count-1 {
					mod := *it.user_mods[x];
					mod.fg = xx ((x % (COLOR_FG_COUNT)) - 1);
					mod.bg = xx ((y % (COLOR_BG_COUNT)) - 1);
					fg1, bg2: s16;
					p := pair_content(xx color_fg_bg(mod.fg, mod.bg), *fg1, *bg2);
					//log("pair % content is % % (% %)", color_fg_bg(mod.fg, mod.bg), fg1, bg2, mod.fg, mod.bg);
					mod.attributes = 0;
					if y >= COLOR_BG_COUNT {
						//mod.fg = xx ((y % (COLOR_FG_COUNT)) - 1);
						//mod.bg = xx ((x % (COLOR_BG_COUNT)) - 1);
						//mod.attributes |= A_STANDOUT;
					}
				}
			}
		}
		return true;
	});
	add_exec("win_flags", (flags: Window.Flags, add: bool) -> bool {
		if add {
			add_flags(context.buffer_window, flags);
		} else {
			remove_flags(context.buffer_window, flags);
		}
		return true;
	});
	add_exec("checkpoint", () -> bool {
		checkpoint := create_checkpoint(context.buffer_window);
		return checkpoint != CHECKPOINT_NULL;
	});
	add_exec("checkpoint_revert", () -> bool {
		if context.buffer_window.buffer.active_checkpoint != CHECKPOINT_NULL
			restore_checkpoint(context.buffer_window, context.buffer_window.buffer.active_checkpoint);
		return true;
	});
	add_exec("echo", (s: string) -> bool {
		edit_alert("%", s);
		return true;
	});
	_quit :: () -> bool {
		return editool_quit();
	}
	add_exec("clip_path", () -> bool {
		path := context.buffer_window.buffer.path;
		edit_set_os_clipboard(path);
		edit_alert("Clip: '%'", path);
		return true;
	});
	add_exec("cd", (s: string) -> bool {
		path := normalize_path(s);
		ok := set_working_directory(path);
		return ok;
	});
	add_exec("pwd", () -> bool {
		dir := get_working_directory();
		edit_alert("pwd: %", dir);
		return true;
	});
	add_exec("refresh", () -> bool {
		ok, msg := refresh_buffer(context.buffer_window);
		if !ok
			edit_alert("Failed refresh: %", msg);
		return ok;
	});
	add_exec("quit", _quit);
	add_exec("q", _quit);
	add_exec("syntax", (filetype: string) -> bool {
		syntax := get_syntax_for_filetype(filetype);
		change_syntax(context.buffer_window.buffer, syntax);
		return true;
	});
}

#scope_file

_convert_arg :: inline (idx: int, arg: string, $T: Type) -> T #expand {
	#if T == string {
		return arg;
	} else #if T == int {
		val, ok, remainder := to_integer(arg);
		if remainder
			ok = false;
		if !ok {
			`return .{
				status = .ERROR,
				error_message = tprint("Cannot convert argument % '%' to %", idx+1, arg, T),
			};
		}
		return val;
	} else #if T == float {
		val, ok, remainder := string_to_float(arg);
		if remainder
			ok = false;
		if !ok {
			`return .{
				status = .ERROR,
				error_message = tprint("Cannot convert argument % '%' to %", idx+1, arg, T),
			};
		}
		return val;
	} else #if T == bool {
		if arg == "true"
			return true;
		if arg == "false"
			return false;
		`return .{
			status = .ERROR,
			error_message = tprint("Cannot convert argument % '%' to %", idx+1, arg, T),
		};
	} else #if type_info(T).type == .ENUM {
		info := type_info(T);
		for info.names {
			if it == "NONE" // this is kinda hardcoded...
				continue;
			if equal_nocase(arg, it) {
				return xx info.values[it_index];
			}
		}
		`return .{
			status = .ERROR,
			error_message = tprint("Cannot convert argument % '%' to enum %", idx+1, arg, T),
		};
	} else {
		#assert false;
	}
}