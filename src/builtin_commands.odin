#+feature dynamic-literals
package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

BUILTIN_COMMANDS :: []string{"echo", "type", "pwd", "cd", "history", "exit"}
commands_history: [dynamic]string
last_append_index := 0

Builtin_Handler :: proc(args: []string, redirect: Redirect) -> i32

handlers := map[string]Builtin_Handler {
	"echo"    = cmd_echo,
	"type"    = cmd_type,
	"pwd"     = cmd_pwd,
	"cd"      = cmd_cd,
	"history" = cmd_history,
	"exit"    = cmd_exit,
}

cmd_echo :: proc(args: []string, redirect: Redirect) -> i32 {
	output, output_err := strings.join(args, " ", context.temp_allocator)
	if output_err != nil {oom_fatal()}

	if redirect.filename == "" {
		fmt.printf("%s\n", output)
	} else {
		redirect_output(fmt.tprintf("%s\n", output), redirect)
	}
	return 0
}

cmd_type :: proc(args: []string, redirect: Redirect) -> i32 {
	for arg in args {
		if arg in handlers {
			if redirect.filename == "" {
				fmt.printf("%s is a shell builtin\n", arg)
			} else {
				redirect_output(fmt.tprintf("%s is a shell builtin\n", arg), redirect)
			}
		} else {
			path, found, _ := resolve_command(arg)
			if found {
				if redirect.filename == "" {
					fmt.printf("%s is %s\n", arg, path)
				} else {
					redirect_output(fmt.tprintf("%s is %s\n", arg, path), redirect)
				}
			} else {
				fmt.eprintf("%s not found\n", arg)
			}
		}
	}
	return 0
}

cmd_pwd :: proc(args: []string, redirect: Redirect) -> i32 {
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.eprintf("%s: unable ro read current directory\n", SHELL_NAME)
		return 1
	}

	if redirect.filename == "" {
		fmt.printf("%s\n", pwd)
	} else {
		redirect_output(fmt.tprintf("%s\n", pwd), redirect)
	}
	return 0
}

cmd_cd :: proc(args: []string, redirect: Redirect) -> i32 {
	if len(args) > 1 {
		fmt.eprint("cd: too many arguments\n")
		return 1
	} else {
		if len(args) == 0 {
			home := os.get_env_alloc("HOME", context.temp_allocator)
			cd_err := os.change_directory(home)
			if cd_err != nil {
				fmt.eprintf("cd: no such file or directory: %s\n", home)
				return 1
			}
			return 0
		} else {
			path := args[0]

			cd_err := os.change_directory(path)
			if cd_err != nil {
				fmt.eprintf("cd: no such file or directory: %s\n", path)
				return 1
			}
			return 0
		}
	}
}

cmd_history :: proc(args: []string, redirect: Redirect) -> i32 {
	starting_index := 0
	history_filename := ""
	if len(args) > 0 {
		if args[0] == "-w" {
			output, output_err := strings.join(commands_history[:], "\n", context.temp_allocator)
			if output_err != nil {
				fmt.eprintf("history: parsing error: %w\n", output_err)
				return 1
			}

			filename := ""
			if len(args) > 1 {
				filename = args[1]
			} else {
				history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
				if len(history_file) <= 0 {
					fmt.eprintf("history: HISTFILE not set\n")
					return 0
				} else {
					filename = history_file
				}
			}

			final_output, concat_err := strings.concatenate({output, "\n"}, context.temp_allocator)
			if concat_err != nil {oom_fatal()}

			redirect_output(final_output, Redirect{filename = filename, append_mode = false})
			last_append_index = len(commands_history)
			return 0
		} else if args[0] == "-a" {
			output, output_err := strings.join(
				commands_history[last_append_index:],
				"\n",
				context.temp_allocator,
			)
			if output_err != nil {
				fmt.eprintf("history: parsing error: %w\n", output_err)
				return 1
			}

			final_output, concat_err := strings.concatenate({output, "\n"}, context.temp_allocator)
			if concat_err != nil {oom_fatal()}

			filename := ""
			if len(args) > 1 {
				filename = args[1]
			} else {
				history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
				if len(history_file) <= 0 {
					fmt.eprintf("history: HISTFILE not set\n")
					return 0
				} else {
					filename = history_file
				}
			}
			redirect_output(final_output, Redirect{filename = filename, append_mode = true})
			last_append_index = len(commands_history)
			return 0
		} else if args[0] == "-r" {

			filename := ""
			if len(args) > 1 {
				filename = args[1]
			} else {
				history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
				if len(history_file) <= 0 {
					fmt.eprintf("history: HISTFILE not set\n")
					return 0
				} else {
					filename = history_file
				}
			}

			file_bytes, file_bytes_err := os.read_entire_file(filename, context.temp_allocator)
			if file_bytes_err != nil {
				fmt.eprintf("history: parsing error: %w\n", file_bytes_err)
				return 0
			}

			history_commands, history_commands_err := strings.split(string(file_bytes[:]), "\n")
			if history_commands_err != nil {
				fmt.eprintf("history: parsing error: %w\n", history_commands_err)
				return 0
			}

			for c in history_commands {
				if len(c) != 0 {
					append(&commands_history, strings.clone(c))
				}
			}
			last_append_index = len(commands_history)
			return 0
		} else {
			arg, ok := strconv.parse_int(args[0], 10)
			if ok {
				starting_index = len(commands_history) - arg
			}
		}
	}

	for i in starting_index ..< len(commands_history) {
		num_str := fmt.tprintf("%d", i + 1)
		padding := 5 - len(num_str)
		for _ in 0 ..< padding {
			fmt.printf(" ")
		}
		if redirect.filename == "" {
			fmt.printf("%s  %s\n", num_str, commands_history[i])
		} else {
			line := fmt.tprintf("%s  %s\n", num_str, commands_history[i])
			redirect_output(line, redirect)
		}
	}
	return 0
}

cmd_exit :: proc(args: []string, redirect: Redirect) -> i32 {
	history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
	if len(history_file) > 0 {
		output, output_err := strings.join(
			commands_history[last_append_index:],
			"\n",
			context.temp_allocator,
		)
		if output_err != nil {oom_fatal()}

		final_output, _ := strings.concatenate({output, "\n"}, context.temp_allocator)
		redirect_output(final_output, Redirect{filename = history_file, append_mode = true})

	}
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &original_termios)
	os.exit(0)
}
