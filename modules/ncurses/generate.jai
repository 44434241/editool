

#run {
	set_build_options_dc(.{ do_output = false });
	generate();
}

generate :: () {
	options: Generate_Bindings_Options;
	{
		using options;
		array_add(*libraries, .{ filename = "libncursesw", identifier = "libncursesw" });
		// not the best idea to have a global file?
		array_add(*source_files, "/usr/include/ncurses.h");
		array_add(*source_files, "/usr/include/curses.h");
		array_add(*source_files, "/usr/include/unctrl.h");
		log_ignored_system_declarations = true;
		log_unsupported = true;
	}
	ok := generate_bindings(options, "generated.jai", log_results = true);
	if !ok {
		log("failed");
		return;
	}
	log("generate ok");
}

#import "Compiler";
#import "Basic";
#import "Bindings_Generator";
