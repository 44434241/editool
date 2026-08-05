//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



NCURSES_WIDECHAR :: 1;
CURSES :: 1;
CURSES_H :: 1;

NCURSES_VERSION_MAJOR :: 6;
NCURSES_VERSION_MINOR :: 6;
NCURSES_VERSION_PATCH :: 20251230;

NCURSES_VERSION :: "6.6";

NCURSES_MOUSE_VERSION :: 2;

NCURSES_ENABLE_STDBOOL_H :: 1;

NCURSES_ATTR_T :: s32;

NCURSES_OPAQUE :: 1;
NCURSES_OPAQUE_FORM :: 1;
NCURSES_OPAQUE_MENU :: 1;
NCURSES_OPAQUE_PANEL :: 1;

NCURSES_WATTR_MACROS :: 0;

NCURSES_REENTRANT :: 0;

NCURSES_SIGWINCH :: 1;

NCURSES_INTEROP_FUNCS :: 1;

NCURSES_TPARM_VARARGS :: 1;

NCURSES_TPARM_ARG :: s64;

NCURSES_WCWIDTH_GRAPHICS :: 1;

NCURSES_CH_T :: cchar_t;

TRUE :: 1;

FALSE :: 0;

WA_NORMAL :: A_NORMAL;

COLOR_BLACK :: 0;
COLOR_RED :: 1;
COLOR_GREEN :: 2;
COLOR_YELLOW :: 3;
COLOR_BLUE :: 4;
COLOR_MAGENTA :: 5;
COLOR_CYAN :: 6;
COLOR_WHITE :: 7;

ERR :: -1;

OK :: 0;

_SUBWIN :: 0x01;
_ENDLINE :: 0x02;
_FULLWIN :: 0x04;
_SCROLLWIN :: 0x08;
_ISPAD :: 0x10;
_HASMOVED :: 0x20;
_WRAPPED :: 0x40;

_NOCHANGE :: -1;

_NEWINDEX :: -1;

CCHARW_MAX :: 5;

NCURSES_EXT_COLORS :: 20251230;

NCURSES_EXT_FUNCS :: 20251230;

NCURSES_XNAMES :: 1;

NCURSES_SP_FUNCS :: 20251230;

NCURSES_ATTR_SHIFT :: 8;

A_NORMAL :: 1 - 1;

KEY_CODE_YES :: 0x100 /* 0400 */;
KEY_MIN :: 0x101 /* 0401 */;
KEY_BREAK :: 0x101 /* 0401 */;
KEY_SRESET :: 0x158 /* 0530 */;
KEY_RESET :: 0x159 /* 0531 */;

KEY_DOWN :: 0x102 /* 0402 */;
KEY_UP :: 0x103 /* 0403 */;
KEY_LEFT :: 0x104 /* 0404 */;
KEY_RIGHT :: 0x105 /* 0405 */;
KEY_HOME :: 0x106 /* 0406 */;
KEY_BACKSPACE :: 0x107 /* 0407 */;
KEY_F0 :: 0x108 /* 0410 */;

KEY_DL :: 0x148 /* 0510 */;
KEY_IL :: 0x149 /* 0511 */;
KEY_DC :: 0x14a /* 0512 */;
KEY_IC :: 0x14b /* 0513 */;
KEY_EIC :: 0x14c /* 0514 */;
KEY_CLEAR :: 0x14d /* 0515 */;
KEY_EOS :: 0x14e /* 0516 */;
KEY_EOL :: 0x14f /* 0517 */;
KEY_SF :: 0x150 /* 0520 */;
KEY_SR :: 0x151 /* 0521 */;
KEY_NPAGE :: 0x152 /* 0522 */;
KEY_PPAGE :: 0x153 /* 0523 */;
KEY_STAB :: 0x154 /* 0524 */;
KEY_CTAB :: 0x155 /* 0525 */;
KEY_CATAB :: 0x156 /* 0526 */;
KEY_ENTER :: 0x157 /* 0527 */;
KEY_PRINT :: 0x15a /* 0532 */;
KEY_LL :: 0x15b /* 0533 */;
KEY_A1 :: 0x15c /* 0534 */;
KEY_A3 :: 0x15d /* 0535 */;
KEY_B2 :: 0x15e /* 0536 */;
KEY_C1 :: 0x15f /* 0537 */;
KEY_C3 :: 0x160 /* 0540 */;
KEY_BTAB :: 0x161 /* 0541 */;
KEY_BEG :: 0x162 /* 0542 */;
KEY_CANCEL :: 0x163 /* 0543 */;
KEY_CLOSE :: 0x164 /* 0544 */;
KEY_COMMAND :: 0x165 /* 0545 */;
KEY_COPY :: 0x166 /* 0546 */;
KEY_CREATE :: 0x167 /* 0547 */;
KEY_END :: 0x168 /* 0550 */;
KEY_EXIT :: 0x169 /* 0551 */;
KEY_FIND :: 0x16a /* 0552 */;
KEY_HELP :: 0x16b /* 0553 */;
KEY_MARK :: 0x16c /* 0554 */;
KEY_MESSAGE :: 0x16d /* 0555 */;
KEY_MOVE :: 0x16e /* 0556 */;
KEY_NEXT :: 0x16f /* 0557 */;
KEY_OPEN :: 0x170 /* 0560 */;
KEY_OPTIONS :: 0x171 /* 0561 */;
KEY_PREVIOUS :: 0x172 /* 0562 */;
KEY_REDO :: 0x173 /* 0563 */;
KEY_REFERENCE :: 0x174 /* 0564 */;
KEY_REFRESH :: 0x175 /* 0565 */;
KEY_REPLACE :: 0x176 /* 0566 */;
KEY_RESTART :: 0x177 /* 0567 */;
KEY_RESUME :: 0x178 /* 0570 */;
KEY_SAVE :: 0x179 /* 0571 */;
KEY_SBEG :: 0x17a /* 0572 */;
KEY_SCANCEL :: 0x17b /* 0573 */;
KEY_SCOMMAND :: 0x17c /* 0574 */;
KEY_SCOPY :: 0x17d /* 0575 */;
KEY_SCREATE :: 0x17e /* 0576 */;
KEY_SDC :: 0x17f /* 0577 */;
KEY_SDL :: 0x180 /* 0600 */;
KEY_SELECT :: 0x181 /* 0601 */;
KEY_SEND :: 0x182 /* 0602 */;
KEY_SEOL :: 0x183 /* 0603 */;
KEY_SEXIT :: 0x184 /* 0604 */;
KEY_SFIND :: 0x185 /* 0605 */;
KEY_SHELP :: 0x186 /* 0606 */;
KEY_SHOME :: 0x187 /* 0607 */;
KEY_SIC :: 0x188 /* 0610 */;
KEY_SLEFT :: 0x189 /* 0611 */;
KEY_SMESSAGE :: 0x18a /* 0612 */;
KEY_SMOVE :: 0x18b /* 0613 */;
KEY_SNEXT :: 0x18c /* 0614 */;
KEY_SOPTIONS :: 0x18d /* 0615 */;
KEY_SPREVIOUS :: 0x18e /* 0616 */;
KEY_SPRINT :: 0x18f /* 0617 */;
KEY_SREDO :: 0x190 /* 0620 */;
KEY_SREPLACE :: 0x191 /* 0621 */;
KEY_SRIGHT :: 0x192 /* 0622 */;
KEY_SRSUME :: 0x193 /* 0623 */;
KEY_SSAVE :: 0x194 /* 0624 */;
KEY_SSUSPEND :: 0x195 /* 0625 */;
KEY_SUNDO :: 0x196 /* 0626 */;
KEY_SUSPEND :: 0x197 /* 0627 */;
KEY_UNDO :: 0x198 /* 0630 */;
KEY_MOUSE :: 0x199 /* 0631 */;

