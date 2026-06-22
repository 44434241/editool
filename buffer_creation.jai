
// this always finds something. the ones for file/directory might return null (well, rn they just crash)
get_path_buffer :: (_path: string) -> *Buffer {
	if !_path {
		// special case for empty buffer
		// (honestly, might want a custom buffer here? maybe)
		return get_file_buffer(_path);
	}
	path := normalize_path(_path,, allocator=temp);
	if is_directory(path)
		return get_directory_buffer(path);
	else
		return get_file_buffer(path);
}

get_directory_buffer :: find_or_create_directory_buffer;

find_or_create_file_buffer :: (_filename: string, flags: Buffer.Flags = .NONE, file_flags: Buffer.File_Flags = .NONE, must_respect_flags := false) -> *Buffer {
	assert(!must_respect_flags); // some flags might be whatever ! but not always ! in the future there will be some case
	assert((file_flags & .READ_ONLY) == file_flags); // has no other flags
	assert(flags == .NONE); // ...
	filename := _filename;
	if filename {
		filename = normalize_path(filename,, allocator=temp);
		assert(!is_directory(filename));
		for context.edit.buffers {
			if it.kind == .FILE && it.path == filename {
				if it.file_flags != file_flags
					continue;
				// for the buffer to be temp, both the previous and this "new created" buffer must be temp
				return it;
			}
		}
	}
	buf := _create_buffer_from_file(filename, flags, file_flags);
	return buf;
}

get_file_buffer :: find_or_create_file_buffer;

find_or_create_directory_buffer :: (_path: string) -> *Buffer {
	path := normalize_path(_path,, allocator=temp);
	if peek(path) != #char "/"
		path = tprint("%/", path);
	assert(is_directory(path), "'%' is not directory", path);
	for context.edit.buffers {
		if it.kind == .DIRECTORY && it.path == path
			return it;
	}
	buf := _create_buffer_from_directory(path);
	return buf;
}

_insert_string_into_buffer_as_from_file :: (buf: *Buffer, file_str: string) {
	string_lines: []string = split(file_str, #char "\n",, allocator=temp);
	for * string_lines {
		// maybe should have some flag for clrf endings ?
		if it.count && peek(it.*) == #char "\r" {
			it.count -= 1;
			buf.file_flags |= .CLRF;
		}
	}
	// Doing this because a line is added on buffer creation
	if string_lines.count > 0 && peek(string_lines) == ""
		string_lines.count -= 1;
	array_reserve(*buf.lines, string_lines.count + 10);
	for string_lines {
		// Only place left where lines/chars are directly added/removed.
		array_adds(*peek_pointer(buf.lines).chars, it);
		if it_index + 1 != string_lines.count {
			array_add(*buf.lines, .{
				chars.allocator = .{pool_allocator_proc, *buf.pool},
			});
		}
	}
}

// filename must be normalized
_create_buffer_from_file :: (filename: string, flags: Buffer.Flags, file_flags: Buffer.File_Flags) -> *Buffer {
	time_this("Create buffer");
	buf := _new_buffer(.FILE);
	buf.caps = .ALL;
	buf.flags = flags;
	buf.file_flags = file_flags;
	buf.path = copy_string(filename,, allocator=allocator_of(buf));
	//refresh_buffer_size(*buf); // from LINES, COLS
	buf.syntax = get_syntax_for_filename(filename);
	file_str: string;
	file_ok: bool = false;
	if filename {
		file_str, file_ok = read_entire_file(filename,, allocator=temp);
	}
	if file_ok {
		_insert_string_into_buffer_as_from_file(buf, file_str);
	} else {
		buf.file_flags |= .NO_FILE;
	}
	return buf;
}

refresh_file_buffer :: (buf: *Buffer) {
	assert(buf.kind == .FILE);
	assert(buf.path != "");
	file_str, file_ok := read_entire_file(buf.path,, allocator=temp);
	replace_buffer_lines_without_caps(null, buf, .[ "" ], .NO_UNDO);
	_insert_string_into_buffer_as_from_file(buf, file_str);
	clear_dirty(buf);
}

