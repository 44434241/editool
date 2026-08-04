
Syntax_Element :: struct {
	// kind is an index..
	Kind :: enum {
		// in order of priority ?
		DEFAULT;
		COMMENT;
		MULTILINE_COMMENT;
		MULTILINE_STRING;
		TAB;
		NOTE;
		STRING1;
		STRING2;
		STRING3;
		DIRECTIVE; 
		KEYWORD1;
		KEYWORD2;
		KEYWORD3;
		CONSTANT1;
		TYPE1;
		TYPE2;
		CONSTANT2;
		CONSTANT3;
		NUMBER1;
		NUMBER2;
		EOL_SPACE;
		DECLARATION;
		OTHER1;
		OTHER2;
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
	elements[STRING3].color = 12; // white
	elements[MULTILINE_STRING].color = 12; // white
	elements[DIRECTIVE].color = 5; // purple 
	elements[NUMBER1].color = 12; // white
	elements[NUMBER2].color = 12; // white
	elements[TAB].color = 12; // white
	elements[COMMENT].color = 4; // grey
	elements[MULTILINE_COMMENT].color = 4; // grey
	elements[DECLARATION].color = 14; // dark green (24 or 30 or 6?)
	elements[NOTE].color = 6; // dark green (24 or 30 or 6?)
	elements[EOL_SPACE].color = 4; // grey, same as comment
	elements[OTHER1].color = 5; // dark purple - this is for bash `ls`
	elements[OTHER2].color = 12; // white? - this is for bash $VARIABLE
	//
	elements[KEYWORD1].flags = .IS_WORD;
	elements[KEYWORD2].flags = .IS_WORD;
	elements[KEYWORD3].flags = .IS_WORD;
	elements[TYPE1].flags = .IS_WORD;
	elements[TYPE2].flags = .IS_WORD;
	elements[CONSTANT1].flags = .IS_WORD;
	elements[CONSTANT2].flags = .IS_WORD;
	elements[CONSTANT3].flags = .IS_WORD;
	elements[NUMBER1].flags = .IS_WORD;
	elements[NUMBER2].flags = .IS_WORD;
	normal_color: s8 = 0;
	is_compiled: bool = false;
	regex: Uniform.Regexp;
	filetype: string;
}

get_syntax_for_filetype :: (filetype: string) -> *Syntax {
	if context.edit.syntaxes.count == 0 {
		{
			// Empty
			syntax := New(Syntax);
			syntax.filetype = "";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Jai
			syntax := New(Syntax);
			syntax.* = create_jai_syntax();
			syntax.filetype = "jai";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Bash
			syntax := New(Syntax);
			syntax.* = create_bash_syntax();
			syntax.filetype = "sh";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Mike
			syntax := New(Syntax);
			syntax.* = create_mike_syntax();
			syntax.filetype = "mike";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Config
			syntax := New(Syntax);
			syntax.* = create_config_syntax();
			syntax.filetype = "config";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Glsl
			syntax := New(Syntax);
			syntax.* = create_glsl_syntax();
			syntax.filetype = "glsl";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// C
			syntax := New(Syntax);
			syntax.* = create_c_syntax();
			syntax.filetype = "c";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Lua
			syntax := New(Syntax);
			syntax.* = create_lua_syntax();
			syntax.filetype = "lua";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Vim
			syntax := New(Syntax);
			syntax.* = create_vim_syntax();
			syntax.filetype = "vim";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Python
			syntax := New(Syntax);
			syntax.* = create_python_syntax();
			syntax.filetype = "py";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Obj
			syntax := New(Syntax);
			syntax.* = create_obj_syntax();
			syntax.filetype = "obj";
			array_add(*context.edit.syntaxes, syntax);
		}
		{
			// Dockerfile
			syntax := New(Syntax);
			syntax.* = create_dockerfile_syntax();
			syntax.filetype = "dockerfile";
			array_add(*context.edit.syntaxes, syntax);
		}
	}
	for context.edit.syntaxes {
		if it.filetype == filetype
			return it;
	}
	return context.edit.syntaxes[0];
}

get_syntax_for_filename :: (filename: string) -> *Syntax {
	return get_syntax_for_filetype(path_to_filetype(filename));
}

path_to_filetype :: (_path: string) -> string {
	path := _path;
	idx1 := find_index_from_right(path, #char "/");
	if idx1 >= 0
		path = advance(path, idx1+1);
	if path == {
		case ".bashrc"; #through;
		case ".xinitrc"; #through;
		case ".bashrc_local";
			return "sh";
		case ".vimrc";
			return "vim";
		case "PKGBUILD"; #through;
		case "fstab"; #through;
		case ".env"; #through;
		case "sshd_config";
			return "config";
	} 
	idx2 := find_index_from_right(path, #char ".");
	if idx2 >= 0 {
		ext := advance(path, idx2+1);
		if ext == {
			case "toml"; #through;
			case "yaml"; #through;
			case "yml"; #through;
			case "example"; #through;
			case "conf";
				return "config"; 
			case "cs"; #through; // C# !!
			case "ino"; #through; // arduino
			case "c"; #through;
			case "cpp"; #through;
			case "h"; #through;
			case "hpp";
				return "c"; 
			case;
				return ext;
		}
	} else {
		return path; // we use full file name as the "file type"
	}
}

create_mike_syntax :: () -> Syntax {
	using syntax: Syntax;
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
	], "|");
	//syntax.elements[COMMENT].match = "#.*?$";
	//
	syntax.elements[CONSTANT1].flags |= .IS_WORD;
	syntax.elements[NUMBER1].flags |= .IS_WORD;
	compile_syntax(*syntax);
	return syntax;
}

create_config_syntax :: () -> Syntax {
	using syntax: Syntax;
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "#.*?$";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)*"; // supports '1.0.0.0'
	//
	compile_syntax(*syntax);
	return syntax;
}