KEY_RESIZE :: 0x19a /* 0632 */;

KEY_MAX :: 0x1ff /* 0777 */;

_XOPEN_CURSES :: 1;

NCURSES_BUTTON_RELEASED :: 0x1 /* 001UL */;
NCURSES_BUTTON_PRESSED :: 0x2 /* 002UL */;
NCURSES_BUTTON_CLICKED :: 0x4 /* 004UL */;
NCURSES_DOUBLE_CLICKED :: 0x8 /* 010UL */;
NCURSES_TRIPLE_CLICKED :: 0x10 /* 020UL */;
NCURSES_RESERVED_EVENT :: 0x20 /* 040UL */;

TRACE_DISABLE :: 0x0000;
TRACE_TIMES :: 0x0001;
TRACE_TPUTS :: 0x0002;
TRACE_UPDATE :: 0x0004;
TRACE_MOVE :: 0x0008;
TRACE_CHARPUT :: 0x0010;
TRACE_ORDINARY :: 0x001F;
TRACE_CALLS :: 0x0020;
TRACE_VIRTPUT :: 0x0040;
TRACE_IEVENT :: 0x0080;
TRACE_BITS :: 0x0100;
TRACE_ICALLS :: 0x0200;
TRACE_CCALLS :: 0x0400;
TRACE_DATABASE :: 0x0800;
TRACE_ATTRS :: 0x1000;

TRACE_SHIFT :: 13;
TRACE_MAXIMUM :: (1 << TRACE_SHIFT) - 1;

chtype :: u32;
mmask_t :: u32;

NCURSES_BOOL :: u8;

acs_map: *chtype #elsewhere libncursesw;

screen :: struct {}
SCREEN :: screen;

_win_st :: struct {}
WINDOW :: _win_st;

attr_t :: chtype;

wint_t :: u32;

cchar_t :: struct {
    attr:      attr_t;
    chars:     [5] s32;

    ext_color: s32; /* color pair, must be more than 16-bits */
}

/*
* Curses uses a helper function.  Define our type for this to simplify
* extending it for the sp-funcs feature.
*/
NCURSES_OUTC :: #type (unknown0: s32) -> s32 #c_call;

/*
* Function prototypes.  This is the complete X/Open Curses list of required
* functions.  Those marked `generated' will have sources generated from the
* macro definitions later in this file, in order to satisfy XPG4.2
* requirements.
*/
addch :: (unknown0: chtype) -> s32 #foreign libncursesw;
addchnstr :: (unknown0: *chtype, unknown1: s32) -> s32 #foreign libncursesw;
addchstr :: (unknown0: *chtype) -> s32 #foreign libncursesw;
addnstr :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
addstr :: (unknown0: *u8) -> s32 #foreign libncursesw;
attroff :: (unknown0: s32) -> s32 #foreign libncursesw;
attron :: (unknown0: s32) -> s32 #foreign libncursesw;
attrset :: (unknown0: s32) -> s32 #foreign libncursesw;
attr_get :: (unknown0: *attr_t, unknown1: *s16, unknown2: *void) -> s32 #foreign libncursesw;
attr_off :: (unknown0: attr_t, unknown1: *void) -> s32 #foreign libncursesw;
attr_on :: (unknown0: attr_t, unknown1: *void) -> s32 #foreign libncursesw;
attr_set :: (unknown0: attr_t, unknown1: s16, unknown2: *void) -> s32 #foreign libncursesw;
baudrate :: () -> s32 #foreign libncursesw;
beep :: () -> s32 #foreign libncursesw;
bkgd :: (unknown0: chtype) -> s32 #foreign libncursesw;
bkgdset :: (unknown0: chtype) -> void #foreign libncursesw;
border :: (unknown0: chtype, unknown1: chtype, unknown2: chtype, unknown3: chtype, unknown4: chtype, unknown5: chtype, unknown6: chtype, unknown7: chtype) -> s32 #foreign libncursesw;
box :: (unknown0: *WINDOW, unknown1: chtype, unknown2: chtype) -> s32 #foreign libncursesw;
can_change_color :: () -> bool #foreign libncursesw;
cbreak :: () -> s32 #foreign libncursesw;
chgat :: (unknown0: s32, unknown1: attr_t, unknown2: s16, unknown3: *void) -> s32 #foreign libncursesw;
clear :: () -> s32 #foreign libncursesw;
clearok :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
clrtobot :: () -> s32 #foreign libncursesw;
clrtoeol :: () -> s32 #foreign libncursesw;
color_content :: (unknown0: s16, unknown1: *s16, unknown2: *s16, unknown3: *s16) -> s32 #foreign libncursesw;
color_set :: (unknown0: s16, unknown1: *void) -> s32 #foreign libncursesw;
COLOR_PAIR :: (unknown0: s32) -> s32 #foreign libncursesw;
copywin :: (unknown0: *WINDOW, unknown1: *WINDOW, unknown2: s32, unknown3: s32, unknown4: s32, unknown5: s32, unknown6: s32, unknown7: s32, unknown8: s32) -> s32 #foreign libncursesw;
curs_set :: (unknown0: s32) -> s32 #foreign libncursesw;
def_prog_mode :: () -> s32 #foreign libncursesw;
def_shell_mode :: () -> s32 #foreign libncursesw;
delay_output :: (unknown0: s32) -> s32 #foreign libncursesw;
delch :: () -> s32 #foreign libncursesw;
delscreen :: (unknown0: *SCREEN) -> void #foreign libncursesw;
delwin :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
deleteln :: () -> s32 #foreign libncursesw;
derwin :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> *WINDOW #foreign libncursesw;
doupdate :: () -> s32 #foreign libncursesw;
dupwin :: (unknown0: *WINDOW) -> *WINDOW #foreign libncursesw;
echo :: () -> s32 #foreign libncursesw;
echochar :: (unknown0: chtype) -> s32 #foreign libncursesw;
erase :: () -> s32 #foreign libncursesw;
endwin :: () -> s32 #foreign libncursesw;
erasechar :: () -> u8 #foreign libncursesw;
filter :: () -> void #foreign libncursesw;
flash :: () -> s32 #foreign libncursesw;
flushinp :: () -> s32 #foreign libncursesw;
getbkgd :: (unknown0: *WINDOW) -> chtype #foreign libncursesw;
getch :: () -> s32 #foreign libncursesw;
getnstr :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
getstr :: (unknown0: *u8) -> s32 #foreign libncursesw;
getwin :: (unknown0: *FILE) -> *WINDOW #foreign libncursesw;
halfdelay :: (unknown0: s32) -> s32 #foreign libncursesw;
has_colors :: () -> bool #foreign libncursesw;
has_ic :: () -> bool #foreign libncursesw;
has_il :: () -> bool #foreign libncursesw;
hline :: (unknown0: chtype, unknown1: s32) -> s32 #foreign libncursesw;
idcok :: (unknown0: *WINDOW, unknown1: bool) -> void #foreign libncursesw;
idlok :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
immedok :: (unknown0: *WINDOW, unknown1: bool) -> void #foreign libncursesw;
inch :: () -> chtype #foreign libncursesw;
inchnstr :: (unknown0: *chtype, unknown1: s32) -> s32 #foreign libncursesw;
inchstr :: (unknown0: *chtype) -> s32 #foreign libncursesw;
initscr :: () -> *WINDOW #foreign libncursesw;
init_color :: (unknown0: s16, unknown1: s16, unknown2: s16, unknown3: s16) -> s32 #foreign libncursesw;
init_pair :: (unknown0: s16, unknown1: s16, unknown2: s16) -> s32 #foreign libncursesw;
innstr :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
insch :: (unknown0: chtype) -> s32 #foreign libncursesw;
insdelln :: (unknown0: s32) -> s32 #foreign libncursesw;
insertln :: () -> s32 #foreign libncursesw;
insnstr :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
insstr :: (unknown0: *u8) -> s32 #foreign libncursesw;
instr :: (unknown0: *u8) -> s32 #foreign libncursesw;
intrflush :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
isendwin :: () -> bool #foreign libncursesw;
is_linetouched :: (unknown0: *WINDOW, unknown1: s32) -> bool #foreign libncursesw;
is_wintouched :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
keyname :: (unknown0: s32) -> *u8 #foreign libncursesw;
keypad :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
killchar :: () -> u8 #foreign libncursesw;
leaveok :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
longname :: () -> *u8 #foreign libncursesw;
meta :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
move :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
mvaddch :: (unknown0: s32, unknown1: s32, unknown2: chtype) -> s32 #foreign libncursesw;
mvaddchnstr :: (unknown0: s32, unknown1: s32, unknown2: *chtype, unknown3: s32) -> s32 #foreign libncursesw;
mvaddchstr :: (unknown0: s32, unknown1: s32, unknown2: *chtype) -> s32 #foreign libncursesw;
mvaddnstr :: (unknown0: s32, unknown1: s32, unknown2: *u8, unknown3: s32) -> s32 #foreign libncursesw;
mvaddstr :: (unknown0: s32, unknown1: s32, unknown2: *u8) -> s32 #foreign libncursesw;
mvchgat :: (unknown0: s32, unknown1: s32, unknown2: s32, unknown3: attr_t, unknown4: s16, unknown5: *void) -> s32 #foreign libncursesw;
mvcur :: (unknown0: s32, unknown1: s32, unknown2: s32, unknown3: s32) -> s32 #foreign libncursesw;
mvdelch :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
mvderwin :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
mvgetch :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
mvgetnstr :: (unknown0: s32, unknown1: s32, unknown2: *u8, unknown3: s32) -> s32 #foreign libncursesw;
mvgetstr :: (unknown0: s32, unknown1: s32, unknown2: *u8) -> s32 #foreign libncursesw;
mvhline :: (unknown0: s32, unknown1: s32, unknown2: chtype, unknown3: s32) -> s32 #foreign libncursesw;
mvinch :: (unknown0: s32, unknown1: s32) -> chtype #foreign libncursesw;
mvinchnstr :: (unknown0: s32, unknown1: s32, unknown2: *chtype, unknown3: s32) -> s32 #foreign libncursesw;
mvinchstr :: (unknown0: s32, unknown1: s32, unknown2: *chtype) -> s32 #foreign libncursesw;
mvinnstr :: (unknown0: s32, unknown1: s32, unknown2: *u8, unknown3: s32) -> s32 #foreign libncursesw;
mvinsch :: (unknown0: s32, unknown1: s32, unknown2: chtype) -> s32 #foreign libncursesw;
mvinsnstr :: (unknown0: s32, unknown1: s32, unknown2: *u8, unknown3: s32) -> s32 #foreign libncursesw;
mvinsstr :: (unknown0: s32, unknown1: s32, unknown2: *u8) -> s32 #foreign libncursesw;
mvinstr :: (unknown0: s32, unknown1: s32, unknown2: *u8) -> s32 #foreign libncursesw;
mvprintw_CFormat :: (unknown0: s32, unknown1: s32, unknown2: *u8, __args: ..Any) -> s32 #foreign libncursesw "mvprintw";
mvprintw :: (unknown0: s32, unknown1: s32, unknown2: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown2, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return mvprintw_CFormat(unknown0, unknown1, "%s", formatted_text.data);
} @PrintLike