refresh_directory_buffer :: (buf: *Buffer) {
	assert(buf.kind == .DIRECTORY);
	using,only(directory_files, path) buf;
	array_reset(*directory_files);
	for s: string.[ "./", "../" ] {
		array_add(*directory_files, .{
			last_name = s,
			flags = .IMMUTABLE,
		});
	}
	names := file_list_including_directories(path,, allocator=allocator_of(buf));
	for names {
		s := it;
		if is_directory(s)
			s = sprint("%/", s,, allocator=allocator_of(buf));
		assert(starts_with(s, path));
		s = advance(s, path.count+1);
		array_add(*directory_files, .{
			last_name = s,
		});
	}
	replace_buffer_lines_without_caps(null, buf, .[ "" ], .NO_UNDO | .NO_CALLBACK);
	for * directory_files {
		array_adds(*peek_pointer(buf.lines).chars, it.last_name);
		if it_index + 1 != directory_files.count {
			array_add(*buf.lines, .{
				chars.allocator = allocator_of(buf),
			});
		}
	}
	clear_dirty(buf);
}

// path must be normalized
_create_buffer_from_directory :: (path: string) -> *Buffer {
	buf := _new_buffer(.DIRECTORY);
	buf.caps |= .ALL;
	buf.syntax = get_syntax_for_filename("");
	buf.path = copy_string(path,, allocator=allocator_of(buf));
	refresh_directory_buffer(buf);
	add_command(*buf.commands, 
		keybind = "\n",
		mode = .COMMAND,
		proc = (in: Command_In) -> Command_Res {
			using in.window.buffer;
			idx := in.window.cursor.position.y;
			name := directory_files[idx].last_name;
			if !name
				return command_error("bad path stuff");
			new_path := path_join(path, name);
			buf := get_path_buffer(new_path);
			change_buffer(in.window, buf);
			return .{};
		}
	);
	buf.modify_buffer_operation = (win: *Window, buf: *Buffer, op: *Buffer_Op) -> bool {
		using buf;
		op.flags |= .CALLBACK_BEFORE_UNDO_AND_REDO;
		if op.kind == {
			case .INSERT_CHARS; #through;
			case .ERASE_CHARS;
				return !directory_files[op.y].is_marked_for_delete && directory_files[op.y].flags & .IMMUTABLE == 0;
			case .SPLIT_LINE;
				if op.x != lines[op.y].count
					return false;
				assert(op.flags & .IS_UNDO == 0);
				array_insert_at(*directory_files, .{
					is_new = true,
				}, op.y+1);
				// split line logic here (the file at y+1 is no longer being created)
				return true;
			case .MERGE_LINES;
				if op.flags & .IS_UNDO == 0 {
					if lines[op.y+1].as_string != "" || !directory_files[op.y+1].is_new
						return false;
				}
				assert(op.count == 1);
				array_ordered_remove_by_index(*directory_files, op.y+1);
				// merge lines logic here (remove file)
				return true;
			case .ERASE_LINES;
				assert(op.flags & .IS_UNDO == 0);
				all_are_empty := true;
				for y: op.y..op.y+op.count-1 {
					if !directory_files[y].is_new || directory_files[y].is_marked_for_delete > 0 {
						all_are_empty = false;
					}
					if directory_files[y].flags & .IMMUTABLE
						return false;
				}
				if all_are_empty {
					for y: op.y..op.y+op.count-1 {
						array_ordered_remove_by_index(*directory_files, op.y);
					}
					return true;
				}
				op.flags |= .DO_NOT_EXECUTE_BUT_CONSIDER_EXECUTED;
				for y: op.y..op.y+op.count-1 {
					f := *directory_files[y];
					if f.flags & .IMMUTABLE == 0 {
						f.is_marked_for_delete += 1;
					}
				}
				return true; // should be true
			case .INSERT_LINES;
				if op.flags & .IS_UNDO == 0
					return false; // tbh could support this..
				if op.flags & .DO_NOT_EXECUTE_BUT_CONSIDER_EXECUTED == 0 {
					for < op.lines {
						array_insert_at(*directory_files, .{
							is_new = true,
						}, op.y);
					}
				} else {
					for y: op.y..op.y+op.count-1 {
						f := *directory_files[y];
						if f.flags & .IMMUTABLE == 0 {
							f.is_marked_for_delete -= 1;
						}
					}
				}
				return true;
		}
		return false;
	}
	buf.apply_mods = (win: *Window, lines: []*Line) {
		for lines {
			using,only(directory_files, directory_files_confirm_index) win.buffer;
			y := it - win.lines.data;
			if y >= directory_files.count
				return;
			f := *directory_files[y];
			col: s8;
			attrs: s32 = 0;
			if directory_files_confirm_index == y
				attrs = A_STANDOUT;
			if f.is_marked_for_delete {
				col = 4;
			} else if f.is_new {
				col = 13;
			} else if f.last_name != it.as_string {
				col = 3;
			} else {
				continue;
			}
			for * it.user_mods {
				it.fg = col;
				it.attributes = attrs;
			}
		}
	}
	return buf;
}

