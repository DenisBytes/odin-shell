package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_resolve_ls :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	path, found, err := resolve_command("ls")

	testing.expect_value(t, found, true)
	testing.expect(t, strings.ends_with(path, "/ls"), "path should end with /ls")
	testing.expect(t, os.exists(path), "resolved path should exists")
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_resolve_nonexistent :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	path, found, err := resolve_command("zsh_no_real_command")

	testing.expect_value(t, found, false)
	testing.expect(t, path == "", "path should be empty")
	// func only returns only allocating errors, there is no "business logic" error
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_resolve_empty_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	path, found, err := resolve_command("")

	testing.expect_value(t, found, false)
	testing.expect_value(t, path, "")
	testing.expect(t, err == .Empty_Input, "expected Empty_Input error")
}


@(test)
test_resolve_directory_not_executable :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	tmp_dir := "/tmp/osh_test_XXXX"
	tmp_command := "fakecmd"

	dir_err := os.make_directory(tmp_dir)
	if dir_err != nil {
		os.remove(tmp_dir)
		testing.fail_now(t, "could not create test dir")
	}

	f, f_err := os.create(fmt.tprintf("%s/%s", tmp_dir, tmp_command))
	if f_err != nil {
		os.close(f)
		os.remove(fmt.tprintf("%s/%s", tmp_dir, tmp_command))
		os.remove(tmp_dir)
		testing.fail_now(t, "could not create test file")
	}

	old_path_env := os.get_env_alloc("PATH", context.temp_allocator)
	set_env_err := os.set_env("PATH", fmt.tprintf("%s:%s", tmp_dir, old_path_env))
	if set_env_err != nil {
		os.close(f)
		os.remove(fmt.tprintf("%s/%s", tmp_dir, tmp_command))
		os.remove(tmp_dir)
		os.set_env("PATH", old_path_env)
		testing.fail_now(t, "could not set env")
	}

	os.close(f)

	path, found, err := resolve_command(tmp_command)

	testing.expect_value(t, found, false)
	testing.expect_value(t, path, "")
	// func only returns only allocating errors, there is no "business logic" error
	testing.expect(t, err == nil, "expected no error")

	// cleanup
	os.remove(fmt.tprintf("%s/%s", tmp_dir, tmp_command))
	os.remove(tmp_dir)
	os.set_env("PATH", old_path_env)
}


@(test)
test_resolve_deterministic :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	path, found, err := resolve_command("ls")
	testing.expect_value(t, found, true)
	testing.expect(t, strings.ends_with(path, "/ls"), "path should end with /ls")
	testing.expect(t, os.exists(path), "resolved path should exists")
	testing.expect(t, err == nil, "expected no error")

	path2, found2, err2 := resolve_command("ls")
	testing.expect_value(t, path, path2)
}


@(test)
test_resolve_builtin_not_in_path :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	path, found, err := resolve_command("cd")
	testing.expect_value(t, found, false)
	// func only returns only allocating errors, there is no "business logic" error
	testing.expect(t, err == nil, "expected no error")
}
