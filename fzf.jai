
// it's not actually fuzzy lol

Fzf_Item :: struct {
	Flags :: enum_flags {
		SYNTAX;
		NONE :: 0;
	}
	flags: Flags = .SYNTAX;
	filename: string; // file to open when selected
	line_number: int; // file line to go to
	line: string; // line as text
	start: int = -1;
	end: int = -1;
	user_data: *void;
	// modified by `create_fzf_window` thing
	line_prefix: string;
	filename_start: int = 0; // where in line prefix filename starts
}

Fzf_Result :: struct {
	pool: Pool; // allocate stuff here
	items: [..]Fzf_Item;
	ok: bool;
	search: string;
	start_line: int; // when getting fzf for the first time, start at this line
	// poll might add to the end of items, but it will never remove anything !!
	poll: #type(*Fzf_Result) -> (); 
	release: #type(*Fzf_Result) -> (); 
	thread_group: Thread_Group;
	input_process: Process;
	input_process_is_done: bool;
	get_buffer: #type (Fzf_Item) -> *Buffer;
	user_data: *void;
}

allocator_of :: (res: *Fzf_Result) -> Allocator {
	return allocator_of(*res.pool);
}

allocator_of :: (pool: *Pool) -> Allocator {
	return .{pool_allocator_proc, pool};
}

// from `rg --json`
Rg_Match :: struct {
	Submatch :: struct {
		match: struct { text: string; };
		start: int;
		end: int;
	}
	type: string;
	using data: struct {
		path: struct {
			text: string;
		};
		lines: struct {
			text: string;
		};
		line_number: int;
		absolute_offset: int;
		submatches: [..]Submatch;
	};
}

