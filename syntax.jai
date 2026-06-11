
// todo: '@ asd' notes

// has reasonable defaults
Syntax_Element :: struct {
	Kind :: enum {
		// in order of priority ?
		DEFAULT;
		TAB;
		DIRECTIVE; 
		KEYWORD1;
		KEYWORD2;
		KEYWORD3;
		TYPE1;
		TYPE2;
		CONSTANT1;
		CONSTANT2;
		CONSTANT3;
		STRING;
		NUMBER;
		COMMENT;
		DECLARATION;
		EOL_SPACE;
		COUNT;
	}
	Flags :: enum_flags {
		IS_NOT_WORD; // between 
		NONE :: 0;
	}
	flags: Flags = .NONE;
	COUNT :: Kind.COUNT;
	match: string;
	match_suffix: string; // not captured
	color: s32 = -1; // 
	replace: string; // ** this isn't a direct replace, but it keeps length ** 
}

Syntax :: struct {
	elements: [Syntax_Element.COUNT]Syntax_Element;
	using Syntax_Element.Kind;
	elements[KEYWORD1].color = 13; // orange
	elements[KEYWORD2].color = 0;
	elements[KEYWORD3].color = 14; // (it/it_index) dark green
	elements[TYPE1].color = 3; // cyan
	elements[TYPE2].color = 3; // cyan
	elements[CONSTANT1].color = 12; // white
	elements[CONSTANT2].color = 12; // white
	elements[CONSTANT3].color = 12; // white
	elements[STRING].color = 12; // white
	elements[DIRECTIVE].color = 5; // purple 
	elements[NUMBER].color = 12; // white
	elements[TAB].color = 12; // white
	elements[COMMENT].color = 4; // grey
	elements[DECLARATION].color = 14; // dark gren (24 or 30 or 6?)
	elements[EOL_SPACE].color = 4; // grey, same as comment
	normal_color: s32 = 0;
	is_compiled: bool = false;
	regex: Uniform.Regexp;
}

compile_syntax :: (using syntax: *Syntax) {
	regex_str: string = ---;
	{
		builder: String_Builder;
		builder.allocator = temp;
		// match anything (lazy) + 1 or more non word character or start of line
		//print(*builder, "(.*?(?:^|\\W))"); // CAN'T DO THIS
		print(*builder, "(.*?)"); 
		print(*builder, "(");
		for syntax.elements {
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
			if it.flags & .IS_NOT_WORD == 0 {
				// is word
				extra_end = "(?:\\W|$)"; 
				extra_start = "(?:^|\\W)"; // CAN'T DO WITH THIS
			}
			print(*builder, "%(%)%0%", extra_start, it.match, it.match_suffix, extra_end);
		}
		print(*builder, ")");
		regex_str = builder_to_string(*builder,, allocator=temp);
		#if 1 {
			log("regex str: %\n", regex_str);
		}
	}
	regex, is_compiled = Uniform.compile(regex_str);
}

get_jai_syntax :: () -> Syntax {
	// TODO: multiple variable declarations like "a, b: int;" are not supported
	// @ notes
	using syntax: Syntax;
	elements[KEYWORD1].match = #run join(.. .[
		"for",
		"while",
		"cast",
		"using",
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
	elements[DECLARATION].match = "[a-zA-Z_]\\w*+";
	decl_type :: "[\\[\\]\\w\\.\\*]+[^\\[\\]\\w\\.\\*]";
	//elements[DECLARATION].match_suffix = "\\s*:\\s*(?:\\**[a-zA-Z_]\\w*+\\s*;|(?:\\**[a-zA-Z_]\\w*+)?=[^;]*;)";
	elements[DECLARATION].match_suffix = #run sprint("\\s*:\\s*(?:%|\\=)", decl_type);
	syntax.elements[TYPE2].match = "[A-Z]\\w*[a-z]\\w*+";
	syntax.elements[DIRECTIVE].match = "#\\w*(?:\\,\\w*+)*+";
	syntax.elements[STRING].match = "\"(?:[^\"])*\"";
	syntax.elements[NUMBER].match = "\\d+(?:\\.\\d+)?";
	syntax.elements[TAB].match = "\\t++";
	syntax.elements[COMMENT].match = "//.*?$";
	syntax.elements[CONSTANT2].match = "(?:\\$?[A-Z][A-Z_]*+|\\$\\w++)";
	syntax.elements[CONSTANT3].match = elements[DECLARATION].match;
	elements[CONSTANT3].match_suffix = #run sprint("\\s*:\\s*(?:%)?\\w*:", decl_type);
	// I'd want EOL_SPACE to match line chars *before* the cursor
	//syntax.elements[EOL_SPACE].match = " +$";
	//syntax.elements[EOL_SPACE].replace = "-";
	//
	elements[STRING].flags |= .IS_NOT_WORD;
	//elements[NUMBER].flags |= .IS_NOT_WORD;
	elements[TAB].flags |= .IS_NOT_WORD;
	elements[COMMENT].flags |= .IS_NOT_WORD;
	elements[TYPE2].flags |= .IS_NOT_WORD;
	elements[CONSTANT2].flags |= .IS_NOT_WORD;
	elements[CONSTANT3].flags |= .IS_NOT_WORD;
	elements[EOL_SPACE].flags |= .IS_NOT_WORD;
	compile_syntax(*syntax);
	return syntax;
}