mvscanw_CFormat :: (unknown0: s32, unknown1: s32, unknown2: *u8, __args: ..Any) -> s32 #foreign libncursesw "mvscanw";
mvscanw :: (unknown0: s32, unknown1: s32, unknown2: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown2, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return mvscanw_CFormat(unknown0, unknown1, "%s", formatted_text.data);
} @PrintLike

mvvline :: (unknown0: s32, unknown1: s32, unknown2: chtype, unknown3: s32) -> s32 #foreign libncursesw;
mvwaddch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: chtype) -> s32 #foreign libncursesw;
mvwaddchnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *chtype, unknown4: s32) -> s32 #foreign libncursesw;
mvwaddchstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *chtype) -> s32 #foreign libncursesw;
mvwaddnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, unknown4: s32) -> s32 #foreign libncursesw;
mvwaddstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8) -> s32 #foreign libncursesw;
mvwchgat :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: attr_t, unknown5: s16, unknown6: *void) -> s32 #foreign libncursesw;
mvwdelch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
mvwgetch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
mvwgetnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, unknown4: s32) -> s32 #foreign libncursesw;
mvwgetstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8) -> s32 #foreign libncursesw;
mvwhline :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: chtype, unknown4: s32) -> s32 #foreign libncursesw;
mvwin :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
mvwinch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> chtype #foreign libncursesw;
mvwinchnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *chtype, unknown4: s32) -> s32 #foreign libncursesw;
mvwinchstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *chtype) -> s32 #foreign libncursesw;
mvwinnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, unknown4: s32) -> s32 #foreign libncursesw;
mvwinsch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: chtype) -> s32 #foreign libncursesw;
mvwinsnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, unknown4: s32) -> s32 #foreign libncursesw;
mvwinsstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8) -> s32 #foreign libncursesw;
mvwinstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8) -> s32 #foreign libncursesw;
mvwprintw_CFormat :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, __args: ..Any) -> s32 #foreign libncursesw "mvwprintw";
mvwprintw :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown3, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return mvwprintw_CFormat(unknown0, unknown1, unknown2, "%s", formatted_text.data);
} @PrintLike

mvwscanw_CFormat :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *u8, __args: ..Any) -> s32 #foreign libncursesw "mvwscanw";
mvwscanw :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown3, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return mvwscanw_CFormat(unknown0, unknown1, unknown2, "%s", formatted_text.data);
} @PrintLike

