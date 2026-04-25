package main

import "core:sys/posix"

last_exit_code: i32 = 0
is_tty: b32 = posix.isatty(0)
interactive: bool
login: bool
scriptname: string = "zsh"
lineno: int = 1
