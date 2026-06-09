


Exec :: struct {
	chars: [..]u8;
	#overlay(chars) as_string: string;
	window: *Window;
	buffer: *Buffer;
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
	_clear_exec();
	select_window(window);
	change_edit_mode(.INSERT);
}

execute_exec :: () {
	using context.exec;
	s := copy_string(window.lines[0].as_string,, allocator=temp);
	_clear_exec();
	select_normal_window();
	change_edit_mode(.COMMAND);
	eval_exec(s);
}

stop_exec :: () {
	_clear_exec();
	select_normal_window();
}

_clear_exec :: () {
	using context.exec;
	delete_chars(window, .{0, 0}, window.lines[0].count);
}


editool_exec_init :: () {
	using context.exec;
	buffer = create_custom_buffer();
	buffer.flags |= .NO_SEARCH;
	line: *Line = array_add(*buffer.lines);
	buffer.caps |= .MODE_INSERT | .MODE_COMMAND;
	buffer.caps |= .INSERT_CHARS | .DELETE_CHARS;
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

add_all_execs :: () {
	add_exec("print", (s: string) -> bool {
		log("print from exec: %\n", s);
		return true;
	});
	add_exec("add", (l: int, r: int) -> bool {
		log("sum from exec is: %\n", l + r);
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
		ok := nest_window(win.parent, win);
		return ok;
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
	add_exec("split", #run make_exec_proc((count: int = 0) -> bool {
		count = max(count, 0);
		parent := get_selected_window_of_kind(.CONTAINER);
		while parent != null && count > 0 {
			parent = parent.parent;
		}
		if !parent
			return false;
		win := create_buffer_window(parent, context.buffer_window.buffer);
		select_window(win);
		return true;
	}, 0));
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
	add_exec("float", #run make_exec_proc((flag: bool) -> bool {
		ok := set_floating(context.buffer_window, flag);
		return ok;
	}, true));
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
	add_exec("something", () -> bool {
		start_search();
		return true;
	});
	add_exec("ff", #run make_exec_proc((dir: string) -> bool {
		//parent := get_selected_window_of_kind(.CONTAINER);
		//if !parent
			//return false;
		//parent: 
		buf := create_custom_buffer();
		buf.caps |= .MODE_COMMAND;
		{
			//buf.flags |= .SUPPORTS_INSERT;
			array_add(*buf.commands, .{
				name = "custom1",
				keybind = to_keybind("\n"),
				proc = (_: Command_In) -> Command_Result {
					log("yup custom command !!");
					using win := context.buffer_window;
					str := lines[cursor.y].as_string;
					buf := get_file_buffer(str);
					#if 0 {
						create_buffer_window(context.edit.root, buf);
					} else {
						destroy_window(context.buffer_window, _force = true);
						new_win := get_window(.BUFFER, not_floating = true, not_special = true);
						change_buffer(new_win, buf);
					}
					return .{};
				},
			});
			array_add(*buf.commands, .{
				name = "custom1",
				keybind = to_keybind("@"),
				proc = (_: Command_In) -> Command_Result {
					using win := context.buffer_window;
					log("string under cursors line is: '%'", lines[cursor.y].as_string);
					return .{};
				},
			});
			array_add(*buf.commands, .{
				name = "quit",
				keybind = to_keybind(.[ KEY_ESCAPE ] ),
				proc = (_: Command_In) -> Command_Result {
					using win := context.buffer_window;
					destroy_window(win, _force = true);
					return .{};
				},
			});
		}
		files := file_list(ifx dir else ".", recursive = true);
		for files {
			#if 1 {
				if !ends_with(it, ".jai")
					continue;
			}
			line: *Line = array_add(*buf.lines);
			array_adds(*line.chars, it);
		}
		win := create_buffer_window(null, buf, is_hidden = true);
		set_floating(win, true);
		return true;
	}, ""));
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
