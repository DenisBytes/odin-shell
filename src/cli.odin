package main

import "core:fmt"
import "core:os"
import "core:strings"

Cli_Args :: struct {
	dash_c:              bool, // -c: command
	dash_i:              bool, // -i: interactive (if -c, this is ommited)
	dash_l:              bool, // -l: login shell
	dash_s:              bool, // -s: read command from stdin
	dash_f:              bool, // -f: no startup files 	
	command_string:      string, // command (value after -c)
	script_path:         string, // if no -c, it is not a command but a script
	arg0:                string, // $0
	positional:          []string, // $1..$N
	parse_error_message: string,
}

parse_cli_args :: proc(argv: []string) -> Cli_Args {
	cli_args: Cli_Args

	i := 1
	for i < len(argv) {
		if argv[i] == "--" {
			i += 1
			break
		}
		if argv[i] == "-" {
			cli_args.dash_s = true
			i += 1
			continue
		}
		if strings.starts_with(argv[i], "-") || strings.starts_with(argv[i], "+") {
			for j in 1 ..< len(argv[i]) {
				switch argv[i][j] {
				case 'c':
					cli_args.dash_c = true
				case 'i':
					cli_args.dash_i = true
				case 'l':
					cli_args.dash_l = true
				case 's':
					cli_args.dash_s = true
				case 'f':
					cli_args.dash_f = true
				case:
					cli_args.parse_error_message = fmt.tprintf("bad option: -%c", argv[i][j])
					fmt.eprintf("%s: %s\n", SHELL_NAME, cli_args.parse_error_message)
					return cli_args
				}
			}
			i += 1
		} else {
			break
		}
	}

	rest := argv[i:]

	switch {
	case cli_args.dash_c:
		if len(rest) > 0 {
			cli_args.command_string = rest[0]
			if len(rest) > 1 {
				cli_args.arg0 = rest[1]
			} else {
				cli_args.arg0 = "zsh"
			}
			if len(rest) > 2 {
				cli_args.positional = rest[2:]
			}
		} else {
			fmt.eprintf("%s: string expected after -c", SHELL_NAME)
			cli_args.parse_error_message = "string expected after -c"
		}
	case cli_args.dash_s:
		cli_args.arg0 = "zsh"
		cli_args.positional = rest[:]
	case len(rest) > 0:
		cli_args.script_path = rest[0]
		cli_args.arg0 = rest[0]
		cli_args.positional = rest[1:]
	case:
		cli_args.arg0 = "zsh"
	}

	return cli_args
}
