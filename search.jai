
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
	// String commands (MUST BE FIRST MEMBER):
	#as using _: String_Command_State;
	//
	status: Status = .ERROR;
	//
	compile_time: Editime = 0;
	// these 2 are normally allocated
	search_chars: [..]u8;
	#overlay(search_chars) search_string: string;
	replace_chars: [..]u8;
	#overlay(replace_chars) replace_string: string;
	// this is a view
	motion_string: string;
	Flags :: enum_flags {
		SPECIAL_CASE_SEARCH_REPLACE; // u
		CASE_SENSITIVE; // C
		// Even if wrote the full search/replace syntax, don't search replace
		SEARCH_ONLY; // s
		// even if replace string is empty, replace (less common than the above option)
		REPLACE; // r
		// confirm search/replace
		REPLACE_CONFIRM; // c
		NONE :: 0;
	}
	flags: Flags;
	//
	search_regex: Uniform.Regexp;
}

editool_search_init :: () {
	time_this("editool_search_init");
	using context.search;
	string_commands_init(*context.search, "Search");
	add_command(*buffer.commands, 
		keybind = .[ 6 ], // ctrl + f
		mode = .INSERT | .COMMAND,
		proc = (in: Command_In) -> Command_Result {
			// Update search
			string_commands_ensure_up_to_date(*context.search);
			if context.search.status != .SEARCH && context.search.status != .SEARCH_REPLACE {
				return command_error("Bad search");
			}
			_ensure_window_released(*context.search);
			str := copy_string(context.search.search_string,, allocator=temp); // not sure if i need to copy this
			fzf_win := make_fzf_window((res: *Fzf_Result, s: string, data: *void) {
				buf := data.(*Buffer);
				do_rg(res, s, ".");
			}, start_search = str);
			if fzf_win == null
				return command_error();
			//_clear_search();
			return .{};
		},
	);
	context.search.execute = _execute_search;
	context.search.update = _update_search;
	context.search.cancel = _cancel_search;
}

// callbacks from string commands
_execute_search :: (__: *String_Command_State, win: *Window) {
	using context.search;
	if win.buffer != context.search.buffer {
		restore_checkpoint(win);
		if status == .SEARCH_REPLACE {
			if flags & .REPLACE_CONFIRM == 0 {
				_do_search_replace(win);
				maybe_update_search_matches(win, force_update=true);
			} else if win.buffer.search_matches.matches.count != 0 {
				hold(win);
				using win.buffer.search_matches;
				if matches.count > 0
					move_cursor(win, matches[0].position);
				ask_for_char("Do u wanna confirm (y/n)", (ch: s32, _win: *void) -> bool, string {
					win := _win.(*Window);
					maybe_update_search_matches(win);
					ret: bool = false;
					using win.buffer.search_matches;
					if matches.count > 0 && context.search.status == .SEARCH_REPLACE {
						if ch == {
							case 0;
							case #char "n";
								ret = false;
							case #char "y";
								ok := _do_search_replace(win, limit = 1);
								maybe_update_search_matches(win, force_update=true);
								ret = ok && matches.count > 0;
								if matches.count > 0 {
									pos := matches[0].position;
									move_cursor(win, pos);
								}
							case;
								edit_alert("Invalid char");
								ret = true;
						}
					} 
					if !ret
						release(win);
					return ret, "";
				}, win);
			}
		} else {
			go_to_search_match_offset(0, jump = true);
		}
	}
}

// This thing with checkpoints should be cleaner.
// It doesn't properly update highlighting !!
_update_search :: (_: *String_Command_State, win: *Window) {
	_recompile_search();
	if win.buffer != context.search.buffer {
		restore_checkpoint(win);
		if context.search.status == .SEARCH_REPLACE && context.search.flags & .REPLACE_CONFIRM == 0 {
			// 
			create_checkpoint(win);
			_do_search_replace(win, is_after_checkpoint = true);
		}
	}
}

_cancel_search :: (_: *String_Command_State, win: *Window) {
	// do nothing
	restore_checkpoint(win);
}

