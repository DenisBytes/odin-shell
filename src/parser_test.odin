package main

import "core:testing"


@(test)
test_parse_simple_command :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("ls")

	testing.expect_value(t, parse_result.command, "ls")
	testing.expect_value(t, len(parse_result.args), 0)
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_with_args :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hello world")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 2)
	testing.expect_value(t, parse_result.args[0], "hello")
	testing.expect_value(t, parse_result.args[1], "world")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_empty_input :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("")

	e, ok := err.(Shell_Error)
	testing.expect(t, ok, "expected Shell_Error")
	testing.expect_value(t, e, Shell_Error.Empty_Input)

	testing.expect_value(t, parse_result.command, "")
	testing.expect_value(t, len(parse_result.args), 0)
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
}


@(test)
test_parse_single_quotes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo 'hello world'")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hello world")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_double_quotes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo \"hello world\"")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hello world")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_backslash :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hello\\ world")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hello world")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_stdout_redirect :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hi > out.txt")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hi")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "out.txt")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_stdout_redirect_append :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hi >> out.txt")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hi")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "out.txt")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, true)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_stderr_redirect :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hi 2> err.txt")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hi")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "err.txt")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_stderr_redirect_append :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hi 2>> err.txt")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "hi")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "err.txt")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, true)
	testing.expect(t, err == nil, "expected no error")
}


@(test)
test_parse_whitespace_edge_cases :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("  echo  hello   world       ")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 2)
	testing.expect_value(t, parse_result.args[0], "hello")
	testing.expect_value(t, parse_result.args[1], "world")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")


	parse_result2, err2 := parse_input("  ")

	e, ok := err2.(Shell_Error)
	testing.expect(t, ok, "expected Shell_Error")
	testing.expect_value(t, e, Shell_Error.Empty_Input)

	testing.expect_value(t, parse_result2.command, "")
	testing.expect_value(t, len(parse_result2.args), 0)
	testing.expect_value(t, parse_result2.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result2.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result2.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result2.stderr_redirect.append_mode, false)


	parse_result3, err3 := parse_input("echo  ")

	testing.expect_value(t, parse_result3.command, "echo")
	testing.expect_value(t, len(parse_result3.args), 0)
	testing.expect_value(t, parse_result3.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result3.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result3.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result3.stderr_redirect.append_mode, false)
	testing.expect(t, err3 == nil, "expected no error")
}


@(test)
test_parse_quote_edge_cases :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo 'hello'world")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "helloworld")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")


	parse_result2, err2 := parse_input("echo hello'world foo'bar")

	testing.expect_value(t, parse_result2.command, "echo")
	testing.expect_value(t, len(parse_result2.args), 1)
	testing.expect_value(t, parse_result2.args[0], "helloworld foobar")
	testing.expect_value(t, parse_result2.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result2.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result2.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result2.stderr_redirect.append_mode, false)
	testing.expect(t, err2 == nil, "expected no error")


	parse_result3, err3 := parse_input("echo \"hello\"'world'")

	testing.expect_value(t, parse_result3.command, "echo")
	testing.expect_value(t, len(parse_result3.args), 1)
	testing.expect_value(t, parse_result3.args[0], "helloworld")
	testing.expect_value(t, parse_result3.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result3.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result3.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result3.stderr_redirect.append_mode, false)
	testing.expect(t, err3 == nil, "expected no error")


	parse_result4, err4 := parse_input("echo ''")

	testing.expect_value(t, parse_result4.command, "echo")
	testing.expect_value(t, len(parse_result4.args), 0)
	testing.expect_value(t, parse_result4.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result4.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result4.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result4.stderr_redirect.append_mode, false)
	testing.expect(t, err4 == nil, "expected no error")


	parse_result5, err5 := parse_input("echo \"\"")

	testing.expect_value(t, parse_result5.command, "echo")
	testing.expect_value(t, len(parse_result5.args), 0)
	testing.expect_value(t, parse_result5.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result5.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result5.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result5.stderr_redirect.append_mode, false)
	testing.expect(t, err5 == nil, "expected no error")


	parse_result6, err6 := parse_input("echo 'hello\\\"world'")

	testing.expect_value(t, parse_result6.command, "echo")
	testing.expect_value(t, len(parse_result6.args), 1)
	testing.expect_value(t, parse_result6.args[0], "hello\\\"world")
	testing.expect_value(t, parse_result6.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result6.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result6.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result6.stderr_redirect.append_mode, false)
	testing.expect(t, err6 == nil, "expected no error")


	parse_result7, err7 := parse_input("echo \"hello'world\"")

	testing.expect_value(t, parse_result7.command, "echo")
	testing.expect_value(t, len(parse_result7.args), 1)
	testing.expect_value(t, parse_result7.args[0], "hello'world")
	testing.expect_value(t, parse_result7.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result7.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result7.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result7.stderr_redirect.append_mode, false)
	testing.expect(t, err7 == nil, "expected no error")
}


@(test)
test_parse_backslash_edge_cases :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	parse_result, err := parse_input("echo hello\\world")

	testing.expect_value(t, parse_result.command, "echo")
	testing.expect_value(t, len(parse_result.args), 1)
	testing.expect_value(t, parse_result.args[0], "helloworld")
	testing.expect_value(t, parse_result.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result.stderr_redirect.append_mode, false)
	testing.expect(t, err == nil, "expected no error")


	parse_result2, err2 := parse_input("echo test\\")

	testing.expect_value(t, parse_result2.command, "echo")
	testing.expect_value(t, len(parse_result2.args), 1)
	testing.expect_value(t, parse_result2.args[0], "test")
	testing.expect_value(t, parse_result2.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result2.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result2.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result2.stderr_redirect.append_mode, false)
	testing.expect(t, err2 == nil, "expected no error")

	parse_result3, err3 := parse_input("echo \\n")

	testing.expect_value(t, parse_result3.command, "echo")
	testing.expect_value(t, len(parse_result3.args), 1)
	testing.expect_value(t, parse_result3.args[0], "n")
	testing.expect_value(t, parse_result3.stdout_redirect.filename, "")
	testing.expect_value(t, parse_result3.stdout_redirect.append_mode, false)
	testing.expect_value(t, parse_result3.stderr_redirect.filename, "")
	testing.expect_value(t, parse_result3.stderr_redirect.append_mode, false)
	testing.expect(t, err3 == nil, "expected no error")
}