do_fd :: (res: *Fzf_Result, search: string, dir: string = ".") {
	time_this("Do find");
	//
	set_allocators(*res.pool);
	ctx: #Context = context;
	push_context,defer_pop ctx;
	context.allocator = .{ pool_allocator_proc, *res.pool};
	//
	res.release = _default_release;
	res.get_buffer = _default_get_buffer;
	res.search = copy_string(search);
	res.items.allocator = context.allocator;
	args: [..]string;
	args.allocator = temp;
	array_add(*args, "fd", "--no-ignore", "--type", "file");
	if array_find(cast([]u8)search, #char "/") {
		array_add(*args, "--full-path");
	}
	array_add(*args, "--", search, dir, "/home/user/jai/latest");
	_, output := run_command(.. args, capture_and_return_output = true);
	count_slashes :: (s: string) -> int {
		ret: int = 0;
		for s
			if it == #char "/"
				ret += 1;
		return ret;
	}
	lines := split(output, #char "\n",, allocator=temp);
	quick_sort(lines, count_slashes);
	for lines {
		if !it
			continue;
		array_add(*res.items, .{
			filename = it,
			line_number = 0,
			line = "",
			start = 0,
			end = -1,
		});
	}
}

do_rg_but_in_background :: (res: *Fzf_Result, _search: string, paths: .. string) {
	// TODO: ugh.. i need to do synchronozationnnasdjn
	time_this("Do ripgrep");
	set_allocators(*res.pool);
	//
	res.items.allocator = allocator_of(res);
	//
	res.get_buffer = _default_get_buffer;
	//
	search := _search;
	extra_paths: [..]string;
	extra_paths.allocator = temp;
	if search && search[0] == #char "!" {
		search = advance(search, 1);
		array_add(*extra_paths, "/home/user/jai/latest");
	}
	//
	res.search = copy_string(search,, allocator=allocator_of(res));
	max_per_file := "15";
	if paths.count <= 1 // hacky ..
		max_per_file = "100"; // idk
	args: [..]string;
	args.allocator = temp;
	array_add(*args, "rg", "--json", "-m", max_per_file, "-S", "--", search);
	array_add(*args, .. paths);
	array_add(*args, .. extra_paths);
	if !paths
		array_add(*args, ".");
	#if 0 {
		_, output := run_command(.. args, capture_and_return_output = true,, allocator=allocator_of(res));
	} else {
		// TODO: run the process in background and read lines as needed...
		process_ok := create_process(*res.input_process, .. args, capture_and_return_output = true);
		if !process_ok {
			edit_alert("something went wrong with fr");
			return;
		}
	}
	Work :: struct {
		json_string: string;
		match: Rg_Match; // some stuff here might be allocated.. dunno
		parse_ok: bool;
	}
	{
		// *fuck it*, we always start thread group
		res.thread_group.logging = false;
		num_threads := get_number_of_processors() / 2;
		num_threads = clamp(num_threads, 1, 32);
		edit_alert("num threads: %", num_threads);
		init(*res.thread_group, num_threads = num_threads, (group: *Thread_Group, thread: *Thread, _work: *void) -> Thread_Continue_Status {
			work := _work.(*Work);
			// looks like using the temp thread allocator works..
			work.parse_ok, work.match = fson_parse_string(work.json_string, Rg_Match,, allocator=temp);
			return .CONTINUE;
		},, allocator=allocator_of(res));
	}
	maybe_add :: (res: *Fzf_Result, val: Rg_Match) {
		if val.type != "match" 
			return;
		if val.submatches.count == 0
			return;
		item := Fzf_Item.{
			filename = val.path.text,
			line_number = val.line_number - 1,
			line = val.lines.text,
			start = val.submatches[0].start,
			end = val.submatches[0].end - 1,
		};
		array_add(*res.items, item);
	}
	res.poll = (res: *Fzf_Result) {
		time_this("Poll");
		read_until_newline :: () -> string #expand {
			if res.input_process_is_done
				return "";
			log("read until newline?");
			// this doesn't buffer.. ugh
			done_with_big_reads: bool = ---;
			ret: [..]u8;
			// this is allocated in the pool !! we need to keep them for json stuff !!
			ret.allocator = allocator_of(res);
			{
				tmp: [128]u8;
				ok, count, _ := read_from_process(*res.input_process, tmp, .[]);
				log("read % %", ok, count);
				if !ok || count == 0 {
					res.input_process_is_done = true;
					return "";
				}
				done_with_big_reads = count != 128;
				array_add(*ret, .. []u8.{ data = tmp.data, count = count });
			}
			while !res.input_process_is_done && !done_with_big_reads {
				log("big read");
				BIG_READ_SIZE :: 64 * 1024; // 64 kb.. too-slow-of-a-wait is like 50 times that
				old_count := ret.count;
				array_reserve(*ret, ret.count + BIG_READ_SIZE);
				ret.count += BIG_READ_SIZE;
				ok, count, _ := read_from_process(*res.input_process, advance(ret, old_count), .[]);
				if !ok || count == 0 {
					res.input_process_is_done = true;
				}
				log("read % %", ok, count);
				if !ok {
					// There might be some case where this fails
					assert(count == 0);
				}
				//if count < cast(int)(BIG_READ_SIZE * 0.6)
					//done_with_big_reads = true;
				done_with_big_reads = count == 0;
				ret.count = old_count + count;
			}
			while !res.input_process_is_done && peek(ret) != #char "\n" {
				log("not newline");
				ch: u8;
				ok, count, _ := read_from_process(*res.input_process, []u8.{ data = *ch, count = 1 }, .[]);
				if !ok || count == 0 {
					res.input_process_is_done = true;
				}
				log("read % %", ok, count);
				if count == 0
					break;
				array_add(*ret, ch);
			}
			return cast(string)ret;
		}
		while true {
			output := read_until_newline();
			if !output
				break;
			lines := split(output, #char "\n",, allocator=temp);
			for lines {
				ok, match := fson_parse_string(it, Rg_Match,, allocator=allocator_of(res));
				if ok
					maybe_add(res, match);
			}
			break;
		}
	}
	thread_proc :: (thread: *Thread) -> s64 {
		return 0;
	}
	res.poll(res);
	return;
	/*
	if lines.count >= 200 {
		// There are a lot of lines, we use threads
		Work :: struct {
			json_string: string;
			match: Rg_Match; // some stuff here might be allocated.. dunno
			parse_ok: bool;
		}
		res.thread_group.logging = false;
		// I DON'T KNOW WHY THIS HAPPENS @@:
		// if num_threads > 6 and using pool allocator, it randomly crashes...
		// (but otherwise, this shit leaks..)
		num_threads := get_number_of_processors();
		num_threads = clamp(num_threads / 2, 1, 32);
		edit_alert("num threads: %", num_threads);
		init(*res.thread_group, num_threads = num_threads, (group: *Thread_Group, thread: *Thread, _work: *void) -> Thread_Continue_Status {
			work := _work.(*Work);
			// looks like using the temp thread allocator works..
			work.parse_ok, work.match = fson_parse_string(work.json_string, Rg_Match,, allocator=temp);
			return .CONTINUE;
		},, allocator=allocator_of(res));
		res.poll = (res: *Fzf_Result) {
			time_this("Poll");
			results := get_completed_work(*res.thread_group,, allocator=temp);
			for results {
				work := it.(*Work);
				if !work.parse_ok
					continue;
				maybe_add(res, work.match);
			}
		};
		start(*res.thread_group,, allocator=temp);
		for lines {
			work := New(Work,, allocator=allocator_of(res));
			work.* = .{ json_string = it };
			add_work(*res.thread_group, work,, allocator=temp);
			//log("MATCH %", val);
		}
		res.poll(res);
		//for 1..2 {
			//res.poll(res);
		//}
	} else {
		for lines {
			ok, match := fson_parse_string(it, Rg_Match,, allocator=allocator_of(res));
			maybe_add(res, match);
		}
	}
	*/
}

