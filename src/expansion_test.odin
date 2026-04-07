package main

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_expand_tilde_middle_or_word :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("/foo/~bar")

	testing.expect_value(t, word, "/foo/~bar")
}


@(test)
test_expand_tilde_just_slash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("~/")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "/"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_double_slash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("~//foo")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "//foo"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_with_dots :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("~/../etc")
	home := os.get_env_alloc("HOME", context.temp_allocator)

	path, _ := strings.concatenate({home, "/../etc"}, context.temp_allocator)
	testing.expect_value(t, word, path)
}


@(test)
test_expand_tilde_root_with_path :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("~root/.zshrc")

	testing.expect_value(t, word, "/root/.zshrc")
}


@(test)
test_expand_tilde_only_tilde_in_quotes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	word := expand_tilde("\"~\"")

	testing.expect_value(t, word, "\"~\"")
}