mvwvline :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: chtype, unknown4: s32) -> s32 #foreign libncursesw;
napms :: (unknown0: s32) -> s32 #foreign libncursesw;
newpad :: (unknown0: s32, unknown1: s32) -> *WINDOW #foreign libncursesw;
newterm :: (unknown0: *u8, unknown1: *FILE, unknown2: *FILE) -> *SCREEN #foreign libncursesw;
newwin :: (unknown0: s32, unknown1: s32, unknown2: s32, unknown3: s32) -> *WINDOW #foreign libncursesw;
nl :: () -> s32 #foreign libncursesw;
nocbreak :: () -> s32 #foreign libncursesw;
nodelay :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
noecho :: () -> s32 #foreign libncursesw;
nonl :: () -> s32 #foreign libncursesw;
noqiflush :: () -> void #foreign libncursesw;
noraw :: () -> s32 #foreign libncursesw;
notimeout :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
overlay :: (unknown0: *WINDOW, unknown1: *WINDOW) -> s32 #foreign libncursesw;
overwrite :: (unknown0: *WINDOW, unknown1: *WINDOW) -> s32 #foreign libncursesw;
pair_content :: (unknown0: s16, unknown1: *s16, unknown2: *s16) -> s32 #foreign libncursesw;
PAIR_NUMBER :: (unknown0: s32) -> s32 #foreign libncursesw;
pechochar :: (unknown0: *WINDOW, unknown1: chtype) -> s32 #foreign libncursesw;
pnoutrefresh :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32, unknown5: s32, unknown6: s32) -> s32 #foreign libncursesw;
prefresh :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32, unknown5: s32, unknown6: s32) -> s32 #foreign libncursesw;
printw_CFormat :: (unknown0: *u8, __args: ..Any) -> s32 #foreign libncursesw "printw";
printw :: (unknown0: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown0, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return printw_CFormat("%s", formatted_text.data);
} @PrintLike

