

// still slow, need to use table
#add_context fstr: string;

fson_parse_string :: (s: string, $T: Type) -> bool, T {
	// @CompilerBug only,only(fstr) doesn't work here?? ?? cuz it's only ??
	using,only(fstr) context;
	context.fstr = s;
	ret: T;
	ok := parse_value(ret, false);
	return ok, ret;
}


#scope_file 

parse_value :: (out: Any, $is_whatever: bool) -> bool {
	using,only(fstr) context;
	tmp := fstr;
	//log("parsing '%': %", fstr, #ifx is_whatever "<>" else type_to_string(out.type));
	skip_whitespace();
	if fstr.count == 0
		return false;
	assign_and_return :: (val: $T) #expand {
		#if !is_whatever {
			if out.type != type_info(T) {
				log_error("type mismatch");
				`return false;
			}
			out.value_pointer.(*T).* = val;
		}
		`return true;
	}
	if fstr[0] == {
		case #char "t";
			if !expect_and_consume("true")
				return false;
			assign_and_return(true);
		case #char "f";
			if !expect_and_consume("false")
				return false;
			assign_and_return(false);
		case #char "n";
			if !expect_and_consume("null")
				return false;
			assert(is_whatever);
			return true;
		case #char "\"";
			ok, str := parse_string();
			if !ok
				return false;
			assign_and_return(str);
		case #char "{";
			fstr = advance(fstr, 1);
			#if !is_whatever {
				if out.type.type != .STRUCT
					return false;
			}
			skip_whitespace();
			if !fstr.count
				return false;
			if fstr[0] == #char "}" {
				fstr = advance(fstr, 1);
				return true;
			} else {
				DO_TABLE :: false; // it's like 3 times slower
				#if !is_whatever && DO_TABLE {
					table: Table(string, Type_Info_Struct_Member);
					table.allocator = temp;
					for out.type.(*Type_Info_Struct).members {
						if it.offset_in_bytes < 0
							continue;
						table_set(*table, it.name, it);
					}
				}
				while true {
					skip_whitespace();
					ok, key := parse_string(,, allocator=temp);
					if !ok
						return false;
					skip_whitespace();
					if !expect_and_consume(":")
						return false;
					#if is_whatever {
						parse_ok := parse_value(null, is_whatever = true);
						if !parse_ok
							return false;
					} else {
						found_member := false;
						#if !DO_TABLE {
							for out.type.(*Type_Info_Struct).members {
								if it.offset_in_bytes < 0
									continue;
								if it.name == key {
									v: Any = Any.{ type = it.type, value_pointer = out.value_pointer + it.offset_in_bytes };
									parse_ok := parse_value(v, is_whatever = false);
									if !parse_ok
										return false;
									found_member = true;
									break;
								}
							}
						} else {
							found, member := table_find(*table, key);
							if found {
								found_member = true;
								v: Any = Any.{ type = member.type, value_pointer = out.value_pointer + member.offset_in_bytes };
								parse_ok := parse_value(v, is_whatever = false);
								if !parse_ok
									return false;
							}
						}
						if !found_member {
							parse_ok := parse_value(null, is_whatever = true);
							if !parse_ok
								return false;
						}
					}
					skip_whitespace();
					if fstr.count && fstr[0] == #char "}" {
						fstr = advance(fstr, 1);
						break;
					}
					if !expect_and_consume(",")
						return false;
				}
				return true;
			}
		case #char "[";
			fstr = advance(fstr, 1);
			#if !is_whatever {
				if out.type.type != .ARRAY
					return false;
				arr_type: *Type_Info_Array = xx out.type;
				assert(arr_type.array_type == .RESIZABLE);
				arr: *Resizable_Array = out.value_pointer;
				Initialize(arr);
			}
			skip_whitespace();
			if !fstr.count
				return false;
			if fstr[0] == #char "]" {
				fstr = advance(fstr, 1);
				return true;
			} else {
				while true {
					#if !is_whatever {
						maybe_grow(arr, arr_type.element_type.runtime_size); 
						assert(arr.data != null);
						val := Any.{ value_pointer = arr.data + (arr_type.element_type.runtime_size * arr.count), type = arr_type.element_type };
						arr.count += 1;
						if arr_type.element_type.type == .STRUCT {
							ini := arr_type.element_type.(*Type_Info_Struct).initializer;
							if ini
								ini(val.value_pointer);
							else
								memset(val.value_pointer, 0, val.type.runtime_size);
						} else {
							memset(val.value_pointer, 0, val.type.runtime_size);
						}
						ok := parse_value(val, is_whatever = false);
						if !ok
							return false;
					} else {
						ok := parse_value(null, is_whatever = true);
						if !ok
							return false;
					}
					skip_whitespace();
					if !fstr.count
						return false;
					if fstr[0] == #char "]" {
						fstr = advance(fstr, 1);
						break;
					}
					if !expect_and_consume(",")
						return false;
				}
				return true;
			}
		case;
			if is_digit(fstr[0]) {
				i, ok, remainder := string_to_int(fstr);
				fstr = remainder;
				if !ok
					return false;
				assign_and_return(i);
			} else {
				assert(false, "%", fstr[0]);
				return false;
			}
	}
}

parse_string :: () -> bool, string {
	using,only(fstr) context;
	if fstr.count == 0 || fstr[0] != #char "\""
		return false, "";
	fstr = advance(fstr, 1);
	start := fstr.data;
	ok := false;
	should_unescape := false;
	while fstr.count {
		if fstr[0] == #char "\"" {
			fstr = advance(fstr, 1);
			ok = true;
			break;
		}
		if fstr[0] == #char "\\" {
			if fstr.count == 1
				break;
			if fstr[1] == {
				case #char "\\"; #through;
				case #char "\""; #through;
				case #char "n"; #through;
				case #char "t"; #through;
				case #char "r";
					fstr = advance(fstr, 2);
					should_unescape = true;
				case;
					assert(false, "Bad escaped char: %", fstr[1]);
			}
		} else {
			fstr = advance(fstr, 1);
		}
	}
	if !ok
		return false, "";
	str := string.{ data = start, count = (fstr.data - start) - 1 };
	unescape :: (_s: string) -> string {
		ret: [..]u8;
		s := _s;
		while s.count {
			if s[0] == #char "\\" {
				if s[1] == {
					case #char "\\"; #through;
					case #char "\"";
						array_add(*ret, s[1]);
					case #char "n";
						array_add(*ret, "\n");
					case #char "t";
						array_add(*ret, "\t");
					case #char "r";
						array_add(*ret, "\r");
					case;
						assert(false);
				}
				s = advance(s, 2);
			} else {
				array_add(*ret, s[0]);
				s = advance(s, 1);
			}
		}
		return cast(string)ret;
	}
	if should_unescape {
		str = unescape(str);
	}
	return true, str;
}

expect_and_consume :: (s: string) -> bool {
	using,only(fstr) context;
	if fstr.count < s.count
		return false;
	defer fstr = advance(fstr, s.count);
	return string.{ data = fstr.data, count = s.count } == s;
}

skip_whitespace :: () {
	using,only(fstr) context;
	while fstr.count && is_space(fstr[0])
		fstr = advance(fstr, 1);
}

#import "Basic";
#import "Hash_Table";
