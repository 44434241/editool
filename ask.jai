


Ask_State :: struct {
	// returns true if it should ask gain?
	// callback with (0) is a special thing saying that it is done !
	Callback :: #type (s32, *void) -> bool;
	callback: Callback;
	request: string; // @Leak
	user_data: *void;
}

Ask :: Ask_State;

ask_for_char :: (req: string, cb: Ask.Callback, dat: *void = null) {
	using context.ask;
	if callback {
		callback(0, user_data);
		callback = null;
		user_data = null;
	}
	callback = cb;
	request = req;
	user_data = dat;
	change_edit_mode(.ASK);
}

handle_ask_char :: (ch: s32) {
	using context.ask;
	assert(callback != null, "What u doing man");
	if ch == KEY_ESCAPE
		ch = 0; // hmh
	should_continue := callback(ch, user_data);
	if !should_continue {
		callback = null;
		user_data = null;
		request = "";
		change_edit_mode(.COMMAND);
	}
}

exit_ask_mode :: () {
	using context.ask;
	if callback {
		callback(0, user_data);
		request = "";
		callback = null;
	}
}