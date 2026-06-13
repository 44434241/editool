


Exec :: struct {
	chars: [..]u8;
	#overlay(chars) as_string: string;
	window: *Window;
	buffer: *Buffer;
	last_win_id: WinId;
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

get_exec_info_for_status_bar :: () -> string {
	using context.exec;
	str := buffer.lines[0].as_string;
	if !str
		return "";
	return tprint("EXEC :%", str);
}

start_exec :: () {
	using context.exec;
	last_win_id = context.buffer_window.id;
	_clear_exec();
	select_window(window);
	change_edit_mode(.INSERT);
}

execute_exec :: () {
	using context.exec;
	win := find_window(last_win_id);
	if win
		select_window(win);
	else
		select_normal_window();
	s := copy_string(window.lines[0].as_string,, allocator=temp);
	_clear_exec();
	change_edit_mode(.COMMAND);
	eval_exec(s);
}

stop_exec :: () {
	using context.exec;
	win := find_window(last_win_id);
	if win
		select_window(win);
	else
		select_normal_window();
	_clear_exec();
}

_clear_exec :: () {
	using context.exec;
	delete_chars(window, .{0, 0}, window.lines[0].count);
}


editool_exec_init :: () {
	using context.exec;
	buffer = create_custom_buffer();
	buffer.flags |= .NO_SEARCH;
	buffer.caps |= .MODE_INSERT | .MODE_COMMAND;
	buffer.caps |= .INSERT_CHARS | .DELETE_CHARS;
	buffer.caps |= .MOVE;
	array_add(*buffer.commands, .{
		keybind = to_keybind("\n"),
		proc = wrap_command(execute_exec),
	});
	array_add(*buffer.commands, .{
		keybind = to_keybind(.[ KEY_ESCAPE ]),
		proc = wrap_command(stop_exec),
	});
	array_add(*buffer.insert_commands, .{
		keybind = to_keybind("\n"),
		proc = wrap_command(execute_exec),
	});
	array_add(*buffer.insert_commands, .{
		keybind = to_keybind(.[ KEY_ESCAPE ]),
		proc = wrap_command(stop_exec),
	});
	window = create_buffer_window(context.edit.second_root, buffer,
			select = false, is_hidden = false);
	window.user_title = "EXEC";
}

exit_exec_mode :: () {
	using context.edit.exec;
	array_reset(*chars);
}

eval_exec :: (_s: string) {
	args: [..]string;
	args.allocator = temp;
	s := _s;
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

make_fzf_window :: ($get_result: #type (*Fzf_Result, string, *void) -> (), user_data: *void = null, start_search := "") -> *Window {
	Fzf_State :: struct {
		buf1: *Buffer;
		buf2: *Buffer;
		win1: *Window;
		win2: *Window;
		description_buf: *Buffer;
		description_win: *Window;
		preview_buf: *Buffer;
		preview_win: *Window;
		parent: *Window;
		using,only(items, search) res: Fzf_Result;
		user_data: *void;
	}
	maybe_update_state :: (state: *Fzf_State, force := false) {
		search := state.buf2.lines[0].as_string;
		should_remake_lines := false;
		if search != state.search || force {
			edit_alert("remake allocator is %", context.allocator);
			should_remake_lines = true;
			if state.res.release // this is only true when force == true
				state.res.release(*state.res);
			Initialize(*state.res);
			get_result(*state.res, search, state.user_data);
			edit_alert("remake allocator is %", context.allocator);
			assert(state.res.search == search);
			edit_alert("Fr '%': %", state.search, state.res.ok);
		} else {
			count := state.res.items.count;
			if state.res.poll {
				state.res.poll(*state.res);
			}
			should_remake_lines = state.res.items.count != count; 
		}
		if should_remake_lines {
			delete_lines(state.description_win, 0, 1);
			_write_normal_string(state.description_win, .{0, 0}, tprint(" Total: %", state.items.count));
			{
				new_lines: [..]string;
				new_lines.allocator = temp;
				for * state.items {
					if it.line.count && peek(it.line) == #char "\n"
						it.line.count -= 1;
					array_add(*new_lines, tprint("%:%: %", it.filename, it.line_number, it.line));
				}
				if !state.items.count
					array_add(*new_lines, "");
				replace_buffer_lines_without_caps(state.win1, new_lines);
			}
		}
		if state.win1.cursor.y < state.res.items.count {
			item := state.res.items[state.win1.cursor.y];
			if item.filename && context.buffer_window != state.preview_win {
				buf := get_file_buffer(item.filename, .TEMP);//, .READ_ONLY);
				change_buffer(state.preview_win, buf);
				move_cursor(state.preview_win, .{0, item.line_number});
				set_scroll(state.preview_win, item.line_number - 2);
			}
		}
	}
	state := New(Fzf_State);
	state.user_data = user_data;
	using,except(user_data) state;
	{
		// assume none of this fails?
		buf1 = create_custom_buffer();
		buf1.caps |= .MODE_COMMAND;
		buf1.caps |= .MOVE_Y;
		buf1.flags |= .NO_SEARCH;
		buf2 = create_custom_buffer();
		buf2.flags |= .NO_SEARCH;
		buf2.caps |= .MODE_ALL | .INSERT_CHARS | .ERASE_CHARS | .MOVE_X;
		description_buf = create_custom_buffer();
		description_buf.caps |= .ALL; // whatever lol
		preview_buf = create_custom_buffer();
		preview_buf.caps |= .ALL; // whatever lol
		// They won't get checked for destruction until any window they belong to gets destroyed.
		// That should be the intended behaviour.
		buf1.flags |= .TEMP;
		buf2.flags |= .TEMP;
		description_buf.flags |= .TEMP;
		preview_buf.flags |= .TEMP;
		parent = create_container_window(null, mode = .VERTICAL, flags = .TEMP_FLOATING, is_hidden = true);
		search_parent := create_container_window(parent, mode = .HORIZONTAL);
		add_flags(search_parent, .BORDER);
		preview_win = create_buffer_window(parent, preview_buf, flags = .BUFFER_LINE_NO, select = false);
		add_flags(preview_win, .BORDER);
		win1 = create_buffer_window(search_parent, buf1, flags = .BUFFER_LINE_NO, select = false);
		description_win = create_buffer_window(search_parent, description_buf);
		win2 = create_buffer_window(search_parent, buf2, select = false);
		update_container_item(win2, .{ fixed_size = 1 });
		update_container_item(description_win, .{ fixed_size = 1 });
		// Not sure if i need all of these
		parent.user_data = state;
		win1.user_data = state;
		win2.user_data = state;
		buf1.user_data = state;
		buf2.user_data = state;
	}
	// start search
	_write_normal_string(state.win2, {0, 0}, start_search);
	parent.on_destroy = (win: *Window) {
		state := win.user_data.(*Fzf_State);
		state.res.release(*state.res);
		edit_alert("release...");
		free(state);
	};
	win2.map_window_for_motion = (win: *Window, motion: *Motion) -> *Window {
		log("map motion?");
		if motion.flags & (.Y_ONLY | .SCROLL_ONLY) {
			state := win.user_data.(*Fzf_State);
			return state.win1;
		}
		return win;
	};
	win1.before_draw = (win: *Window) {
		state := win.user_data.(*Fzf_State);
		maybe_update_state(state);
	}
	// modifiers directly affect the window, not the buffer. is that what i want?
	win1.apply_mods = (win: *Window, lines: []Line) {
		for * win.lines[win.cursor.y].user_mods {
			it.bg_color = 1;
			it.fg_color = 4;
			it.attributes |= A_STANDOUT;
		}
	};
	Select_Mode :: enum {
		OPEN;
		TAB;
		VERTICAL;
	}
	select_proc :: (in: Command_In, select_mode: Select_Mode) -> Command_Result {
		win := context.buffer_window;
		state := win.user_data.(*Fzf_State);
		if state.items.count == 0 {
			return .{ status = .ERROR };
		}
		item := state.items[state.win1.cursor.y];
		buf := get_file_buffer(item.filename);
		//
		new_win: *Window = ---;
		if select_mode == .OPEN {
			new_win = get_window(.BUFFER, not_floating = true, not_special = true);
			change_buffer(new_win, buf);
		} else { // .TAB
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
	enter_command := Command.{
		keybind = to_keybind("\n"),
		proc = #bake_arguments select_proc(select_mode = .OPEN),
	};
	split_enter_command := Command.{
		keybind = to_keybind(.[ 20 ]), // ctrl + t
		proc = #bake_arguments select_proc(select_mode = .TAB),
	};
	vert_enter_command := Command.{
		keybind = to_keybind(.[ 22 ]), // ctrl + v
		proc = #bake_arguments select_proc(select_mode = .VERTICAL),
	};
	escape_command := Command.{
		keybind = to_keybind(.[ KEY_ESCAPE ]),
		proc = (_: Command_In) -> Command_Result {
			state := context.buffer_window.user_data.(*Fzf_State);
			destroy_window(state.parent, force = true);
			change_edit_mode(.COMMAND);
			return .{};
		}
	};
	//
	array_add(*buf2.commands, enter_command);
	array_add(*buf2.commands, split_enter_command);
	array_add(*buf2.commands, vert_enter_command);
	array_add(*buf2.insert_commands, enter_command);
	array_add(*buf2.insert_commands, split_enter_command);
	array_add(*buf2.insert_commands, vert_enter_command);
	//
	array_add(*buf2.insert_commands, escape_command);
	array_add(*buf2.commands, escape_command);
	set_floating(parent, .{
		lx = .{ .BEGIN, 10 },
		rx = .{ .END, -10 },
		ly = .{ .BEGIN, 5 },
		ry = .{ .END, -5 },
	}, border = false);
	maybe_update_state(state, force = true);
	select_window(win2);
	change_edit_mode(.INSERT);
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
	add_exec("nest", #run make_exec_proc((count: int = 0) -> bool {
		win := context.buffer_window;
		if win.parent == null
			return false;
		container := nest_window(win.parent, win);
		return container != null;
	}, 0));
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
			buf = get_file_buffer(name);
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
		buf := get_file_buffer(filename); // doesn't fail?
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
	add_exec("close", () -> bool {
		destroy_window(context.buffer_window); // if it can't destroy, it will notify later?
		return true;
	});
	_save_file :: () -> bool {
		using win := context.buffer_window;
		if buffer.kind != .FILE {
			return false;
		}
		if buffer.file_flags & (.NO_FILE | .READ_ONLY) {
			return false;
		}
		s := buffer_as_string_for_saving(buffer,, allocator=temp);
		edit_alert("Writing % bytes to '%'", s.count, buffer.filename);
		ok := write_entire_file(buffer.filename, s);
		if ok
			clear_dirty(buffer);
		return ok;
	}
	add_exec("save", _save_file);
	add_exec("s", _save_file);
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
	add_exec("fr", #run make_exec_proc(() -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			do_rg(res, s, ".", "/home/user/jai/latest");
		});
		return win != null;
	}));
	add_exec("fs", #run make_exec_proc(() -> bool {
		if context.buffer_window.buffer.kind != .FILE
			return false;
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			buf := data.(*Buffer);
			do_rg(res, s, buf.filename);
		}, context.buffer_window.buffer);
		return win != null;
	}));
	add_exec("ff", #run make_exec_proc(() -> bool {
		win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
			do_fd(res, s);
		});
		return win != null;
	}));
	add_exec("search", () -> bool {
		buf := context.search.buffer;
		win := create_buffer_window(null, buf, flags = .TEMP_FLOATING | .BUFFER_LINE_NO | .BORDER, is_hidden = true, select = false);
		ok := set_floating(win);
		if ok 
			select_window(win);
		return ok;
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