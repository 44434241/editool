

message_loop :: (w: Workspace) {
	while true {
		message := compiler_wait_for_message();
		if message.kind == .COMPLETE break;
	}
}

#run {
	set_build_options_dc(.{ do_output = false });
	w := compiler_create_workspace();
	args := get_build_options(get_current_workspace()).compile_time_command_line;
	opts := get_build_options(get_current_workspace());
	if array_find(args, "ok") {
		log("doing editool.ok");
		set_optimization(*opts, .VERY_OPTIMIZED);
		opts.output_executable_name = "editool.ok";
	} else {
		log("doing debug editool");
		set_optimization(*opts, .VERY_DEBUG);
		opts.output_executable_name = "editool";
	}
	do_run := false;
	if array_find(args, "-run") {
		do_run = true;
	}
	opts.output_type = .EXECUTABLE;
	set_build_options(opts, w);
	compiler_begin_intercept(w);
	add_build_file("main.jai", w);
	message_loop(w);
	compiler_end_intercept(w);
	//if do_run {
		//run_command(tprint("./%", opts.output_executable_name));
	//}
}

#import "Compiler";
#import "Basic";
#import "Process";