create_obj_syntax :: () -> Syntax {
	using syntax: Syntax;
	syntax.elements[COMMENT].match = "#.*?$";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)*"; // supports '1.0.0.0'
	elements[KEYWORD1].match = #run join(.. .[
		"^v",
		"^vt",
		"^vn",
		"^f",
		"^s", 
		"^usemtl",
		"^mtllib",
		"^o",
	], "|");
	//
	compile_syntax(*syntax);
	return syntax;
}

create_dockerfile_syntax :: () -> Syntax {
	using syntax: Syntax;
	kw :: (s: string) -> string #compile_time {
		buf := NewArray(s.count * 4 + 1, u8);
		buf[0] = #char "^";
		for s {
			assert(to_lower(it) != to_upper(it));
			buf[1+it_index*4+0] = #char "[";
			buf[1+it_index*4+1] = to_lower(it);
			buf[1+it_index*4+2] = to_upper(it);
			buf[1+it_index*4+3] = #char "]";
		}
		return cast(string)buf;
	}
	elements[KEYWORD1].match = #run join(.. .[
		#run kw("add"),
		#run kw("arg"),
		#run kw("cmd"),
		#run kw("copy"),
		#run kw("entrypoint"),
		#run kw("env"),
		#run kw("expose"),
		#run kw("from"),
		#run kw("healthcheck"),
		#run kw("label"),
		#run kw("maintainer"),
		#run kw("onbuild"),
		#run kw("run"),
		#run kw("shell"),
		#run kw("stopsignal"),
		#run kw("user"),
		#run kw("volume"),
		#run kw("workdir"),
	], "|");
	// these are bash builtins?
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)";
	//
	syntax.elements[OTHER2].match = "\\$[A-Za-z_]+";
	syntax.elements[OTHER1].match = "`(?:[^`\\\\]|\\\\.)*(?:`|$)";
	//syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "#.*?$";
	//
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
	syntax.elements[OTHER2].match = "\\$[A-Za-z_]+"; // variable.. idk if i should call this a keyword
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "#.*?$";
	//
	compile_syntax(*syntax);
	return syntax;
}

