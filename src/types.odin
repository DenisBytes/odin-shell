package main

import "base:runtime"
import "core:io"

// %% is escape sequence to print % in fmt.printf
PROMPT :: "% "

Parse_Result :: struct {
	command:         string,
	args:            []string,
	stdout_redirect: Redirect,
	stderr_redirect: Redirect,
}

Shell_Error :: enum {
	Empty_Input,
	Unclosed_Quote,
	Command_Not_Found,
	Fork_Failed,
	Pipe_Failed,
	Redirect_Failed,
	Exec_Failed,
	Parse_Error,
}

Error :: union {
	Shell_Error,
	runtime.Allocator_Error,
	io.Error,
}

Redirect :: struct {
	filename:    string,
	append_mode: bool,
}
