package main

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_expand_tilde_middle_or_word :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("/foo/~bar")

	testing.expect_value(t, word, "/foo/~bar")
}


@(test)
test_expand_tilde_just_slash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("~/")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "/"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_double_slash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("~//foo")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "//foo"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_with_dots :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("~/../etc")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "/../etc"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_root_with_path :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("~root/.zshrc")

	testing.expect_value(t, word, "/root/.zshrc")
}


@(test)
test_expand_tilde_only_tilde_in_quotes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, _ := expand_tilde("\"~\"")

	testing.expect_value(t, word, "\"~\"")
}


@(test)
test_expand_tilde_unknown_user :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word, ok := expand_tilde("~unknownuser")

	testing.expect_value(t, word, "~unknownuser")
	testing.expect_value(t, ok, false)
}


@(test)
test_expand_braces_comma :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a,b,c}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "b")
	testing.expect_value(t, result[2], "c")
}


@(test)
test_expand_braces_comma_prefix_suffix :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("pre{a,b}suf")

	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "preasuf")
	testing.expect_value(t, result[1], "prebsuf")
}


@(test)
test_expand_braces_comma_prefix_only :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("pre{x,y}")

	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "prex")
	testing.expect_value(t, result[1], "prey")
}


@(test)
test_expand_braces_comma_suffix_only :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{x,y}suf")

	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "xsuf")
	testing.expect_value(t, result[1], "ysuf")
}


@(test)
test_expand_braces_comma_empty_element :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a,,b}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "")
	testing.expect_value(t, result[2], "b")
}


@(test)
test_expand_braces_comma_leading_empty :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{,a}")

	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "")
	testing.expect_value(t, result[1], "a")
}


@(test)
test_expand_braces_comma_trailing_empty :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a,}")

	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "")
}


@(test)
test_expand_braces_comma_nested :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a,{b,c}}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "b")
	testing.expect_value(t, result[2], "c")
}


@(test)
test_expand_braces_comma_nested_prefix :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a,b{c,d}}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "bc")
	testing.expect_value(t, result[2], "bd")
}


@(test)
test_expand_braces_range_alpha :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a..d}")

	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "a")
	testing.expect_value(t, result[1], "b")
	testing.expect_value(t, result[2], "c")
	testing.expect_value(t, result[3], "d")
}


@(test)
test_expand_braces_range_alpha_reverse :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{d..a}")

	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "d")
	testing.expect_value(t, result[1], "c")
	testing.expect_value(t, result[2], "b")
	testing.expect_value(t, result[3], "a")
}


@(test)
test_expand_braces_range_alpha_single :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{a..a}")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "a")
}


@(test)
test_expand_braces_range_alpha_uppercase :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{A..D}")

	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "A")
	testing.expect_value(t, result[1], "B")
	testing.expect_value(t, result[2], "C")
	testing.expect_value(t, result[3], "D")
}


@(test)
test_expand_braces_range_alpha_prefix_suffix :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("file_{a..c}.txt")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "file_a.txt")
	testing.expect_value(t, result[1], "file_b.txt")
	testing.expect_value(t, result[2], "file_c.txt")
}


@(test)
test_expand_braces_range_alpha_prefix_only :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("item_{x..z}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "item_x")
	testing.expect_value(t, result[1], "item_y")
	testing.expect_value(t, result[2], "item_z")
}


@(test)
test_expand_braces_range_numeric :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{1..5}")

	testing.expect_value(t, len(result), 5)
	testing.expect_value(t, result[0], "1")
	testing.expect_value(t, result[1], "2")
	testing.expect_value(t, result[2], "3")
	testing.expect_value(t, result[3], "4")
	testing.expect_value(t, result[4], "5")
}


@(test)
test_expand_braces_range_numeric_reverse :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{5..1}")

	testing.expect_value(t, len(result), 5)
	testing.expect_value(t, result[0], "5")
	testing.expect_value(t, result[1], "4")
	testing.expect_value(t, result[2], "3")
	testing.expect_value(t, result[3], "2")
	testing.expect_value(t, result[4], "1")
}


@(test)
test_expand_braces_range_numeric_negative :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{-2..2}")

	testing.expect_value(t, len(result), 5)
	testing.expect_value(t, result[0], "-2")
	testing.expect_value(t, result[1], "-1")
	testing.expect_value(t, result[2], "0")
	testing.expect_value(t, result[3], "1")
	testing.expect_value(t, result[4], "2")
}


@(test)
test_expand_braces_range_numeric_single :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{2..2}")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "2")
}


@(test)
test_expand_braces_range_numeric_padded :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{01..03}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "01")
	testing.expect_value(t, result[1], "02")
	testing.expect_value(t, result[2], "03")
}


@(test)
test_expand_braces_range_numeric_padded_asymmetric :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{001..3}")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "001")
	testing.expect_value(t, result[1], "002")
	testing.expect_value(t, result[2], "003")
}


@(test)
test_expand_braces_range_numeric_step :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{001..10..3}")

	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "001")
	testing.expect_value(t, result[1], "004")
	testing.expect_value(t, result[2], "007")
	testing.expect_value(t, result[3], "010")
}


@(test)
test_expand_braces_range_numeric_step_reverse :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{10..001..3}")

	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "010")
	testing.expect_value(t, result[1], "007")
	testing.expect_value(t, result[2], "004")
	testing.expect_value(t, result[3], "001")
}


@(test)
test_expand_braces_range_with_prefix_suffix :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("file{1..3}.txt")

	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "file1.txt")
	testing.expect_value(t, result[1], "file2.txt")
	testing.expect_value(t, result[2], "file3.txt")
}


@(test)
test_expand_braces_no_expansion_plain :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("hello")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "hello")
}


@(test)
test_expand_braces_no_expansion_unmatched_open :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{hello")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "{hello")
}


@(test)
test_expand_braces_no_expansion_no_comma_or_range :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{abc}")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "{abc}")
}


@(test)
test_expand_braces_no_expansion_empty_braces :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("{}")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "{}")
}


@(test)
test_expand_braces_no_expansion_empty_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_braces("")

	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "")
}