putwin :: (unknown0: *WINDOW, unknown1: *FILE) -> s32 #foreign libncursesw;
qiflush :: () -> void #foreign libncursesw;
raw :: () -> s32 #foreign libncursesw;
redrawwin :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
refresh :: () -> s32 #foreign libncursesw;
resetty :: () -> s32 #foreign libncursesw;
reset_prog_mode :: () -> s32 #foreign libncursesw;
reset_shell_mode :: () -> s32 #foreign libncursesw;
ripoffline :: (unknown0: s32, unknown1: #type (unknown0: *WINDOW, unknown1: s32) -> s32 #c_call) -> s32 #foreign libncursesw;
savetty :: () -> s32 #foreign libncursesw;
scanw_CFormat :: (unknown0: *u8, __args: ..Any) -> s32 #foreign libncursesw "scanw";
scanw :: (unknown0: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown0, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return scanw_CFormat("%s", formatted_text.data);
} @PrintLike

scr_dump :: (unknown0: *u8) -> s32 #foreign libncursesw;
scr_init :: (unknown0: *u8) -> s32 #foreign libncursesw;
scrl :: (unknown0: s32) -> s32 #foreign libncursesw;
scroll :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
scrollok :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
scr_restore :: (unknown0: *u8) -> s32 #foreign libncursesw;
scr_set :: (unknown0: *u8) -> s32 #foreign libncursesw;
setscrreg :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
set_term :: (unknown0: *SCREEN) -> *SCREEN #foreign libncursesw;
slk_attroff :: (unknown0: chtype) -> s32 #foreign libncursesw;
slk_attr_off :: (unknown0: attr_t, unknown1: *void) -> s32 #foreign libncursesw;
slk_attron :: (unknown0: chtype) -> s32 #foreign libncursesw;
slk_attr_on :: (unknown0: attr_t, unknown1: *void) -> s32 #foreign libncursesw;
slk_attrset :: (unknown0: chtype) -> s32 #foreign libncursesw;
slk_attr :: () -> attr_t #foreign libncursesw;
slk_attr_set :: (unknown0: attr_t, unknown1: s16, unknown2: *void) -> s32 #foreign libncursesw;
slk_clear :: () -> s32 #foreign libncursesw;
slk_color :: (unknown0: s16) -> s32 #foreign libncursesw;
slk_init :: (unknown0: s32) -> s32 #foreign libncursesw;
slk_label :: (unknown0: s32) -> *u8 #foreign libncursesw;
slk_noutrefresh :: () -> s32 #foreign libncursesw;
slk_refresh :: () -> s32 #foreign libncursesw;
slk_restore :: () -> s32 #foreign libncursesw;
slk_set :: (unknown0: s32, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
slk_touch :: () -> s32 #foreign libncursesw;
standout :: () -> s32 #foreign libncursesw;
standend :: () -> s32 #foreign libncursesw;
start_color :: () -> s32 #foreign libncursesw;
subpad :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> *WINDOW #foreign libncursesw;
subwin :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> *WINDOW #foreign libncursesw;
syncok :: (unknown0: *WINDOW, unknown1: bool) -> s32 #foreign libncursesw;
termattrs :: () -> chtype #foreign libncursesw;
termname :: () -> *u8 #foreign libncursesw;
timeout :: (unknown0: s32) -> void #foreign libncursesw;
touchline :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
touchwin :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
typeahead :: (unknown0: s32) -> s32 #foreign libncursesw;
ungetch :: (unknown0: s32) -> s32 #foreign libncursesw;
untouchwin :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
use_env :: (unknown0: bool) -> void #foreign libncursesw;
use_tioctl :: (unknown0: bool) -> void #foreign libncursesw;
vidattr :: (unknown0: chtype) -> s32 #foreign libncursesw;
vidputs :: (unknown0: chtype, unknown1: NCURSES_OUTC) -> s32 #foreign libncursesw;
vline :: (unknown0: chtype, unknown1: s32) -> s32 #foreign libncursesw;

waddch :: (unknown0: *WINDOW, unknown1: chtype) -> s32 #foreign libncursesw;
waddchnstr :: (unknown0: *WINDOW, unknown1: *chtype, unknown2: s32) -> s32 #foreign libncursesw;
waddchstr :: (unknown0: *WINDOW, unknown1: *chtype) -> s32 #foreign libncursesw;
waddnstr :: (unknown0: *WINDOW, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
waddstr :: (unknown0: *WINDOW, unknown1: *u8) -> s32 #foreign libncursesw;
wattron :: (unknown0: *WINDOW, unknown1: s32) -> s32 #foreign libncursesw;
wattroff :: (unknown0: *WINDOW, unknown1: s32) -> s32 #foreign libncursesw;
wattrset :: (unknown0: *WINDOW, unknown1: s32) -> s32 #foreign libncursesw;
wattr_get :: (unknown0: *WINDOW, unknown1: *attr_t, unknown2: *s16, unknown3: *void) -> s32 #foreign libncursesw;
wattr_on :: (unknown0: *WINDOW, unknown1: attr_t, unknown2: *void) -> s32 #foreign libncursesw;
wattr_off :: (unknown0: *WINDOW, unknown1: attr_t, unknown2: *void) -> s32 #foreign libncursesw;
wattr_set :: (unknown0: *WINDOW, unknown1: attr_t, unknown2: s16, unknown3: *void) -> s32 #foreign libncursesw;
wbkgd :: (unknown0: *WINDOW, unknown1: chtype) -> s32 #foreign libncursesw;
wbkgdset :: (unknown0: *WINDOW, unknown1: chtype) -> void #foreign libncursesw;
wborder :: (unknown0: *WINDOW, unknown1: chtype, unknown2: chtype, unknown3: chtype, unknown4: chtype, unknown5: chtype, unknown6: chtype, unknown7: chtype, unknown8: chtype) -> s32 #foreign libncursesw;
wchgat :: (unknown0: *WINDOW, unknown1: s32, unknown2: attr_t, unknown3: s16, unknown4: *void) -> s32 #foreign libncursesw;
wclear :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wclrtobot :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wclrtoeol :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wcolor_set :: (unknown0: *WINDOW, unknown1: s16, unknown2: *void) -> s32 #foreign libncursesw;
wcursyncup :: (unknown0: *WINDOW) -> void #foreign libncursesw;
wdelch :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wdeleteln :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wechochar :: (unknown0: *WINDOW, unknown1: chtype) -> s32 #foreign libncursesw;
werase :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wgetch :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wgetnstr :: (unknown0: *WINDOW, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
wgetstr :: (unknown0: *WINDOW, unknown1: *u8) -> s32 #foreign libncursesw;
whline :: (unknown0: *WINDOW, unknown1: chtype, unknown2: s32) -> s32 #foreign libncursesw;
winch :: (unknown0: *WINDOW) -> chtype #foreign libncursesw;
winchnstr :: (unknown0: *WINDOW, unknown1: *chtype, unknown2: s32) -> s32 #foreign libncursesw;
winchstr :: (unknown0: *WINDOW, unknown1: *chtype) -> s32 #foreign libncursesw;
winnstr :: (unknown0: *WINDOW, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
winsch :: (unknown0: *WINDOW, unknown1: chtype) -> s32 #foreign libncursesw;
winsdelln :: (unknown0: *WINDOW, unknown1: s32) -> s32 #foreign libncursesw;
winsertln :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
winsnstr :: (unknown0: *WINDOW, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
winsstr :: (unknown0: *WINDOW, unknown1: *u8) -> s32 #foreign libncursesw;
winstr :: (unknown0: *WINDOW, unknown1: *u8) -> s32 #foreign libncursesw;
wmove :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
wnoutrefresh :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wprintw_CFormat :: (unknown0: *WINDOW, unknown1: *u8, __args: ..Any) -> s32 #foreign libncursesw "wprintw";
wprintw :: (unknown0: *WINDOW, unknown1: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown1, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return wprintw_CFormat(unknown0, "%s", formatted_text.data);
} @PrintLike

wredrawln :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
wrefresh :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wscanw_CFormat :: (unknown0: *WINDOW, unknown1: *u8, __args: ..Any) -> s32 #foreign libncursesw "wscanw";
wscanw :: (unknown0: *WINDOW, unknown1: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown1, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return wscanw_CFormat(unknown0, "%s", formatted_text.data);
} @PrintLike

wscrl :: (unknown0: *WINDOW, unknown1: s32) -> s32 #foreign libncursesw;
wsetscrreg :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
wstandout :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wstandend :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wsyncdown :: (unknown0: *WINDOW) -> void #foreign libncursesw;
wsyncup :: (unknown0: *WINDOW) -> void #foreign libncursesw;
wtimeout :: (unknown0: *WINDOW, unknown1: s32) -> void #foreign libncursesw;
wtouchln :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: s32) -> s32 #foreign libncursesw;
wvline :: (unknown0: *WINDOW, unknown1: chtype, unknown2: s32) -> s32 #foreign libncursesw;

/*
* These are also declared in <term.h>:
*/
tigetflag :: (unknown0: *u8) -> s32 #foreign libncursesw;
tigetnum :: (unknown0: *u8) -> s32 #foreign libncursesw;
tigetstr :: (unknown0: *u8) -> *u8 #foreign libncursesw;
putp :: (unknown0: *u8) -> s32 #foreign libncursesw;

tparm_CFormat :: (unknown0: *u8, __args: ..Any) -> *u8 #foreign libncursesw "tparm";
tparm :: (unknown0: string, __args: ..Any) -> *u8 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown0, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return tparm_CFormat("%s", formatted_text.data);
} @PrintLike

tiparm_CFormat :: (unknown0: *u8, __args: ..Any) -> *u8 #foreign libncursesw "tiparm";
tiparm :: (unknown0: string, __args: ..Any) -> *u8 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown0, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return tiparm_CFormat("%s", formatted_text.data);
} @PrintLike
tiparm_s_CFormat :: (unknown0: s32, unknown1: s32, unknown2: *u8, __args: ..Any) -> *u8 #foreign libncursesw "tiparm_s";
tiparm_s :: (unknown0: s32, unknown1: s32, unknown2: string, __args: ..Any) -> *u8 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, unknown2, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return tiparm_s_CFormat(unknown0, unknown1, "%s", formatted_text.data);
} @PrintLike
tiscan_s :: (unknown0: *s32, unknown1: *s32, unknown2: *u8) -> s32 #foreign libncursesw;

/*
* These functions are not in X/Open, but we use them in macro definitions:
*/
getattrs :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getcurx :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getcury :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getbegx :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getbegy :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getmaxx :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getmaxy :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getparx :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
getpary :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;

NCURSES_WINDOW_CB :: #type (unknown0: *WINDOW, unknown1: *void) -> s32 #c_call;
NCURSES_SCREEN_CB :: #type (unknown0: *SCREEN, unknown1: *void) -> s32 #c_call;
alloc_pair :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
assume_default_colors :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
curses_version :: () -> *u8 #foreign libncursesw;
define_key :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
extended_color_content :: (unknown0: s32, unknown1: *s32, unknown2: *s32, unknown3: *s32) -> s32 #foreign libncursesw;
extended_pair_content :: (unknown0: s32, unknown1: *s32, unknown2: *s32) -> s32 #foreign libncursesw;
extended_slk_color :: (unknown0: s32) -> s32 #foreign libncursesw;
find_pair :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
free_pair :: (unknown0: s32) -> s32 #foreign libncursesw;
get_escdelay :: () -> s32 #foreign libncursesw;
init_extended_color :: (unknown0: s32, unknown1: s32, unknown2: s32, unknown3: s32) -> s32 #foreign libncursesw;
init_extended_pair :: (unknown0: s32, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
is_cbreak :: () -> s32 #foreign libncursesw;
is_echo :: () -> s32 #foreign libncursesw;
is_nl :: () -> s32 #foreign libncursesw;
is_raw :: () -> s32 #foreign libncursesw;
is_term_resized :: (unknown0: s32, unknown1: s32) -> bool #foreign libncursesw;
key_defined :: (unknown0: *u8) -> s32 #foreign libncursesw;
keybound :: (unknown0: s32, unknown1: s32) -> *u8 #foreign libncursesw;
keyok :: (unknown0: s32, unknown1: bool) -> s32 #foreign libncursesw;
nofilter :: () -> void #foreign libncursesw;
reset_color_pairs :: () -> void #foreign libncursesw;
resize_term :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
resizeterm :: (unknown0: s32, unknown1: s32) -> s32 #foreign libncursesw;
set_escdelay :: (unknown0: s32) -> s32 #foreign libncursesw;
set_tabsize :: (unknown0: s32) -> s32 #foreign libncursesw;
use_default_colors :: () -> s32 #foreign libncursesw;
use_legacy_coding :: (unknown0: s32) -> s32 #foreign libncursesw;
use_screen :: (unknown0: *SCREEN, unknown1: NCURSES_SCREEN_CB, unknown2: *void) -> s32 #foreign libncursesw;
use_window :: (unknown0: *WINDOW, unknown1: NCURSES_WINDOW_CB, unknown2: *void) -> s32 #foreign libncursesw;
wresize :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;

use_extended_names :: (unknown0: bool) -> s32 #foreign libncursesw;

/*
* These extensions provide access to information stored in the WINDOW even
* when NCURSES_OPAQUE is set:
*/
wgetparent :: (unknown0: *WINDOW) -> *WINDOW #foreign libncursesw;
is_cleared :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_idcok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_idlok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_immedok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_keypad :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_leaveok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_nodelay :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_notimeout :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_pad :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_scrollok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_subwin :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
is_syncok :: (unknown0: *WINDOW) -> bool #foreign libncursesw;
wgetdelay :: (unknown0: *WINDOW) -> s32 #foreign libncursesw;
wgetscrreg :: (unknown0: *WINDOW, unknown1: *s32, unknown2: *s32) -> s32 #foreign libncursesw;

NCURSES_OUTC_sp :: #type (unknown0: *SCREEN, unknown1: s32) -> s32 #c_call;

new_prescr :: () -> *SCREEN #foreign libncursesw;

baudrate_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
beep_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
can_change_color_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
cbreak_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
curs_set_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
color_content_sp :: (unknown0: *SCREEN, unknown1: s16, unknown2: *s16, unknown3: *s16, unknown4: *s16) -> s32 #foreign libncursesw;
def_prog_mode_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
def_shell_mode_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
delay_output_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
doupdate_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
echo_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
endwin_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
erasechar_sp :: (unknown0: *SCREEN) -> u8 #foreign libncursesw;
filter_sp :: (unknown0: *SCREEN) -> void #foreign libncursesw;
flash_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
flushinp_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
getwin_sp :: (unknown0: *SCREEN, unknown1: *FILE) -> *WINDOW #foreign libncursesw;
halfdelay_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
has_colors_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
has_ic_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
has_il_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
init_color_sp :: (unknown0: *SCREEN, unknown1: s16, unknown2: s16, unknown3: s16, unknown4: s16) -> s32 #foreign libncursesw;
init_pair_sp :: (unknown0: *SCREEN, unknown1: s16, unknown2: s16, unknown3: s16) -> s32 #foreign libncursesw;
intrflush_sp :: (unknown0: *SCREEN, unknown1: *WINDOW, unknown2: bool) -> s32 #foreign libncursesw;
isendwin_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
keyname_sp :: (unknown0: *SCREEN, unknown1: s32) -> *u8 #foreign libncursesw;
killchar_sp :: (unknown0: *SCREEN) -> u8 #foreign libncursesw;
longname_sp :: (unknown0: *SCREEN) -> *u8 #foreign libncursesw;
mvcur_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> s32 #foreign libncursesw;
napms_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
newpad_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> *WINDOW #foreign libncursesw;
newterm_sp :: (unknown0: *SCREEN, unknown1: *u8, unknown2: *FILE, unknown3: *FILE) -> *SCREEN #foreign libncursesw;
newwin_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> *WINDOW #foreign libncursesw;
nl_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
nocbreak_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
noecho_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
nonl_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
noqiflush_sp :: (unknown0: *SCREEN) -> void #foreign libncursesw;
noraw_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
pair_content_sp :: (unknown0: *SCREEN, unknown1: s16, unknown2: *s16, unknown3: *s16) -> s32 #foreign libncursesw;
qiflush_sp :: (unknown0: *SCREEN) -> void #foreign libncursesw;
raw_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
reset_prog_mode_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
reset_shell_mode_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
resetty_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
ripoffline_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: #type (unknown0: *WINDOW, unknown1: s32) -> s32 #c_call) -> s32 #foreign libncursesw;
savetty_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
scr_init_sp :: (unknown0: *SCREEN, unknown1: *u8) -> s32 #foreign libncursesw;
scr_restore_sp :: (unknown0: *SCREEN, unknown1: *u8) -> s32 #foreign libncursesw;
scr_set_sp :: (unknown0: *SCREEN, unknown1: *u8) -> s32 #foreign libncursesw;
slk_attroff_sp :: (unknown0: *SCREEN, unknown1: chtype) -> s32 #foreign libncursesw;
slk_attron_sp :: (unknown0: *SCREEN, unknown1: chtype) -> s32 #foreign libncursesw;
slk_attrset_sp :: (unknown0: *SCREEN, unknown1: chtype) -> s32 #foreign libncursesw;
slk_attr_sp :: (unknown0: *SCREEN) -> attr_t #foreign libncursesw;
slk_attr_set_sp :: (unknown0: *SCREEN, unknown1: attr_t, unknown2: s16, unknown3: *void) -> s32 #foreign libncursesw;
slk_clear_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
slk_color_sp :: (unknown0: *SCREEN, unknown1: s16) -> s32 #foreign libncursesw;
slk_init_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
slk_label_sp :: (unknown0: *SCREEN, unknown1: s32) -> *u8 #foreign libncursesw;
slk_noutrefresh_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
slk_refresh_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
slk_restore_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
slk_set_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: *u8, unknown3: s32) -> s32 #foreign libncursesw;
slk_touch_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
start_color_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
termattrs_sp :: (unknown0: *SCREEN) -> chtype #foreign libncursesw;
termname_sp :: (unknown0: *SCREEN) -> *u8 #foreign libncursesw;
typeahead_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
ungetch_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
use_env_sp :: (unknown0: *SCREEN, unknown1: bool) -> void #foreign libncursesw;
use_tioctl_sp :: (unknown0: *SCREEN, unknown1: bool) -> void #foreign libncursesw;
vidattr_sp :: (unknown0: *SCREEN, unknown1: chtype) -> s32 #foreign libncursesw;
vidputs_sp :: (unknown0: *SCREEN, unknown1: chtype, unknown2: NCURSES_OUTC_sp) -> s32 #foreign libncursesw;

alloc_pair_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
assume_default_colors_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
define_key_sp :: (unknown0: *SCREEN, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;
extended_color_content_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: *s32, unknown3: *s32, unknown4: *s32) -> s32 #foreign libncursesw;
extended_pair_content_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: *s32, unknown3: *s32) -> s32 #foreign libncursesw;
extended_slk_color_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
find_pair_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
free_pair_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
get_escdelay_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
init_extended_color_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32, unknown3: s32, unknown4: s32) -> s32 #foreign libncursesw;
init_extended_pair_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32, unknown3: s32) -> s32 #foreign libncursesw;
is_cbreak_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
is_echo_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
is_nl_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
is_raw_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
is_term_resized_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> bool #foreign libncursesw;
key_defined_sp :: (unknown0: *SCREEN, unknown1: *u8) -> s32 #foreign libncursesw;
keybound_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> *u8 #foreign libncursesw;
keyok_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: bool) -> s32 #foreign libncursesw;
nofilter_sp :: (unknown0: *SCREEN) -> void #foreign libncursesw;
reset_color_pairs_sp :: (unknown0: *SCREEN) -> void #foreign libncursesw;
resize_term_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
resizeterm_sp :: (unknown0: *SCREEN, unknown1: s32, unknown2: s32) -> s32 #foreign libncursesw;
set_escdelay_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
set_tabsize_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
use_default_colors_sp :: (unknown0: *SCREEN) -> s32 #foreign libncursesw;
use_legacy_coding_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;

