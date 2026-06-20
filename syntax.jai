
Syntax_Element :: struct {
	// kind is an index..
	Kind :: enum {
		// in order of priority ?
		DEFAULT;
		COMMENT;
		MULTILINE_COMMENT;
		TAB;
		NOTE;
		STRING1;
		STRING2;
		DIRECTIVE; 
		KEYWORD1;
		KEYWORD2;
		KEYWORD3;
		TYPE1;
		TYPE2;
		CONSTANT1;
		CONSTANT2;
		CONSTANT3;
		NUMBER;
		EOL_SPACE;
		DECLARATION;
		OTHER1;
		COUNT;
	}
	COUNT :: Kind.COUNT;
	Flags :: enum_flags {
		IS_WORD;
		NONE :: 0;
	}
	Match_Kind :: enum {
		NORMAL;
		MULTILINE_START_END;
	}
	match_kind: Match_Kind = .NORMAL;
	flags: Flags = .NONE;
	color: s8 = -1; // 
	// .NORMAL
	match: string;
	match_suffix: string; // not captured
	// .START_END_MULTILINE
	multiline_start: string;
	multiline_end: string;
	multiline_start_regex: Uniform.Regexp;
	multiline_end_regex: Uniform.Regexp;
	// replace is unused ..
	replace: string; // ** this isn't a direct replace, but it keeps length ** 
	is_compiled: bool = false;
	regex: Uniform.Regexp;
}

// has reasonable defaults  ?
Syntax :: struct {
	elements: [Syntax_Element.COUNT]Syntax_Element;
	using Syntax_Element.Kind;
	elements[KEYWORD1].color = 13; // orange
	elements[KEYWORD2].color = 14; // 14 - dark green.. this is for less special keywords?
	elements[KEYWORD3].color = 13; // 13 - orange, 14 - (it/it_index) dark green
	elements[TYPE1].color = 3; // cyan
	elements[TYPE2].color = 3; // cyan
	elements[CONSTANT1].color = 12; // white
	elements[CONSTANT2].color = 12; // white
	elements[CONSTANT3].color = 12; // white
	elements[STRING1].color = 12; // white
	elements[STRING2].color = 12; // white
	elements[DIRECTIVE].color = 5; // purple 
	elements[NUMBER].color = 12; // white
	elements[TAB].color = 12; // white
	elements[COMMENT].color = 4; // grey
	elements[MULTILINE_COMMENT].color = 4; // grey
	elements[DECLARATION].color = 14; // dark green (24 or 30 or 6?)
	elements[NOTE].color = 6; // dark green (24 or 30 or 6?)
	elements[EOL_SPACE].color = 4; // grey, same as comment
	elements[OTHER1].color = 5; // dark purple - this is for bash `ls`
	//
	elements[KEYWORD1].flags = .IS_WORD;
	elements[KEYWORD2].flags = .IS_WORD;
	elements[KEYWORD3].flags = .IS_WORD;
	elements[TYPE1].flags = .IS_WORD;
	elements[TYPE2].flags = .IS_WORD;
	elements[CONSTANT1].flags = .IS_WORD;
	elements[CONSTANT2].flags = .IS_WORD;
	elements[CONSTANT3].flags = .IS_WORD;
	elements[NUMBER].flags = .IS_WORD;
	normal_color: s8 = 0;
	is_compiled: bool = false;
	regex: Uniform.Regexp;
	extension: string;
}

get_syntax_for_filename :: (filename: string) -> *Syntax {
	if context.edit.syntaxes.count == 0 {
		{
			// Empty
			syntax := New(Syntax);
			syntax.extension = "";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Jai
			syntax := New(Syntax);
			syntax.* = create_jai_syntax();
			syntax.extension = "jai";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Bash
			syntax := New(Syntax);
			syntax.* = create_bash_syntax();
			syntax.extension = "sh";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Mike
			syntax := New(Syntax);
			syntax.* = create_mike_syntax();
			syntax.extension = "mike";
			array_add(*context.edit.syntaxes, syntax);
		}
	}
	ext := path_to_extension(filename);
	for context.edit.syntaxes {
		if it.extension == ext
			return it;
	}
	return context.edit.syntaxes[0];
}

path_to_extension :: (_path: string) -> string {
	path := _path;
	idx1 := find_index_from_right(path, #char "/");
	if idx1 >= 0
		path = advance(path, idx1+1);
	if path == {
		case ".bashrc";
			return "sh";
	}
	idx2 := find_index_from_right(path, #char ".");
	if idx2 >= 0
		return advance(path, idx2+1);
	else
		return "";
}

create_mike_syntax :: () -> Syntax {
	using syntax: Syntax;
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[NUMBER].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
	], "|");
	//syntax.elements[COMMENT].match = "#.*?$";
	//
	syntax.elements[CONSTANT1].flags |= .IS_WORD;
	syntax.elements[NUMBER].flags |= .IS_WORD;
	compile_syntax(*syntax);
	return syntax;
}

create_bash_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"alias",
		"export",
		"set",
		"unset",
		"function",
		"if",
		"then",
		"fi",
		"return",
		"for",
		"while",
		"do",
		"done",
		"else",
		"in",
		"break",
	], "|");
	// these are bash builtins?
	elements[KEYWORD2].match = #run join(.. .[
		"trap",
		"eval",
		"ulimit",
		"cd",
		"shopt",
		"echo",
		"true",
		"false",
	], "|");
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)";
	syntax.elements[OTHER1].match = "`(?:[^`\\\\]|\\\\.)*(?:`|$)";
	//syntax.elements[NUMBER].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "#.*?$";
	//
	compile_syntax(*syntax);
	return syntax;
}

