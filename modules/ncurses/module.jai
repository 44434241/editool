

#load "generated.jai";

#import "POSIX"; // FILE

// NCURSES_ATTR_SHIFT :: 8;

#assert chtype == u32;

NCURSES_BITS :: (mask: int, shift: int) -> chtype #expand #no_aoc {
	return cast(chtype) ((mask << (shift + NCURSES_ATTR_SHIFT)) & ((1 << 32) - 1));
}

// A_NORMAL :: (1 - 1);
A_ATTRIBUTES :: #run NCURSES_BITS(~(1 - 1),0);
A_CHARTEXT :: (#run NCURSES_BITS(1,0) - 1);
A_COLOR :: #run NCURSES_BITS(((1) << 8) - 1,0);
A_STANDOUT :: #run NCURSES_BITS(1,8);
A_UNDERLINE :: #run NCURSES_BITS(1,9);
A_REVERSE :: #run NCURSES_BITS(1,10);
A_BLINK :: #run NCURSES_BITS(1,11);
A_DIM :: #run NCURSES_BITS(1,12);
A_BOLD :: #run NCURSES_BITS(1,13);
A_ALTCHARSET :: #run NCURSES_BITS(1,14);

/* SVr4 curses marks these as "subject to change" */
A_INVIS :: #run NCURSES_BITS(1,15);
A_PROTECT :: #run NCURSES_BITS(1,16);

/* X/Open features not found in SVr4 curses */
A_HORIZONTAL :: #run NCURSES_BITS(1,17);
A_LEFT :: #run NCURSES_BITS(1,18);
A_LOW :: #run NCURSES_BITS(1,19);
A_RIGHT :: #run NCURSES_BITS(1,20);
A_TOP :: #run NCURSES_BITS(1,21);
A_VERTICAL :: #run NCURSES_BITS(1,22);

#if 1 {/* NCURSES_EXT_FUNCS */
	A_ITALIC :: #run NCURSES_BITS(1,23); /* ncurses extension */
	#if 0 {/* NCURSES_RGB_COLORS */
		A_FOREGROUND :: #run NCURSES_BITS(1,17); /* ncurses extension */
		A_BACKGROUND :: #run NCURSES_BITS(1,18); /* ncurses extension */
		A_DIRECT :: (A_FOREGROUND|A_BACKGROUND);
	}/* NCURSES_RGB_COLORS */
} /* NCURSES_EXT_FUNCS */

#if NCURSES_MOUSE_VERSION > 1 {
	NCURSES_MOUSE_MASK :: (b: mmask_t , mask: mmask_t) -> mmask_t #expand {
		return mask << ((b - 1) * 5);
	}
	BUTTON_CTRL :: #run NCURSES_MOUSE_MASK(6, 1);
	BUTTON_SHIFT :: #run NCURSES_MOUSE_MASK(6, 2);
	BUTTON_ALT :: #run NCURSES_MOUSE_MASK(6, 4);
} else {
	#assert false;
}

// THESE ARE NOT FROM NCURSES

KEY_ESCAPE : s32 : 0x1b;

// ctrl and alt keys
// alt + 2 = ctrl
// ctrl + 2 = ctrl | alt
// Seems like alt is 2 mask and ctrl is 4 
// Shift is 1 mask, but might get a different key if just shift is pressed...
// (actually they're not rly masks.. more like addition)

// ctrl
KEY_CRIGHT : s32 : 569;
KEY_CLEFT  : s32 : 554;
KEY_CUP    : s32 : 575;
KEY_CDOWN  : s32 : 534;

// alt
KEY_ARIGHT : s32 : 567;
KEY_ALEFT  : s32 : 552;
KEY_AUP    : s32 : 573;
KEY_ADOWN  : s32 : 532;

// alt + shift
KEY_ASRIGHT : s32 : 568;
KEY_ASLEFT  : s32 : 553;
KEY_ASUP    : s32 : 574;
KEY_ASDOWN  : s32 : 533;


