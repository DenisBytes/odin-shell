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

Builtin_Handler :: proc(args: []string, redirect: Redirect)

handlers := map[string]Builtin_Handler {
	"echo"    = cmd_echo,
	"type"    = cmd_type,
	"pwd"     = cmd_pwd,
	"cd"      = cmd_cd,
	"history" = cmd_history,
	"exit"    = cmd_exit,
}

cmd_echo :: proc(args: []string, redirect: Redirect) {
	output, output_err := strings.join(args, " ", context.temp_allocator)
	if output_err != nil {
		fmt.printf("shell: error formatting echo output: %w\n", output_err)
	}

	if redirect.filename == "" {
		fmt.printf("%s\n", output)
	} else {
		redirect_output(fmt.tprintf("%s\n", output), redirect)
	}
}

cmd_type :: proc(args: []string, redirect: Redirect) {
	for arg in args {
		if arg in handlers {
			if redirect.filename == "" {
				fmt.printf("%s is a shell builtin\n", arg)
			} else {
				redirect_output(fmt.tprintf("%s is a shell builtin\n", arg), redirect)
			}

		} else {

			path := os.get_env_alloc("PATH", context.temp_allocator)
			dirs, split_path_err := strings.split(path, ":")
			if split_path_err != nil {
				fmt.printf("type: error splitting PATH: %w\n", split_path_err)
			}

			outer: for dir in dirs {
				full := strings.concatenate({dir, "/", arg}, context.temp_allocator)
				if os.exists(full) {
					stat, stat_err := os.stat(full, context.temp_allocator)
					if stat_err != nil {
						fmt.printf("type: error reading file stat: %w\n", stat_err)
					}

					if os.Permission_Flag.Execute_User in stat.mode {
						if redirect.filename == "" {
							fmt.printf("%s is %s\n", arg, full)
						} else {
							redirect_output(fmt.tprintf("%s is %s\n", arg, full), redirect)
						}
						break outer
					}
				}
			}
			fmt.printf("%s: not found\n", arg)
		}
	}
}

cmd_pwd :: proc(args: []string, redirect: Redirect) {
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.printf("pwd: %w\n", pwd_err)
	}

	if redirect.filename == "" {
		fmt.printf("%s\n", pwd)
	} else {
		redirect_output(fmt.tprintf("%s\n", pwd), redirect)
	}
}

cmd_cd :: proc(args: []string, redirect: Redirect) {
	if len(args) > 1 {
		fmt.print("cd: Too many arguments\n")
	} else {
		path := args[0]
		if strings.has_prefix(args[0], "~") {
			home := os.get_env_alloc("HOME", context.temp_allocator)
			index := strings.index(args[0], "~")
			if index != -1 {
				path = strings.concatenate({home, args[0][index + 1:]}, context.temp_allocator)
			}
		}

		cd_err := os.change_directory(path)
		if cd_err != nil {
			fmt.printf("cd: %s: No such file or directory\n", path)
		}
	}
}

cmd_history :: proc(args: []string, redirect: Redirect) {
	starting_index := 0
	history_filename := ""
	if len(args) > 0 {
		if args[0] == "-w" {
			if len(args) > 1 {
				output, output_err := strings.join(
					commands_history[:],
					"\n",
					context.temp_allocator,
				)
				if output_err != nil {
					fmt.printf("history: parsing error: %w\n", output_err)
				}
				final_output, _ := strings.concatenate({output, "\n"}, context.temp_allocator)
				redirect_output(final_output, Redirect{filename = args[1], append_mode = false})

				return
			} else {
				arg, ok := strconv.parse_int(args[0], 10)
				if ok {
					starting_index = len(commands_history) - arg
				}
			}
		} else if args[0] == "-a" {
			if len(args) > 1 {
				output, output_err := strings.join(
					commands_history[last_append_index:],
					"\n",
					context.temp_allocator,
				)
				if output_err != nil {
					fmt.printf("history: parsing error: %w\n", output_err)
				}
				final_output, _ := strings.concatenate({output, "\n"}, context.temp_allocator)
				redirect_output(final_output, Redirect{filename = args[1], append_mode = true})
				last_append_index = len(commands_history)
				return
			} else {
				arg, ok := strconv.parse_int(args[0], 10)
				if ok {
					starting_index = len(commands_history) - arg
				}
			}
		} else if args[0] == "-r" {
			if len(args) > 1 {

				file_bytes, file_bytes_err := os.read_entire_file(args[1], context.temp_allocator)
				if file_bytes_err != nil {
					fmt.printf("history: parsing error: %w\n", file_bytes_err)
				}

				history_commands, history_commands_err := strings.split(
					string(file_bytes[:]),
					"\n",
				)
				if history_commands_err != nil {
					fmt.printf("history: parsing error: %w\n", history_commands_err)
					return
				}

				for c in history_commands {
					if len(c) != 0 {
						append(&commands_history, strings.clone(c))
					}
				}
				return
			} else {
				fmt.printf("history: -r filename argument missing\n")
				return
			}
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
}

cmd_exit :: proc(args: []string, redirect: Redirect) {

	history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
	if len(history_file) > 0 {
		output, output_err := strings.join(
			commands_history[last_append_index:],
			"\n",
			context.temp_allocator,
		)
		if output_err != nil {
			fmt.printf("history: parsing error: %w\n", output_err)
			return
		}
		final_output, _ := strings.concatenate({output, "\n"}, context.temp_allocator)
		redirect_output(final_output, Redirect{filename = history_file, append_mode = true})

	}
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &original_termios)
	os.exit(0)
}
