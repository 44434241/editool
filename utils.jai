
// TODO: syntax (declaration) not working here
array_ordered_remove_range :: (arr: *[..]$T, index: int, count: int) {
	for index..(arr.count-count)-1 {
		arr.*[it] = arr.*[it+count];
	}
	arr.count -= count;
}

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

array_insert_range_at :: (array: *[..] $T, index: int, items: []T) {
	assert(index >= 0);
	assert(index <= array.count);
	array_reserve(array, array.count + items.count);
	prev_count := array.count;
	array.count += items.count;
	for < index..prev_count-1 {
		array.*[it+items.count] = array.*[it];
	}
	for items {
		array.*[index+it_index] = it;
	}
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

time_this :: (name: string, really_time := true) #expand {
	start_time := current_time_monotonic();
	`defer {
		end_time := current_time_monotonic();
		duration := to_float64_seconds(end_time - start_time);
		if really_time
			log("TIME: % took % ms", name, duration * 1000);
	}
}

sign :: (v: $T) -> T 
	#modify { return IsScalar(T); } {
	if v == 0
		return v;
	return ifx v > 0 then cast(T)1 else cast(T)-1;
}

in_range_inclusive :: (v: int, l: int, r: int) -> bool {
	return l <= v && v <= r;
}

// exclusive int implies [l, r)
in_range_exclusive :: (v: int, l: int, r: int) -> bool {
	return l <= v && v < r;
}

peek :: (s: string) -> u8 {
	return peek(cast([]u8)s);
}

default_of :: inline ($T: Type) -> T {
	v: T;
	return v;
}

round_to_int :: (v: float) -> int {
	flr := floor(v);
	if (v - flr) >= 0.5
		return xx flr + 1;
	else
		return xx flr;
}

array_reverse :: (arr: *[]$T) {
	for 0..arr.count/2-1 {
		swap(*(arr.*[it]), *(arr.*[arr.count-(it+1)]));
	}
}

string_copy :: copy_string;

file_length :: (filename: string) -> int {
	f, ok := file_open(filename);
	if !ok
		return -1;
	len := file_length(f);
	file_close(*f);
	return len;
}

#scope_file

#import "Math";