do_rg :: (res: *Fzf_Result, _search: string, paths: .. string) {
	time_this("Do ripgrep");
	set_allocators(*res.pool);
	#if 0 {
		// this still leaks.. ? maybe the problem is somwhere else?
		ctx: #Context = context;
		ctx.allocator = allocator_of(res);
		push_context,defer_pop ctx;
	}
	
	//
	res.items.allocator = allocator_of(res);
	//
	res.get_buffer = _default_get_buffer;
	//
	search := _search;
	extra_paths: [..]string;
	extra_paths.allocator = temp;
	if search && search[0] == #char "!" {
		search = advance(search, 1);
		array_add(*extra_paths, "/home/user/jai/latest");
	}
	//
	res.search = copy_string(search,, allocator=allocator_of(res));
	res.release = (res: *Fzf_Result) {
		if res.thread_group.initted {
			edit_alert("release thread group");
			// @CompilerBug looks like i need to pass allocator for shutdown...
			shutdown(*res.thread_group,, allocator=allocator_of(res));
			res.thread_group.initted = false; 
		}
		release(*res.pool);
	};
	max_per_file := "15";
	if paths.count <= 1 // hacky ..
		max_per_file = "100"; // idk
	args: [..]string;
	args.allocator = temp;
	array_add(*args, "rg", "--json", "-m", max_per_file, "-S", "--", search);
	array_add(*args, .. paths);
	array_add(*args, .. extra_paths);
	if !paths
		array_add(*args, ".");
	// error value is not checked
	_, output := run_command(.. args, capture_and_return_output = true,, allocator=allocator_of(res));
	//res, output := run_command("rg", search, dir, "--json", "-m", "10", "-S", capture_and_return_output = true,, allocator=temp);
	lines := split(output, #char "\n",, allocator=temp);
	maybe_add :: (res: *Fzf_Result, val: Rg_Match) {
		if val.type != "match" 
			return;
		if val.submatches.count == 0
			return;
		item := Fzf_Item.{
			filename = val.path.text,
			line_number = val.line_number - 1,
			line = val.lines.text,
			start = val.submatches[0].start,
			end = val.submatches[0].end - 1,
		};
		array_add(*res.items, item);
	}
	if lines.count >= 200 {
		// There are a lot of lines, we use threads
		Work :: struct {
			json_string: string;
			match: Rg_Match; // some stuff here might be allocated.. dunno
			parse_ok: bool;
		}
		res.thread_group.logging = false;
		// I DON'T KNOW WHY THIS HAPPENS @@:
		// if num_threads > 6 and using pool allocator, it randomly crashes...
		// (but otherwise, this shit leaks..)
		num_threads := get_number_of_processors();
		num_threads = clamp(num_threads / 2, 1, 32);
		edit_alert("num threads: %", num_threads);
		init(*res.thread_group, num_threads = num_threads, (group: *Thread_Group, thread: *Thread, _work: *void) -> Thread_Continue_Status {
			work := _work.(*Work);
			// looks like using the temp thread allocator works..
			work.parse_ok, work.match = fson_parse_string(work.json_string, Rg_Match,, allocator=temp);
			return .CONTINUE;
		},, allocator=allocator_of(res));
		res.poll = (res: *Fzf_Result) {
			time_this("Poll");
			results := get_completed_work(*res.thread_group,, allocator=temp);
			for results {
				work := it.(*Work);
				if !work.parse_ok
					continue;
				maybe_add(res, work.match);
			}
		};
		start(*res.thread_group,, allocator=temp);
		for lines {
			work := New(Work,, allocator=allocator_of(res));
			work.* = .{ json_string = it };
			add_work(*res.thread_group, work,, allocator=temp);
			//log("MATCH %", val);
		}
		res.poll(res);
		//for 1..2 {
			//res.poll(res);
		//}
	} else {
		for lines {
			ok, match := fson_parse_string(it, Rg_Match,, allocator=allocator_of(res));
			maybe_add(res, match);
		}
	}
}

