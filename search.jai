
// This is for buffer.
// I think some stuff should belong to the window?
// - Like `last_match_index`. But for now, whatever.
Search_Matches :: struct {
	Match :: struct {
		position: Position;
		// end: Position; // todo
		count: int;
	}
	matches: [..]Match;
	match_time: Editime = -1;
	last_match_index: int = -1;
}

Search_Match :: Search_Matches.Match;

Search_State :: struct {
	Status :: enum {
		SEARCH;
		SEARCH_REPLACE;
		ERROR;
	}
	status: Status = .ERROR;
	chars: [..]u8; // input chars
	#overlay(chars) char_string: string;
	//
	change_time: Editime = 0;
	// These 2 are not touched by anything else!!!
	// And they are views into char, OR constant strings
	search_string: string;
	replace_string: string;
	search_regex: Uniform.Regexp;
	buffer: *Buffer;
	window: *Window;
}

editool_search_init :: () {
	using context.search;
	buffer = create_custom_buffer();
	buffer.flags |= .NO_SEARCH;
	line: *Line = array_add(*buffer.lines);
	//array_adds(*line.chars, "keybind ");
	buffer.caps |= .MODE_INSERT | .MODE_COMMAND;
	buffer.caps |= .INSERT_CHARS | .DELETE_CHARS;
	array_add(*buffer.commands, .{
		keybind = to_keybind("\n"),
		proc = wrap_command(execute_search),
	});
	array_add(*buffer.commands, .{
		keybind = to_keybind(.[ KEY_ESCAPE ]),
		proc = wrap_command(stop_search),
	});
	array_add(*buffer.insert_commands, .{
		keybind = to_keybind("\n"),
		proc = wrap_command(execute_search),
	});
	parent := context.edit.second_root;
	window = create_buffer_window(parent, context.search.buffer,
			select = false, is_hidden = false);
	window.user_title = "SEARCH";
}

start_search :: () {
	using context.search;
	_clear_search();
	select_window(window);
	change_edit_mode(.INSERT);
}

// pressed enter
execute_search :: () {
	using context.search;
	change_edit_mode(.COMMAND);
	select_normal_window();
	if status == .SEARCH_REPLACE {
		_do_search_replace(context.buffer_window);
		maybe_update_search_matches(context.buffer_window, force_update=true);
	} else {
		go_to_search_match_offset(0, jump = true);
	}
}

// TODO: this auto changes to command mode,
// because of how commands work...
// i think ?? either way, it's wrong
stop_search :: () {
	_clear_search();
	select_normal_window();
}


// - parse error:
// Search 'abc': parse error
// - search:
// Search 'abc': 1/3
// - search-replace
// Search+Replace: 'abc/efg': 1/3, First match 'abc' -> 'efg'

get_search_info_for_status_bar :: (win: *Window) -> string {
	using,except(buffer) context.edit.search_state;
	assert(win.kind == .BUFFER, "%", win.kind);
	_maybe_recompile_search();
	if search_string == ""
		return "";
	b: String_Builder;
	b.allocator = temp;
	if status == .SEARCH_REPLACE {
		print(*b, "Search/Replace ");
		print(*b, "'%/%': ", search_string, replace_string);
	} else {
		print(*b, "Search ");
		print(*b, "'%': ", cast(string)chars);
	}
	if status == .ERROR {
		print(*b, "Parse error!");
	} else {
		using win.buffer.search_matches;
		maybe_update_search_matches(win); // sanity check
		print(*b, "%/%", last_match_index+1, matches.count);
		if status == .SEARCH_REPLACE && matches.count > 0 {
			idx := max(last_match_index, 0);
			ok, searched, replaced := _match_search_replace(win, matches[idx], replace_string);
			if ok {
				print(*b, ", Replace: % -> %", searched, replaced);
			}
		}
	}
	return builder_to_string(*b,, allocator=temp);
}

_clear_search :: () {
	using context.edit.search;
	delete_chars(window, .{0, 0}, window.lines[0].count);
	_maybe_recompile_search();
}

_maybe_recompile_search :: () {
	using context.edit.search_state;
	change_time = context.edit.time;
	if char_string == buffer.lines[0].as_string
		return;
	if status != .ERROR {
		Uniform.uninit(*search_regex);
	}
	{
		array_reset(*chars);
		array_add(*chars, .. buffer.lines[0].chars);
	}
	status = .SEARCH;
	search_string = cast(string)chars;
	replace_string = "";
	idx := 0;
	while idx < chars.count {
		if chars[idx] == #char "/" {
			search_string = string.{ data = chars.data, count = idx };
			replace_string = cast(string)advance(chars, idx + 1);
			status = .SEARCH_REPLACE;
			break;
		}
		idx += 1;
		//if chars[idx] == #char "\\" {
	}
	full_regex_string := tprint(".*+(%)", search_string); // non-greedy whatever
	// @UniformBug with how .NonGreedy works, i think? (inverts instead of choosing a default)
	compile_flags: Uniform.ParseFlags = (.LikePerl | .NonGreedy | .FoldCase);
	re, ok := Uniform.compile(full_regex_string, compile_flags);
	if !ok {
		status = .ERROR;
		edit_alert("Regex compile failed");
		return;
	}
	search_regex = re; 
	if status == .SEARCH_REPLACE {
		if !can_replace(search_regex, replace_string) {
			Uniform.uninit(*search_regex);
			status = .ERROR;
			return;
		}
	}
}