create_vim_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"fu!",
		"func!",
		"function",
		"if",
		"elseif",
		"endif",
		"else",
		"endfunction",
		"let",
		"return",
		"while",
		"for",
		"endfor",
	], "|");
	elements[KEYWORD2].match = #run join("^(?:", join(.. .[
		"require",
		// command names
		"set",
		"lua",
		"source",
		"au",
		"autocmd",
		"nnoremap",
		"colorscheme",
		"syntax",
		"filetype",
	], "|"), ")");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
	], "|");
	// these are bash builtins?
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)";
	//syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	//
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[COMMENT].match = "\".*?$";
	compile_syntax(*syntax);
	return syntax;
}

create_lua_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"local",
		"function",
		"if",
		"then",
		"end",
		"if",
		"then",
		"return",
		"for",
		"while",
		"end",
		"else",
		"break",
	], "|");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
	], "|");
	// these are bash builtins?
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)";
	//syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	//
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[COMMENT].match = "--.*?$";
	compile_syntax(*syntax);
	return syntax;
}

create_glsl_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"if",
		"else",
		"then",
		"return",
		"continue",
		"break",
		"struct",
		//
		"const",
		"layout",
		"location",
		"uniform",
		"core",
		"set",
		"binding",
		"location",
		"in",
		"out",
		"const",
		"buffer",
		"discard",
		"flat",
		"local_size_[xyz]",
		"readonly",
	], "|");
	syntax.elements[TYPE1].match = #run join(.. .[
		// int
		"u?int",
		"bool",
		"float",
		"[iub]?vec[234]",
		// these ints are not actually from glsl
		"[i]?mat[234]",
		//
		"void",
		"u?sampler2D",
	], "|");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
	], "|");
	syntax.elements[KEYWORD2].match = #run join(.. .[
		"texture",
		//
		"length",
		"inverse",
		"transpose",
		"normalize",
		"abs",
		"cos",
		"sin",
		"asin",
		"acos",
		"sqrt",
		"clamp",
		"round",
		"pow",
		"dot",
		"sign",
		"mod",
		"mix",
		//
		"atomicAdd",
		"atomicCompSwap",
		// gl_Position
		"gl_\\w*", // are we do i wanna use wildcard or hardcode things??
	], "|");
	syntax.elements[TYPE2].match = "_?[A-Z]\\w*[a-z]\\w*+";
	syntax.elements[DIRECTIVE].match = "#\\w*(?:\\,\\w*+)*+";
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "//.*?$";
	syntax.elements[MULTILINE_COMMENT].match_kind = .MULTILINE_START_END;
	syntax.elements[MULTILINE_COMMENT].multiline_start = "/\\*";
	syntax.elements[MULTILINE_COMMENT].multiline_end = "\\*/";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z_][A-Z_\\d]*+|\\$\\w++)";
	//
	compile_syntax(*syntax);
	return syntax;
}

create_python_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"if",
		"else",
		"then",
		"return",
		"continue",
		"break",
		"class",
		"def",
		"from",
		"import",
		"as",
		"try",
		"except",
		"is",
		"not",
		"and",
		"in",
		"yield",
		"async",
		"await",
		"pass",
		"raise", // throw
		"elif",
		"with",
		"del",
		"assert",
	], "|");
	syntax.elements[TYPE1].match = #run join(.. .[
		// int
		"int",
		"str",
		"bool",
		"type",
		"float",
	], "|");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"True",
		"False",
		"None",
	], "|");
	syntax.elements[KEYWORD2].match = #run join(.. .[
		"self",
		"object",
		// builtin procs:
		"len",
		"isinstance",
		"hasattr",
		"getattr",
		"set",
		"range",
		"ord",
		"chr",
		"__\\w+__", // special underscore things (c/cpp)
	], "|");
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "'(?:[^'\\\\]|\\\\.)*(?:'|$)"; // 'aad'
	syntax.elements[MULTILINE_STRING].match_kind = .MULTILINE_START_END;
	syntax.elements[MULTILINE_STRING].multiline_start = "\"\"\"";
	syntax.elements[MULTILINE_STRING].multiline_end = "\"\"\"";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?f?";
	syntax.elements[NUMBER2].match = "0[xbo][0-9a-fA-F_]*";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "#.*?$";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z_][A-Z_\\d]*+|\\$\\w++)";
	syntax.elements[NOTE].match = "@\\w+";
	syntax.elements[TYPE2].match = "_?[A-Z]\\w*[a-z]\\w*+"; // most python types are LikeThis
	//
	compile_syntax(*syntax);
	return syntax;
}

