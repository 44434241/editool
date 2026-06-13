
// it's not actually fuzzy lol

Fzf_Item :: struct {
	filename: string; // file to open when selected
	line_number: int; // file line to go to
	line: string; // line as text
	start: int;
	end: int;
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

do_fd :: (ret: *Fzf_Result, search: string, dir: string = ".") {
	time_this("Do find");
	//
	set_allocators(*ret.pool);
	ctx: #Context = context;
	push_context,defer_pop ctx;
	context.allocator = .{ pool_allocator_proc, *ret.pool};
	//
	ret.release = (res: *Fzf_Result) {
		release(*res.pool);
	};
	ret.search = copy_string(search);
	ret.items.allocator = context.allocator;
	_, output := run_command("fd", "-p", "--type", "file", "--", search, ".", "/home/user/jai/latest", capture_and_return_output = true);
	for < split(output, #char "\n",, allocator=temp) {
		if !it
			continue;
		array_add(*ret.items, .{
			filename = it,
			line_number = 0,
			line = "",
			start = 0,
			end = 0,
		});
	}
}

do_rg :: (ret: *Fzf_Result, search: string, paths: .. string) {
	time_this("Do ripgrep");
	//
	set_allocators(*ret.pool);
	ctx: #Context = context;
	push_context,defer_pop ctx;
	context.allocator = .{ pool_allocator_proc, *ret.pool};
	//
	ret.search = copy_string(search);
	ret.release = (res: *Fzf_Result) {
		if res.thread_group.initted {
			edit_alert("release thread group");
			shutdown(*res.thread_group);
			res.thread_group.initted = false; // @CompilerBug
		}
		release(*res.pool);
	};
	ret.items.allocator = context.allocator;
	max_per_file := "15";
	if paths.count <= 1 // hacky ..
		max_per_file = "100"; // idk
	args: [..]string;
	args.allocator = temp;
	array_add(*args, "rg", "--json", "-m", max_per_file, "-S", "--", search);
	array_add(*args, .. paths);
	if !paths
		array_add(*args, ".");
	res, output := run_command(.. args, capture_and_return_output = true);
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
			end = val.submatches[0].end,
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
		ret.thread_group.logging = false;
		// I DON'T KNOW WHY THIS HAPPENS @@:
		// if num_threads > 6 and using pool allocator, it randomly crashes...
		// (but otherwise, this shit leaks..)
		init(*ret.thread_group, num_threads = 5, (group: *Thread_Group, thread: *Thread, _work: *void) -> Thread_Continue_Status {
			work := _work.(*Work);
			// looks like using the temp thread allocator works..
			work.parse_ok, work.match = fson_parse_string(work.json_string, Rg_Match,, allocator=temp);
			return .CONTINUE;
		});
		ret.poll = (res: *Fzf_Result) {
			results := get_completed_work(*res.thread_group);
			for results {
				work := it.(*Work);
				if !work.parse_ok
					continue;
				maybe_add(res, work.match);
			}
		};
		start(*ret.thread_group);
		for lines {
			work := New(Work);
			work.* = .{ json_string = it };
			add_work(*ret.thread_group, work);
			//log("MATCH %", val);
		}
		ret.poll(ret);
		//for 1..2 {
			//ret.poll(ret);
		//}
	} else {
		for lines {
			ok, match := fson_parse_string(it, Rg_Match);
			maybe_add(ret, match);
		}
	}
}

#scope_file 

#import "Process";
#import "jaison";
#import "Pool";
#import "Thread";