// updates matches only when you jump actually
// what do i name this??
go_to_search_match_offset :: (offset: int, jump := true) -> bool {
	win := context.buffer_window;
	buf := win.buffer;
	using buf.search_matches;
	ok := maybe_update_search_matches(win);
	if !ok
		return false;
	if matches.count == 0
		return false;
	y := win.cursor.y;
	selected_match := matches.count - 1;
	defer {
		last_match_index = selected_match;
	}
	for matches {
		if it.position <= win.cursor.position {
			selected_match = it_index;
		} else {
			break;
		}
	}
	if win.cursor.position != matches[selected_match].position && offset <= 0 {
		selected_match += 1;
	}
	log("selected match: %\n", selected_match);
	selected_match = (selected_match + offset) % matches.count;
	selected_match = (selected_match + matches.count) % matches.count;
	move_cursor(win, matches[selected_match].position, jump = jump);
	return true;
}

_do_search_replace :: (using win: *Window) {
	using,except(buffer) context.edit.search_state;
	assert(status == .SEARCH_REPLACE);
	if !can_replace(search_regex, replace_string) {
		edit_error("Can't search replace");
		return;
	}
	maybe_update_search_matches(win);
	using buffer.search_matches;
	log("DOING SEARCH REPLACE (%)", matches.count);
	// need to iterate them just right !
	for < array_copy(matches,, allocator=temp) {
		ok, searched, replaced := _match_search_replace(win, it, replace_string);
		if !ok
			return;
		log("REPLACE % -> %", searched, replaced);
		delete_chars(win, it.position, it.count);
		// assumes ok string
		_write_normal_string(win, it.position, replaced);
	}
}

maybe_update_search_matches :: (win: *Window, force_update := false) -> bool {
	_maybe_recompile_search();
	buf := win.buffer;
	if buf.flags & .NO_SEARCH
		return true;
	should_update := force_update;
	if buf.search_matches.match_time < max(buf.modify_time, context.edit.search_state.change_time) {
		should_update = true;
	}
	if should_update
		return _update_search_matches(win);
	return true;
}

// temp allocated
_match_search_replace :: (using win: *Window, m: Search_Match, replace: string) -> bool, string, string {
	if !is_position_in_buffer(buffer, .{m.position.x + m.count, m.position.y}) {
		edit_error("Failed search replace");
		return false, "", "";
	}
	line := *lines[m.position.y];
	s := string.{ data = line.chars.data + m.position.x, count = m.count };
	// uses global search regex !
	ok, new_str := search_replace(context.edit.search_state.search_regex, s, replace,, allocator=temp);
	if !ok {
		edit_error("Failed search replace (2)");
		return false, "", "";
	}
	return true, s, new_str;
}

// returns true if match was *valid*
_update_search_matches :: (win: *Window) -> bool {
	using,except(buffer) context.edit.search_state;
	using win.buffer.search_matches;
	{
		array_reset(*matches);
		last_match_index = -1;
	}
	//_clear_search();
	match_time = context.edit.time;
	if search_string.count == 0
		return false;
	if status == .ERROR {
		return false;
	}
	time_this("Search");
	//text: [..]u8;
	//indices: [..]Position;
	//text.allocator, indices.allocator = temp;
	MAX_MATCHES :: 10000;
	for line, y: win.buffer.lines {
		if matches.count >= MAX_MATCHES
			break;
		//array_add(*text, it);
		//array_add(*indices, it_index);
		s: string = cast(string)line.chars;
		idx := 0;
		while matches.count < MAX_MATCHES { // limit 
			ok, m := Uniform.match(s, search_regex, .ANCHOR_START);
			if !ok
				break;
			match_str := m[GROUP_ZERO];
			match_offset := match_str.data - s.data;
			if match_str.count == 0 {
				edit_alert("Weirdass match error");
				// not reseting match array?
				return false;
			}
			idx += match_offset;
			defer idx += match_str.count;
			vec2_idx := Position.{ idx, y};
			array_add(*matches, .{
				position = vec2_idx,
				count = match_str.count,
			});
			log("Found match at %: %", vec2_idx, match_str);
			s = advance(s, match_offset + match_str.count);
		}
	}
	return true;
}

#scope_file

// REGEX STUFF

GROUP_ZERO :: 1;

can_replace :: (re: Uniform.Regexp, replace: string) -> bool {
	parts := _replace_to_parts(replace,, allocator=temp);
	for parts {
		if it.group_index + GROUP_ZERO >= re.num_capture_groups + 1 {
			return false;
		}
	}
	return true;
}

search_replace :: (re: Uniform.Regexp, s: string, replace: string) -> bool, string {
	// unanchored ..
	parts := _replace_to_parts(replace);
	ok, captures := Uniform.match(s, re, .ANCHOR_BOTH);
	if !ok 
		return false, "";
	b: String_Builder = .{ allocator = temp };
	for parts {
		if it.group_index < 0 {
			append(*b, it.str);
		} else {
			append(*b, captures[GROUP_ZERO+it.group_index]);
		}
	}
	return true, builder_to_string(*b);
}

Replace_Part :: struct {
	group_index: int = -1;
	str: string;
}

// doesn't support digit > 9
_replace_to_parts :: (replace: string) -> []Replace_Part {
	ret: [..]Replace_Part;
	idx := 0;
	last_idx := 0;
	while idx <= replace.count {
		if idx == replace.count {
			if idx != last_idx
				array_add(*ret, .{ str = .{ data = replace.data + last_idx, count = idx - last_idx }});
			idx += 1;
			last_idx = idx;
			continue;
		}
		if idx + 1 < replace.count && replace[idx] == #char "\\" && is_digit(replace[idx+1]) {
			array_add(*ret, .{ str = .{ data = replace.data + last_idx, count = idx - last_idx }});
			idx += 1;
			array_add(*ret, .{ group_index = replace[idx] - #char "0" });
			idx += 1;
			last_idx = idx;
			continue;
		}
		idx += 1;
	}
	return ret;
}