// this is a mishmash of c/cpp/c# because i cbf to create a separate syntax for all of them
create_c_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"if",
		"else",
		"then",
		"return",
		"continue",
		"break",
		"struct",
		//
		"do",
		"static",
		"const",
		"extern",
		"typedef",
		"case",
		"switch",
		"default",
		"inline",
		"enum",
		// cpp:
		"using",
		"public",
		"private",
		"protected",
		"virtual",
		"class",
		"new",
		// csharp:
		"sealed",
		"readonly",
		"var",
		"is",
		"as",
		"event",
		"out",
	], "|");
	syntax.elements[TYPE1].match = #run join(.. .[
		// int
		"int",
		"long",
		"bool",
		"void",
		"unsigned",
		"char",
		"short",
		"float",
		"double",
		"u?int8_t",
		"u?int16_t",
		"u?int32_t",
		"u?int64_t",
		// csharp
		"string",
	], "|");
	syntax.elements[CONSTANT1].match = #run join(.. .[
		"true",
		"false",
		"null",
		"__\\w+", // special underscore things (c/cpp)
	], "|");
	syntax.elements[KEYWORD2].match = #run join(.. .[
		"sizeof",
	], "|");
	syntax.elements[DIRECTIVE].match = "#\\w*(?:\\,\\w*+)*+";
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[STRING2].match = "<(?:[^>\\\\]|\\\\.)*>\\w*$";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?f?";
	syntax.elements[NUMBER2].match = "0[xbo][0-9a-fA-F_]*";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "//.*?$";
	syntax.elements[MULTILINE_COMMENT].match_kind = .MULTILINE_START_END;
	syntax.elements[MULTILINE_COMMENT].multiline_start = "/\\*";
	syntax.elements[MULTILINE_COMMENT].multiline_end = "\\*/";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z_][A-Z_\\d]*+|\\$\\w++)";
	//
	compile_syntax(*syntax);
	return syntax;
}

create_jai_syntax :: () -> Syntax {
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"cast(?:\\,\\w+)?",
		"using(?:\\,\\w+)?",
		"if",
		"else",
		"then",
		"context",
		"return",
		"continue",
		"break",
		"remove",
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
		"union",
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
		"big_float", // my thing !
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
	elements[DECLARATION].match = "[a-zA-Z_]\\w*+";
	decl_type :: "[\\(\\)#\\[\\]\\w\\.\\*]+[^\\[\\]\\w\\.\\*]";
	elements[DECLARATION].match_suffix = "(?:\\s*\\,\\s*\\w+)*\\s*:";
	syntax.elements[TYPE2].match = "_?[A-Z]\\w*[a-z]\\w*+";
	syntax.elements[DIRECTIVE].match = "#\\w*(?:\\,\\w*+)*+";
	syntax.elements[STRING1].match = "\"(?:[^\"\\\\]|\\\\.)*(?:\"|$)";
	syntax.elements[NUMBER1].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[NUMBER2].match = "0[xbo][0-9a-fA-F_]*";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "//.*?$";
	// doesn't support nested multiline comments ...
	syntax.elements[MULTILINE_COMMENT].match_kind = .MULTILINE_START_END;
	syntax.elements[MULTILINE_COMMENT].multiline_start = "/\\*";
	syntax.elements[MULTILINE_COMMENT].multiline_end = "\\*/";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z_][A-Z_\\d]*+|\\$\\w++)"; // capitalized word
	elements[CONSTANT3].match_suffix = #run sprint("\\s*:\\s*(?:%)?\\w*:", decl_type);
	syntax.elements[CONSTANT3].match = elements[DECLARATION].match;
	syntax.elements[NOTE].match = "@\\w+";
	// TODO: I'd want EOL_SPACE to match line chars *before* the cursor
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