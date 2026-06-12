
Grep_Item :: struct {
	filename: string;
	line_number: int;
	line: string;
	start: int;
	end: int;
}


//Grep_Results :: struct {
	//matches: [..]Grep;
//}


do_grep :: (search: string) -> bool, []Grep_Item {
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
	time_this("Do grep");
	res, output := run_command("rg", search, ".", "--json", "-m", "10", "-S", capture_and_return_output = true,, allocator=temp);
	//res, output := run_command("rg", search, ".", "/home/user/jai/latest", "--json", "-m", "10", "-S", capture_and_return_output = true,, allocator=temp);
	ok := res.exit_code == 0;
	if !ok {
		return false, .[];
	}
	ret: [..]Grep_Item;
	//return false, .[];
	for split(output, #char "\n") {
		ok, val := fson_parse_string(it, Rg_Match,, allocator=temp);
		if !ok
			continue;
		if val.type != "match" // @Leak
			continue;
		if val.submatches.count == 0
			continue;
		item := Grep_Item.{
			// @Leak
			filename = copy_string(val.path.text),
			line_number = val.line_number - 1,
			line = copy_string(val.lines.text),
			start = val.submatches[0].start,
			end = val.submatches[0].end,
		};
		//log("MATCH %", val);
		array_add(*ret, item);
	}
	return ok, ret;
}

#scope_file

#import "Process";