create_jai_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"cast",
		"using(?:\\,\\w+)?",
		"if",
		"else",
		"then",
		"context",
		"return",
		"continue",
		"break",
		"case",
		"struct",
		"xx",
		"defer",
		"enum",
		"enum_flags",
		"operator",
		"inline",
		"interface",
		"size_of",
		"type_of",
		"type_info",
		"push_context(?:\\,\\w+)?",
		"ifx",
	], "|");
	syntax.elements[TYPE1].match = #run join(.. .[
		"int",
		"s64",
		"s32",
		"s16",
		"s8",
		"u64",
		"u32",
		"u16",
		"u8",
		"float",
		"float32",
		"float64",
		"Type",
		"void",
		"bool",
		"string",
	], "|");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
		"null",
	], "|");
	syntax.elements[KEYWORD3].match = #run join(.. .[
		"it",
		"it_index"
	], "|");
	//elements[DECLARATION].match_suffix = "\\s*:\\s*(?:\\**[a-zA-Z_]\\w*+\\s*;|(?:\\**[a-zA-Z_]\\w*+)?=[^;]*;)";
	//elements[DECLARATION].match_suffix = #run sprint("(?:\\s*\\,\\s*\\w+){0}\\s*:\\s*(?:%|\\=|#type)", decl_type);
	elements[DECLARATION].match = "[a-zA-Z_]\\w*+";
	decl_type :: "[\\[\\]\\w\\.\\*]+[^\\[\\]\\w\\.\\*]";
	elements[DECLARATION].match_suffix = "(?:\\s*\\,\\s*\\w+)*\\s*:";
	syntax.elements[TYPE2].match = "[A-Z]\\w*[a-z]\\w*+";
	syntax.elements[DIRECTIVE].match = "#\\w*(?:\\,\\w*+)*+";
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[NUMBER].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "//.*?$";
	// doesn't support nested multiline comments ...
	syntax.elements[MULTILINE_COMMENT].match_kind = .MULTILINE_START_END;
	syntax.elements[MULTILINE_COMMENT].multiline_start = "/\\*";
	syntax.elements[MULTILINE_COMMENT].multiline_end = "\\*/";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z_][A-Z_\\d]*+|\\$\\w++)";
	elements[CONSTANT3].match_suffix = #run sprint("\\s*:\\s*(?:%)?\\w*:", decl_type);
	syntax.elements[CONSTANT3].match = elements[DECLARATION].match;
	syntax.elements[NOTE].match = "@\\w+";
	// I'd want EOL_SPACE to match line chars *before* the cursor
	//syntax.elements[EOL_SPACE].match = " +$";
	//syntax.elements[EOL_SPACE].replace = "-";
	//
	compile_syntax(*syntax);
	return syntax;
}

compile_syntax :: (using syntax: *Syntax) {
	regex_str: string = ---;
	{
		builder: String_Builder;
		builder.allocator = temp;
		// match anything (lazy) + 1 or more non word character or start of line
		//print(*builder, "(.*?(?:^|\\W))"); // CAN'T DO THIS
		print(*builder, "()"); 
		print(*builder, "(");
		for * syntax.elements {
			defer {
				if it_index + 1 != syntax.elements.count
					print(*builder, "|");
			}
			if it.match == "" {
				// never matches
				print(*builder, "(%)", "asdhujsgfuyrsdghuieqw3h");
				continue;
			}
			extra_end := "";
			extra_start := "";
			//log("% % %", it_index, it.flags, extra);
			if it.flags & .IS_WORD {
				// is word
				extra_end = "(?:\\W|$)"; 
				extra_start = "(?:^|\\W)"; // CAN'T DO WITH THIS
			}
			s := tprint("%(%)%0%", extra_start, it.match, it.match_suffix, extra_end);
			print(*builder, "%", s);
		}
		print(*builder, ")");
		regex_str = builder_to_string(*builder,, allocator=temp);
		#if 1 {
			log("regex str: %\n", regex_str);
		}
	}
	regex, is_compiled = Uniform.compile(regex_str);
	// now, compile each element seperately...
	for * syntax.elements {
		if it.match_kind == .NORMAL {
			if !it.match
				continue;
			extra_start := "";
			extra_end := "";
			if it.flags & .IS_WORD {
				// is word
				extra_start = "(?:^|\\W)"; 
				extra_end = "(?:\\W|$)"; 
			}
			regex_str := tprint("%(%)%0%", extra_start, it.match, it.match_suffix, extra_end);
			it.regex, it.is_compiled = Uniform.compile(regex_str);
		} else if it.match_kind == .MULTILINE_START_END {
			if !it.multiline_start || !it.multiline_end
				continue;
			re_start, ok_start := Uniform.compile(tprint("%", it.multiline_start));
			re_end, ok_end := Uniform.compile(tprint("%", it.multiline_end));
			if ok_start && ok_end { // @Leak if only half compiles
				it.is_compiled = true;
				it.multiline_start_regex = re_start;
				it.multiline_end_regex = re_end;
			} else {
				assert(false, "error thing..");
			}
		}
	}
}