curscr: *WINDOW #elsewhere libncursesw;
newscr: *WINDOW #elsewhere libncursesw;
stdscr: *WINDOW #elsewhere libncursesw;
ttytype: *u8 #elsewhere libncursesw;
COLORS: s32 #elsewhere libncursesw;
COLOR_PAIRS: s32 #elsewhere libncursesw;
COLS: s32 #elsewhere libncursesw;
ESCDELAY: s32 #elsewhere libncursesw;
LINES: s32 #elsewhere libncursesw;
TABSIZE: s32 #elsewhere libncursesw;

_nc_wacs: *cchar_t #elsewhere libncursesw;

/*
* Function prototypes for wide-character operations.
*
* "generated" comments should include ":WIDEC" to make the corresponding
* functions ifdef'd in lib_gen.c
*
* "implemented" comments do not need this marker.
*/
add_wch :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
add_wchnstr :: (unknown0: *cchar_t, unknown1: s32) -> s32 #foreign libncursesw;
add_wchstr :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
addnwstr :: (unknown0: *s32, unknown1: s32) -> s32 #foreign libncursesw;
addwstr :: (unknown0: *s32) -> s32 #foreign libncursesw;
bkgrnd :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
bkgrndset :: (unknown0: *cchar_t) -> void #foreign libncursesw;
border_set :: (unknown0: *cchar_t, unknown1: *cchar_t, unknown2: *cchar_t, unknown3: *cchar_t, unknown4: *cchar_t, unknown5: *cchar_t, unknown6: *cchar_t, unknown7: *cchar_t) -> s32 #foreign libncursesw;
box_set :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: *cchar_t) -> s32 #foreign libncursesw;
echo_wchar :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
erasewchar :: (unknown0: *s32) -> s32 #foreign libncursesw;
get_wch :: (unknown0: *wint_t) -> s32 #foreign libncursesw;
get_wstr :: (unknown0: *wint_t) -> s32 #foreign libncursesw;
getbkgrnd :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
getcchar :: (unknown0: *cchar_t, unknown1: *s32, unknown2: *attr_t, unknown3: *s16, unknown4: *void) -> s32 #foreign libncursesw;
getn_wstr :: (unknown0: *wint_t, unknown1: s32) -> s32 #foreign libncursesw;
hline_set :: (unknown0: *cchar_t, unknown1: s32) -> s32 #foreign libncursesw;
in_wch :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
in_wchnstr :: (unknown0: *cchar_t, unknown1: s32) -> s32 #foreign libncursesw;
in_wchstr :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
innwstr :: (unknown0: *s32, unknown1: s32) -> s32 #foreign libncursesw;
ins_nwstr :: (unknown0: *s32, unknown1: s32) -> s32 #foreign libncursesw;
ins_wch :: (unknown0: *cchar_t) -> s32 #foreign libncursesw;
ins_wstr :: (unknown0: *s32) -> s32 #foreign libncursesw;
inwstr :: (unknown0: *s32) -> s32 #foreign libncursesw;
key_name :: (unknown0: s32) -> *u8 #foreign libncursesw;
killwchar :: (unknown0: *s32) -> s32 #foreign libncursesw;
mvadd_wch :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t) -> s32 #foreign libncursesw;
mvadd_wchnstr :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t, unknown3: s32) -> s32 #foreign libncursesw;
mvadd_wchstr :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t) -> s32 #foreign libncursesw;
mvaddnwstr :: (unknown0: s32, unknown1: s32, unknown2: *s32, unknown3: s32) -> s32 #foreign libncursesw;
mvaddwstr :: (unknown0: s32, unknown1: s32, unknown2: *s32) -> s32 #foreign libncursesw;
mvget_wch :: (unknown0: s32, unknown1: s32, unknown2: *wint_t) -> s32 #foreign libncursesw;
mvget_wstr :: (unknown0: s32, unknown1: s32, unknown2: *wint_t) -> s32 #foreign libncursesw;
mvgetn_wstr :: (unknown0: s32, unknown1: s32, unknown2: *wint_t, unknown3: s32) -> s32 #foreign libncursesw;
mvhline_set :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t, unknown3: s32) -> s32 #foreign libncursesw;
mvin_wch :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t) -> s32 #foreign libncursesw;
mvin_wchnstr :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t, unknown3: s32) -> s32 #foreign libncursesw;
mvin_wchstr :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t) -> s32 #foreign libncursesw;
mvinnwstr :: (unknown0: s32, unknown1: s32, unknown2: *s32, unknown3: s32) -> s32 #foreign libncursesw;
mvins_nwstr :: (unknown0: s32, unknown1: s32, unknown2: *s32, unknown3: s32) -> s32 #foreign libncursesw;
mvins_wch :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t) -> s32 #foreign libncursesw;
mvins_wstr :: (unknown0: s32, unknown1: s32, unknown2: *s32) -> s32 #foreign libncursesw;
mvinwstr :: (unknown0: s32, unknown1: s32, unknown2: *s32) -> s32 #foreign libncursesw;
mvvline_set :: (unknown0: s32, unknown1: s32, unknown2: *cchar_t, unknown3: s32) -> s32 #foreign libncursesw;
mvwadd_wch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t) -> s32 #foreign libncursesw;
mvwadd_wchnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t, unknown4: s32) -> s32 #foreign libncursesw;
mvwadd_wchstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t) -> s32 #foreign libncursesw;
mvwaddnwstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32, unknown4: s32) -> s32 #foreign libncursesw;
mvwaddwstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32) -> s32 #foreign libncursesw;
mvwget_wch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *wint_t) -> s32 #foreign libncursesw;
mvwget_wstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *wint_t) -> s32 #foreign libncursesw;
mvwgetn_wstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *wint_t, unknown4: s32) -> s32 #foreign libncursesw;
mvwhline_set :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t, unknown4: s32) -> s32 #foreign libncursesw;
mvwin_wch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t) -> s32 #foreign libncursesw;
mvwin_wchnstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t, unknown4: s32) -> s32 #foreign libncursesw;
mvwin_wchstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t) -> s32 #foreign libncursesw;
mvwinnwstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32, unknown4: s32) -> s32 #foreign libncursesw;
mvwins_nwstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32, unknown4: s32) -> s32 #foreign libncursesw;
mvwins_wch :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t) -> s32 #foreign libncursesw;
mvwins_wstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32) -> s32 #foreign libncursesw;
mvwinwstr :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *s32) -> s32 #foreign libncursesw;
mvwvline_set :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32, unknown3: *cchar_t, unknown4: s32) -> s32 #foreign libncursesw;
pecho_wchar :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
setcchar :: (unknown0: *cchar_t, unknown1: *s32, unknown2: attr_t, unknown3: s16, unknown4: *void) -> s32 #foreign libncursesw;
slk_wset :: (unknown0: s32, unknown1: *s32, unknown2: s32) -> s32 #foreign libncursesw;
term_attrs :: () -> attr_t #foreign libncursesw;
unget_wch :: (unknown0: s32) -> s32 #foreign libncursesw;
vid_attr :: (unknown0: attr_t, unknown1: s16, unknown2: *void) -> s32 #foreign libncursesw;
vid_puts :: (unknown0: attr_t, unknown1: s16, unknown2: *void, unknown3: NCURSES_OUTC) -> s32 #foreign libncursesw;
vline_set :: (unknown0: *cchar_t, unknown1: s32) -> s32 #foreign libncursesw;
wadd_wch :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
wadd_wchnstr :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: s32) -> s32 #foreign libncursesw;
wadd_wchstr :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
waddnwstr :: (unknown0: *WINDOW, unknown1: *s32, unknown2: s32) -> s32 #foreign libncursesw;
waddwstr :: (unknown0: *WINDOW, unknown1: *s32) -> s32 #foreign libncursesw;
wbkgrnd :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
wbkgrndset :: (unknown0: *WINDOW, unknown1: *cchar_t) -> void #foreign libncursesw;
wborder_set :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: *cchar_t, unknown3: *cchar_t, unknown4: *cchar_t, unknown5: *cchar_t, unknown6: *cchar_t, unknown7: *cchar_t, unknown8: *cchar_t) -> s32 #foreign libncursesw;
wecho_wchar :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
wget_wch :: (unknown0: *WINDOW, unknown1: *wint_t) -> s32 #foreign libncursesw;
wget_wstr :: (unknown0: *WINDOW, unknown1: *wint_t) -> s32 #foreign libncursesw;
wgetbkgrnd :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
wgetn_wstr :: (unknown0: *WINDOW, unknown1: *wint_t, unknown2: s32) -> s32 #foreign libncursesw;
whline_set :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: s32) -> s32 #foreign libncursesw;
win_wch :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
win_wchnstr :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: s32) -> s32 #foreign libncursesw;
win_wchstr :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
winnwstr :: (unknown0: *WINDOW, unknown1: *s32, unknown2: s32) -> s32 #foreign libncursesw;
wins_nwstr :: (unknown0: *WINDOW, unknown1: *s32, unknown2: s32) -> s32 #foreign libncursesw;
wins_wch :: (unknown0: *WINDOW, unknown1: *cchar_t) -> s32 #foreign libncursesw;
wins_wstr :: (unknown0: *WINDOW, unknown1: *s32) -> s32 #foreign libncursesw;
winwstr :: (unknown0: *WINDOW, unknown1: *s32) -> s32 #foreign libncursesw;
wunctrl :: (unknown0: *cchar_t) -> *s32 #foreign libncursesw;
wvline_set :: (unknown0: *WINDOW, unknown1: *cchar_t, unknown2: s32) -> s32 #foreign libncursesw;

