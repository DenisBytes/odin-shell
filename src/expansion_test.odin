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


@(test)
test_expand_param_no_dollar :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("hello world")

	testing.expect_value(t, result, "hello world")
}


@(test)
test_expand_param_empty_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("")

	testing.expect_value(t, result, "")
}


@(test)
test_expand_param_simple_var :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_TEST_SIMPLE", "hello")
	result := expand_parameters("$OSH_TEST_SIMPLE")
	os.unset_env("OSH_TEST_SIMPLE")

	testing.expect_value(t, result, "hello")
}


@(test)
test_expand_param_braced_var :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_TEST_BRACED", "world")
	result := expand_parameters("${OSH_TEST_BRACED}")
	os.unset_env("OSH_TEST_BRACED")

	testing.expect_value(t, result, "world")
}


@(test)
test_expand_param_unset_var :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_TOTALLY_UNSET")
	result := expand_parameters("$OSH_TOTALLY_UNSET")

	testing.expect_value(t, result, "")
}


@(test)
test_expand_param_unset_braced_var :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_TOTALLY_UNSET")
	result := expand_parameters("${OSH_TOTALLY_UNSET}")

	testing.expect_value(t, result, "")
}


@(test)
test_expand_param_exit_code :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	last_exit_code = 42
	result := expand_parameters("$?")
	last_exit_code = 0

	testing.expect_value(t, result, "42")
}


@(test)
test_expand_param_exit_code_zero :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	last_exit_code = 0
	result := expand_parameters("$?")

	testing.expect_value(t, result, "0")
}


@(test)
test_expand_param_exit_code_127 :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	last_exit_code = 127
	result := expand_parameters("$?")
	last_exit_code = 0

	testing.expect_value(t, result, "127")
}


@(test)
test_expand_param_shell_name :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("$0")

	testing.expect_value(t, result, SHELL_NAME)
}


@(test)
test_expand_param_pid :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("$$")

	testing.expect(t, len(result) > 0, "expected non-empty PID string")
}


@(test)
test_expand_param_mixed_text_and_var :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_TEST_MIX", "there")
	result := expand_parameters("hello $OSH_TEST_MIX friend")
	os.unset_env("OSH_TEST_MIX")

	testing.expect_value(t, result, "hello there friend")
}


@(test)
test_expand_param_multiple_vars :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_A", "foo")
	os.set_env("OSH_B", "bar")
	result := expand_parameters("$OSH_A/$OSH_B")
	os.unset_env("OSH_A")
	os.unset_env("OSH_B")

	testing.expect_value(t, result, "foo/bar")
}


@(test)
test_expand_param_adjacent_vars :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_X", "ab")
	os.set_env("OSH_Y", "cd")
	result := expand_parameters("${OSH_X}${OSH_Y}")
	os.unset_env("OSH_X")
	os.unset_env("OSH_Y")

	testing.expect_value(t, result, "abcd")
}


@(test)
test_expand_param_trailing_dollar :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("hello$")

	testing.expect_value(t, result, "hello$")
}


@(test)
test_expand_param_dollar_space :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("$ hello")

	testing.expect_value(t, result, "$ hello")
}


@(test)
test_expand_param_dollar_slash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("$/foo")

	testing.expect_value(t, result, "$/foo")
}


@(test)
test_expand_param_unclosed_brace :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("${FOO")

	testing.expect_value(t, result, "${FOO")
}


@(test)
test_expand_param_default_used :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_UNSET_DEF")
	result := expand_parameters("${OSH_UNSET_DEF:-fallback}")

	testing.expect_value(t, result, "fallback")
}


@(test)
test_expand_param_default_not_used :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_SET_DEF", "real")
	result := expand_parameters("${OSH_SET_DEF:-fallback}")
	os.unset_env("OSH_SET_DEF")

	testing.expect_value(t, result, "real")
}


@(test)
test_expand_param_assign_used :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_UNSET_ASSIGN")
	result := expand_parameters("${OSH_UNSET_ASSIGN:=assigned}")

	testing.expect_value(t, result, "assigned")

	env_val := os.get_env_alloc("OSH_UNSET_ASSIGN", context.temp_allocator)
	testing.expect_value(t, env_val, "assigned")
	os.unset_env("OSH_UNSET_ASSIGN")
}


@(test)
test_expand_param_assign_not_used :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_SET_ASSIGN", "existing")
	result := expand_parameters("${OSH_SET_ASSIGN:=ignored}")
	os.unset_env("OSH_SET_ASSIGN")

	testing.expect_value(t, result, "existing")
}


@(test)
test_expand_param_alt_set :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_SET_ALT", "something")
	result := expand_parameters("${OSH_SET_ALT:+replacement}")
	os.unset_env("OSH_SET_ALT")

	testing.expect_value(t, result, "replacement")
}


@(test)
test_expand_param_alt_unset :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_UNSET_ALT")
	result := expand_parameters("${OSH_UNSET_ALT:+replacement}")

	testing.expect_value(t, result, "")
}


@(test)
test_expand_param_suffix_strip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_PATH", "/home/user/file.txt")
	result := expand_parameters("${OSH_PATH%.txt}")
	os.unset_env("OSH_PATH")

	testing.expect_value(t, result, "/home/user/file")
}


@(test)
test_expand_param_suffix_no_match :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_PATH2", "/home/user/file.txt")
	result := expand_parameters("${OSH_PATH2%.rs}")
	os.unset_env("OSH_PATH2")

	testing.expect_value(t, result, "/home/user/file.txt")
}


@(test)
test_expand_param_prefix_strip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_PRE", "/home/user/file.txt")
	result := expand_parameters("${OSH_PRE#/home/}")
	os.unset_env("OSH_PRE")

	testing.expect_value(t, result, "user/file.txt")
}


@(test)
test_expand_param_prefix_no_match :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_PRE2", "/home/user/file.txt")
	result := expand_parameters("${OSH_PRE2#/var/}")
	os.unset_env("OSH_PRE2")

	testing.expect_value(t, result, "/home/user/file.txt")
}


@(test)
test_expand_param_underscore_in_name :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_MY_VAR_123", "works")
	result := expand_parameters("$OSH_MY_VAR_123")
	os.unset_env("OSH_MY_VAR_123")

	testing.expect_value(t, result, "works")
}


@(test)
test_expand_param_var_then_punctuation :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.set_env("OSH_STOP", "val")
	result := expand_parameters("$OSH_STOP!")
	os.unset_env("OSH_STOP")

	testing.expect_value(t, result, "val!")
}


@(test)
test_expand_param_only_dollar :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("$")

	testing.expect_value(t, result, "$")
}


@(test)
test_expand_param_double_dollar_in_text :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	result := expand_parameters("pid=$$")

	testing.expect(t, len(result) > 4, "expected pid= plus digits")
	testing.expect(t, result[:4] == "pid=", "expected pid= prefix")
}


@(test)
test_expand_param_exit_code_in_text :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	last_exit_code = 7
	result := expand_parameters("code=$?!")
	last_exit_code = 0

	testing.expect_value(t, result, "code=7!")
}


@(test)
test_expand_param_default_empty_value :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	os.unset_env("OSH_EMPTY_DEF")
	result := expand_parameters("${OSH_EMPTY_DEF:-}")

	testing.expect_value(t, result, "")
}