destroy_buffer :: (buffer: *Buffer) {
	if !can_destroy_buffer(buffer) {
		edit_error("ruh roh, can't destroy buffer..");
		return;
	}
	ok := array_ordered_remove_by_value(*context.edit.buffers, buffer);
	assert(ok);
	release(*buffer.pool);
	free(buffer);
}

can_destroy_buffer :: (buf: *Buffer) -> bool {
	assert(buf != null);
	if buf.ref_count > 0
		return false;
	if buf.windows.count > 0
		return false;
	if buf.flags & .PERM
		return false;
	if buf.kind == {
		case .FILE; #through;
		case .DIRECTORY;
			if is_dirty(buf)
				return false;
		case .CUSTOM; //
			// no logic for custom, should be implemented differently
		case;
			// For now, random unknown buffers can't be deleted..
			return false;
	}
	return true;
}

normalize_path :: (_path: string) -> string {
	path := _path;
	arr: [..]string;
	arr.allocator = temp;
	if path[0] == "~" {
		path = advance(path, 1);
		home, ok := get_home_directory(,, allocator=temp);
		if !ok {
			log_error("Cannot get home directory");
			return "";
		}
		array_add(*arr, .. split(home, #char "/",, allocator=temp));
	} else if path[0] != #char "/" {
		dir := get_working_directory(,, allocator=temp);
		if !dir {
			log_error("Cannot get working directory");
			return ""; 
		}
		array_add(*arr, .. split(dir, "/",, allocator=temp));
	}
	array_add(*arr, .. split(path, "/",, allocator=temp));
	idx := 0;
	while idx < arr.count {
		if arr[idx] == "" || arr[idx] == "." {
			array_ordered_remove_by_index(*arr, idx);
			continue;
		}
		if arr[idx] == ".." {
			array_ordered_remove_by_index(*arr, idx);
			if idx > 0 {
				array_ordered_remove_by_index(*arr, idx-1);
				idx -= 1;
			}
			continue;
		}
		idx += 1;
	}
	if arr.count == 0
		return "/";
	b: String_Builder;
	for arr {
		print(*b, "/%", it);
	}
	return builder_to_string(*b);
}

// find implies that it might return null
find_buffer :: (id: BufId) -> *Buffer {
	for context.edit.buffers {
		if it.id == id
			return it;
	}
	return null;
}

// this doesn't have lines, so it'll crash if u dont add any
create_custom_buffer :: (flags: Buffer.Flags = .NONE) -> *Buffer {
	buf := _new_buffer(.CUSTOM);
	buf.syntax = get_syntax_for_filename("");
	buf.flags |= flags;
	return buf;
}

BufId :: #type,distinct s64;
BUF_ID_NULL :: 0;
_running_buffer_id: BufId = 1;

next_buffer_id :: () -> BufId {
	ret := _running_buffer_id;
	_running_buffer_id += 1;
	return ret;
}

_new_buffer :: (kind: Buffer.Kind) -> *Buffer {
	buf := New(Buffer);
	set_allocators(*buf.pool);
	buf.id = next_buffer_id();
	buf.kind = kind;
	array_add(*context.edit.buffers, buf);
	allocator := Allocator.{pool_allocator_proc, *buf.pool};
	// in order of declaration
	buf.lines.allocator = allocator;
	buf.ops.allocator = allocator;
	buf.windows.allocator = allocator;
	buf.commands.allocator = allocator;
	buf.search_matches.matches.allocator = allocator;
	buf.marks.allocator = allocator;
	buf.folds.allocator = allocator;
	buf.directory_files.allocator = allocator;
	array_add(*buf.lines, .{
		chars.allocator = allocator,
	});
	return buf;
}

file_list_including_directories :: (path: string, recursive := false, follow_directory_symlinks := true) -> [] string {
	files : [..] string;
	visitor :: (info: *File_Visit_Info, user_data: *[..] string) {
		array_add(user_data, copy_string(info.full_name));
	}
	 visit_files(path, recursive, *files, visitor,
			follow_directory_symlinks=follow_directory_symlinks, visit_directories=true);
	quick_sort(files, compare);
	return files;
}

#import "Sort";