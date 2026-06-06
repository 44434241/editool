
array_insert_at :: (array: *[..] $T, index: int) -> *T {
	assert(index >= 0);
	assert(index <= array.count);
	maybe_grow(xx array, size_of(T));
	array.count += 1;
	i := array.count-1;
	while i > index {
		array.*[i] = array.*[i-1];
		i -= 1;
	}
	Initialize(*(array.*[index]));
	return *(array.*[index]);
}

advance :: inline (array: []$T, amount: int) -> []T {
	assert(0 <= amount);
	assert(amount <= array.count);
	return .{ data = array.data + amount, count = array.count - amount };
}

// overload for s32
is_digit :: (c: s32) -> bool {
	return c >= #char "0" && c <= #char "9";
}

array_adds :: (a: *[..]u8, s: string) {
	array_add(a, .. cast([]u8)s);
}