start_search :: (start: string = "") {
	string_commands_start(*context.search, start);
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
	string_commands_ensure_up_to_date(*context.search);
	if search_string == ""
		return "";
	b: String_Builder;
	b.allocator = temp;
	if status == .SEARCH_REPLACE {
		print(*b, "Search/Replace ");
		print(*b, "'%/%'", search_string, replace_string);
	} else {
		print(*b, "Search ");
		print(*b, "'%'", cast(string)chars);
	}
	if motion_string {
		print(*b, " m:'%'", motion_string);
	}
	print(*b, ": ");
	if status == .ERROR {
		print(*b, "Parse error!");
	} else {
		using win.buffer.search_matches;
		maybe_update_search_matches(win); // sanity check
		print(*b, "%/%", last_match_index+1, matches.count);
	}
	return builder_to_string(*b,, allocator=temp);
}

_recompile_search :: () {
	using context.edit.search_state;
	y := window.cursor.y;
	compile_time = context.edit.time;
	if status != .ERROR {
		Uniform.uninit(*search_regex);
	}
	status = .SEARCH;
	array_reset(*search_chars);
	array_reset(*replace_chars);
	motion_string = "";
	flags = .NONE;
	idx := 0;
	while idx < chars.count {
		if chars[idx] == #char "\\" {
			if idx + 1 == chars.count {
				array_add(*search_chars, chars[idx]);
				break;
			}
			// only these characters get escaped
			if chars[idx+1] == "/" || chars[idx+1] == "!" || chars[idx+1] == "@" {
				array_add(*search_chars, chars[idx+1]);
				idx += 2;
				continue;
			}
		}
		if chars[idx] == #char "!" || chars[idx] == "@" {
			motion_string = cast(string)advance(chars, idx+1);
			break;
		}
		if chars[idx] != #char "/" {
			array_add(*search_chars, chars[idx]);
			idx += 1;
			continue;
		}
		if chars[idx] == #char "/" {
			idx += 1;
			status = .SEARCH_REPLACE;
			while idx < chars.count {
				if chars[idx] == #char "\\" {
					if idx + 1 == chars.count {
						array_add(*replace_chars, chars[idx]);
						break;
					}
					// only these characters get escaped
					if chars[idx+1] == "/" || chars[idx+1] == "!" || chars[idx+1] == "@" {
						array_add(*replace_chars, chars[idx+1]);
						idx += 2;
						continue;
					}
				}
				if chars[idx] == #char "!" || chars[idx] == "@" {
					motion_string = cast(string)advance(chars, idx+1);
					break;
				}
				if chars[idx] != #char "/" {
					array_add(*replace_chars, chars[idx]);
					idx += 1;
					continue;
				}
				flag_string := cast(string)advance(chars, idx+1);
				for flag_string {
					if it == {
						case "u";
							flags |= .SPECIAL_CASE_SEARCH_REPLACE;
						case "C";
							flags |= .CASE_SENSITIVE;
						case "s";
							flags |= .SEARCH_ONLY;
						case "r";
							flags |= .REPLACE;
						case "c";
							flags |= .REPLACE_CONFIRM;
						case "!";
							motion_string = advance(flag_string, it_index+1);
							break;
						case;
							status = .ERROR;
							return;
					}
				}
				break;
			}
			break;
		}
	}
	if flags & .SEARCH_ONLY
		status = .SEARCH;
	if !(flags & .REPLACE) && replace_string.count == 0
		status = .SEARCH;
	full_regex_string := tprint(".*+(%)", search_string); // non-greedy whatever
	// @UniformBug with how .NonGreedy works, i think? (inverts instead of choosing a default)
	compile_flags: Uniform.ParseFlags = (.LikePerl | .NonGreedy | .FoldCase);
	if flags & .CASE_SENSITIVE {
		compile_flags &= ~.FoldCase;
	}
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
			edit_warn("Bad replace string");
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
	pos := matches[selected_match].position;
	// we'll see if i like this scrolling thing
	scroll := get_relative_y(win.buffer, pos.y, -win.size.y / 2);
	should_scroll := !in_range_exclusive(pos.y, win.scroll, win.scroll + win.size.y);
	move_cursor(win, pos, jump = jump);
	if should_scroll
		set_scroll(win, scroll);
	// also, scroll
	return true;
}

