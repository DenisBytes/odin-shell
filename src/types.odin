package main

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:sys/posix"

SHELL_NAME :: "zsh"
PROMPT :: "% "

Parse_Result :: struct {
	command:         string,
	args:            []string,
	stdin_redirect:  Redirect,
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

oom_fatal :: proc() -> ! {
	fmt.eprintf("%s: fatal error: out of memory\n", SHELL_NAME)
	posix.exit(1)
}