do_fzf_buffers :: (res: *Fzf_Result, search: string) {
	time_this("Do buffers");
	//
	set_allocators(*res.pool);
	ctx: #Context = context;
	push_context,defer_pop ctx;
	context.allocator = allocator_of(*res.pool);
	res.items.allocator = allocator_of(res);
	//
	res.release = _default_release;
	res.get_buffer = (item: Fzf_Item) -> *Buffer {
		id := cast(BufId)item.user_data;
		buf := find_buffer(id);
		//assert(buf != null);
		return buf;
	}
	//
	for context.edit.buffers {
		array_add(*res.items, .{
			filename = it.path,
			line = sprint("% % %", get_title(it), it.kind, it.flags),
			user_data = cast(*void)it.id,
		});
	}
}

do_fzf_jumps :: (win: *Window, res: *Fzf_Result, search: string) {
	time_this("Do fzf_jumps");
	//
	set_allocators(*res.pool);
	res.items.allocator = allocator_of(res);
	//
	res.release = _default_release;
	res.get_buffer = _default_get_buffer;
	if !win
		return;
	res.start_line = max(0, win.cursor_mark_index);
	//
	for win.cursor_marks {
		buf := get_mark_buffer(it);
		y := it.position.y;
		array_add(*res.items, .{
			filename = it.path,
			line = ifx y < buf.lines.count then string_copy(buf.lines[y].as_string,, allocator=allocator_of(res)) else "",
			line_number = y,
		});
	}
}

#scope_file

_default_release :: (res: *Fzf_Result) {
	if res.thread_group.initted {
		edit_alert("release thread group");
		// @CompilerBug looks like i need to pass allocator for shutdown...
		shutdown(*res.thread_group,, allocator=allocator_of(res));
		res.thread_group.initted = false;
	}
	if res.input_process.pid {
		ok := kill_process(*res.input_process);
		edit_alert("kill process ok: %", ok);
	}
	release(*res.pool);
}

_default_get_buffer :: (item: Fzf_Item) -> *Buffer {
	cnt := file_length(item.filename);
	if cnt > 1024 * 1024 {
		edit_alert("Refusing to preview > 1mb file");
		return null;
	}
	return get_path_buffer(item.filename);
}

file_length :: (filename: string) -> int {
	f, ok := file_open(filename);
	if !ok
		return -1;
	len := file_length(f);
	file_close(*f);
	return len;
}

#import "Process";
#import "jaison";
#import "Pool";
#import "Thread";