// search replace works with preview i guess.. don't need to overengineer it :: 
_do_search_replace :: (using,except(flags, Flags) win: *Window, limit := -1, $is_after_checkpoint := false) -> bool {
	is_lower :: (ch: u8) -> bool {
		return #char "a" <= ch && ch <= "z";
	}
	is_upper :: (ch: u8) -> bool {
		return #char "A" <= ch && ch <= "Z";
	}
	using,except(buffer) context.edit.search_state;
	assert(status == .SEARCH_REPLACE);
	if !can_replace(search_regex, replace_string) {
		edit_error("Can't search replace");
		return false;
	}
	maybe_update_search_matches(win);
	using buffer.search_matches;
	edit_alert("Replacing %", matches.count);
	// Match positions are in increasing position
	x_offset := 0;
	last_y := 0;
	#if is_after_checkpoint {
		new_matches: [..]Match;
		defer {
			match_time = context.edit.time;
			array_reset(*matches);
			matches = new_matches;
		}
	}
	here_matches: []Match = matches;
	if limit >= 0
		here_matches.count = min(here_matches.count, limit);
	for * array_copy(here_matches,, allocator=temp) {
		if it.position.y != last_y {
			x_offset = 0;
			last_y = it.position.y;
		}
		it.position.x += x_offset;
		ok, searched, replaced := _match_search_replace(win, it.*, replace_string);
		if !ok {
			edit_alert("Can't search replace (2)");
			return false;
		}
		if flags & .SPECIAL_CASE_SEARCH_REPLACE && searched.count > 0 && replaced.count > 0 {
			if is_lower(searched[0]) {
				to_lower_in_place(replaced);
			} else if searched.count >= 2 && is_upper(searched[0]) && is_upper(searched[1]) {
				to_upper_in_place(replaced);
			} else {
				replaced[0] = to_upper(replaced[0]);
				to_lower_in_place(advance(replaced, 1));
			}
		}
		log("REPLACE % -> %", searched, replaced);
		erase_chars(win, it.position, it.count);
		// assumes ok string
		_write_normal_string(win, it.position, replaced);
		x_offset += replaced.count - searched.count;
		#if is_after_checkpoint {
			array_add(*new_matches, it.*);
			peek_pointer(new_matches).count = replaced.count;
		}
	}
	return true;
}

// temp allocated
// doesn't handle search/replace flags ..?
_match_search_replace :: (using,except(flags, Flags) win: *Window, m: Search_Match, replace: string) -> bool, string, string {
	if !is_position_in_buffer(buffer, .{m.position.x + m.count, m.position.y}) {
		edit_error("Failed search replace");
		return false, "", "";
	}
	line := *lines[m.position.y];
	s := string.{ data = line.chars.data + m.position.x, count = m.count };
	// uses global search regex !
	ok, new_str := search_replace(context.edit.search_state.search_regex, s, replace,, allocator=temp);
	if !ok {
		edit_error("Failed search replace (2) % %", m, replace);
		log_stack_trace(context.stack_trace);
		return false, "", "";
	}
	return true, s, new_str;
}

maybe_update_search_matches :: (win: *Window, force_update := false) -> bool {
	string_commands_ensure_up_to_date(*context.search);
	buf := win.buffer;
	if buf.flags & .NO_SEARCH
		return true;
	should_update := force_update;
	if buf.search_matches.match_time < max(buf.modify_time, context.edit.search_state.compile_time) {
		should_update = true;
	}
	if should_update
		return _update_search_matches(win);
	return true;
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
	//text: [..]u8;
	//indices: [..]Position;
	//text.allocator, indices.allocator = temp;
	ly := 0;
	ry := win.buffer.lines.count - 1;
	if motion_string {
		waiting: Waiting_Chars;
		waiting.chars.allocator = temp;
		for motion_string {
			waiting_chars_add(*waiting, it);
		}
		motion := find_motion(waiting.chars);
		if !motion {
			edit_warn("Couldn't find search motion '%'", motion_string);
			return false;
		} else {
			res := execute_motion(motion, number = waiting.number, window = win);
			ly = normalize_position(win, res.start, .NONE).y;
			ry = normalize_position(win, res.end, .NONE).y;
			if ly > ry
				ly, ry = ry, ly;
		}
	}
	MAX_MATCHES :: 10000;
	for y: ly..ry {
		line := win.buffer.lines[y];
		if matches.count >= MAX_MATCHES
			break;
		//array_add(*text, it);
		//array_add(*indices, it_index);
		s: string = cast(string)line.chars;
		idx := 0;
		while matches.count < MAX_MATCHES { // limit 
			// Looks like i can use unanchored here??? to not have a group for the first match?
			ok, m := Uniform.match(s, search_regex, .UNANCHORED,, allocator=temp);
			if !ok
				break;
			if GROUP_ZERO >= m.count {
				edit_error("nonsense"); // TODO: should check compiled regex to make sure that groups are ok 
				return false;
			}
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

#import "String";