term_attrs_sp :: (unknown0: *SCREEN) -> attr_t #foreign libncursesw;
erasewchar_sp :: (unknown0: *SCREEN, unknown1: *s32) -> s32 #foreign libncursesw;
killwchar_sp :: (unknown0: *SCREEN, unknown1: *s32) -> s32 #foreign libncursesw;
unget_wch_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
vid_attr_sp :: (unknown0: *SCREEN, unknown1: attr_t, unknown2: s16, unknown3: *void) -> s32 #foreign libncursesw;
vid_puts_sp :: (unknown0: *SCREEN, unknown1: attr_t, unknown2: s16, unknown3: *void, unknown4: NCURSES_OUTC_sp) -> s32 #foreign libncursesw;
wunctrl_sp :: (unknown0: *SCREEN, unknown1: *cchar_t) -> *s32 #foreign libncursesw;

MEVENT :: struct {
    id:     s16; /* ID to distinguish multiple devices */
    x:      s32; /* event coordinates (character-cell) */
    y:      s32; /* event coordinates (character-cell) */
    z:      s32; /* event coordinates (character-cell) */
    bstate: mmask_t; /* button state bits */
}

has_mouse :: () -> bool #foreign libncursesw;
getmouse :: (unknown0: *MEVENT) -> s32 #foreign libncursesw;
ungetmouse :: (unknown0: *MEVENT) -> s32 #foreign libncursesw;
mousemask :: (unknown0: mmask_t, unknown1: *mmask_t) -> mmask_t #foreign libncursesw;
wenclose :: (unknown0: *WINDOW, unknown1: s32, unknown2: s32) -> bool #foreign libncursesw;
mouseinterval :: (unknown0: s32) -> s32 #foreign libncursesw;
wmouse_trafo :: (unknown0: *WINDOW, unknown1: *s32, unknown2: *s32, unknown3: bool) -> bool #foreign libncursesw;
mouse_trafo :: (unknown0: *s32, unknown1: *s32, unknown2: bool) -> bool #foreign libncursesw;

