
// it's not actually fuzzy lol

Fzf_Item :: struct {
	filename: string; // file to open when selected
	line_number: int; // file line to go to
	line: string; // line as text
	start: int = -1;
	end: int = -1;
	// modified by window thing
	line_prefix: string;
	filename_start: int = 0; // where in line prefix filename starts
	user_data: *void;
}

Fzf_Result :: struct {
	pool: Pool; // allocate stuff here
	items: [..]Fzf_Item;
	ok: bool;
	search: string;
	// poll might add to the end of items, but it will never remove anything !!
	poll: #type(*Fzf_Result) -> (); 
	release: #type(*Fzf_Result) -> (); 
	thread_group: Thread_Group;
	get_buffer: #type (Fzf_Item) -> *Buffer;
}

allocator_of :: (res: *Fzf_Result) -> Allocator {
	return allocator_of(*res.pool);
}

allocator_of :: (pool: *Pool) -> Allocator {
	return .{pool_allocator_proc, pool};
}

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
	res.release = (res: *Fzf_Result) {
		release(*res.pool);
	};
	res.get_buffer = _default_get_buffer;
	res.search = copy_string(search);
	res.items.allocator = context.allocator;
	_, output := run_command("fd", "-p", "--no-ignore", "--type", "file", "--", search, dir, "/home/user/jai/latest", capture_and_return_output = true);
	for < split(output, #char "\n",, allocator=temp) {
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

do_rg :: (res: *Fzf_Result, _search: string, paths: .. string) {
	time_this("Do ripgrep");
	set_allocators(*res.pool);
	//
	ctx: #Context = context;
	push_context,defer_pop ctx;
	context.allocator = allocator_of(*res.pool);
	res.items.allocator = context.allocator;
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
	res.search = copy_string(search);
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
	_, output := run_command(.. args, capture_and_return_output = true);
	//res, output := run_command("rg", search, dir, "--json", "-m", "10", "-S", capture_and_return_output = true,, allocator=temp);
	lines := split(output, #char "\n");
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
	if lines.count >= 200 && false {
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
		init(*res.thread_group, num_threads = 5, (group: *Thread_Group, thread: *Thread, _work: *void) -> Thread_Continue_Status {
			work := _work.(*Work);
			// looks like using the temp thread allocator works..
			work.parse_ok, work.match = fson_parse_string(work.json_string, Rg_Match,, allocator=temp);
			return .CONTINUE;
		});
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
			work := New(Work);
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
			ok, match := fson_parse_string(it, Rg_Match);
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
	res.release = (res: *Fzf_Result) {
		release(*res.pool);
	};
	res.get_buffer = (item: Fzf_Item) -> *Buffer {
		id := cast(BufId)item.user_data;
		buf := find_buffer(id);
		//assert(buf != null);
		return buf;
	}
	//
	for context.edit.buffers {
		array_add(*res.items, .{
			filename = it.filename,
			line = sprint("% % %", get_title(it), it.kind, it.flags),
			user_data = cast(*void)it.id,
		});
	}
}

_default_get_buffer :: (item: Fzf_Item) -> *Buffer {
	return get_file_buffer(item.filename);
}

#scope_file 

#import "Process";
#import "jaison";
#import "Pool";
#import "Thread";