has_mouse_sp :: (unknown0: *SCREEN) -> bool #foreign libncursesw;
getmouse_sp :: (unknown0: *SCREEN, unknown1: *MEVENT) -> s32 #foreign libncursesw;
ungetmouse_sp :: (unknown0: *SCREEN, unknown1: *MEVENT) -> s32 #foreign libncursesw;
mousemask_sp :: (unknown0: *SCREEN, unknown1: mmask_t, unknown2: *mmask_t) -> mmask_t #foreign libncursesw;
mouseinterval_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;

/* other non-XSI functions */
mcprint :: (unknown0: *u8, unknown1: s32) -> s32 #foreign libncursesw;
has_key :: (unknown0: s32) -> s32 #foreign libncursesw;

has_key_sp :: (unknown0: *SCREEN, unknown1: s32) -> s32 #foreign libncursesw;
mcprint_sp :: (unknown0: *SCREEN, unknown1: *u8, unknown2: s32) -> s32 #foreign libncursesw;

curses_trace :: (unknown0: u32) -> u32 #foreign libncursesw;

exit_curses :: (unknown0: s32) -> void #foreign libncursesw;

#scope_file

#import "Basic"; // For assert, print_to_builder

libncursesw :: #library,system "libncursesw";

#run {
    {
        info := type_info(cchar_t);
        for info.members {
            if it.name == {
                case "attr";
                    assert(it.offset_in_bytes == 0, "cchar_t.attr has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "cchar_t.attr has unexpected size % instead of 4", it.type.runtime_size);
                case "chars";
                    assert(it.offset_in_bytes == 4, "cchar_t.chars has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 20, "cchar_t.chars has unexpected size % instead of 20", it.type.runtime_size);
                case "ext_color";
                    assert(it.offset_in_bytes == 24, "cchar_t.ext_color has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "cchar_t.ext_color has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(cchar_t) == 28, "cchar_t has size % instead of 28", size_of(cchar_t));
    }

    {
        info := type_info(MEVENT);
        for info.members {
            if it.name == {
                case "id";
                    assert(it.offset_in_bytes == 0, "MEVENT.id has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 2, "MEVENT.id has unexpected size % instead of 2", it.type.runtime_size);
                case "x";
                    assert(it.offset_in_bytes == 4, "MEVENT.x has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "MEVENT.x has unexpected size % instead of 4", it.type.runtime_size);
                case "y";
                    assert(it.offset_in_bytes == 8, "MEVENT.y has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "MEVENT.y has unexpected size % instead of 4", it.type.runtime_size);
                case "z";
                    assert(it.offset_in_bytes == 12, "MEVENT.z has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "MEVENT.z has unexpected size % instead of 4", it.type.runtime_size);
                case "bstate";
                    assert(it.offset_in_bytes == 16, "MEVENT.bstate has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "MEVENT.bstate has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(MEVENT) == 20, "MEVENT has size % instead of 20", size_of(MEVENT));
    }
}

