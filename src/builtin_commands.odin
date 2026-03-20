#+feature dynamic-literals
package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

commands_history: [dynamic]string

BUILTIN_COMMANDS := []string{"echo", "type", "pwd", "cd", "history", "exit"}

Commands_Proc :: proc(args: []string, filename: string, append_file: bool)

handlers := map[string]Commands_Proc {
	"echo"    = cmd_echo,
	"type"    = cmd_type,
	"pwd"     = cmd_pwd,
	"cd"      = cmd_cd,
	"history" = cmd_history,
	"exit"    = cmd_exit,
}

cmd_echo :: proc(args: []string, filename: string, append_file: bool) {
	output, output_err := strings.join(args, " ")
	if output_err != nil {
		fmt.printf("shell: error formatting echo output: %w\n", output_err)
	}

	if filename == "" {
		fmt.printf("%s\n", output)
	} else {
		redirect_output(fmt.tprintf("%s\n", output), filename, append_file)
	}
}

cmd_type :: proc(args: []string, filename: string, append_file: bool) {
	for arg in args {
		outer: switch arg {
		case "type", "echo", "pwd", "cd", "history", "exit":
			if filename == "" {
				fmt.printf("%s is a shell builtin\n", arg)
			} else {
				redirect_output(fmt.tprintf("%s is a shell builtin\n", arg), filename, append_file)
			}
		case:
			path := os.get_env_alloc("PATH", context.temp_allocator)
			dirs, split_path_err := strings.split(path, ":")
			if split_path_err != nil {
				fmt.printf("type: error splitting PATH: %w\n", split_path_err)
			}

			for dir in dirs {
				full := strings.concatenate({dir, "/", arg})
				if os.exists(full) {
					stat, stat_err := os.stat(full, context.temp_allocator)
					if stat_err != nil {
						fmt.printf("type: error reading file stat: %w\n", stat_err)
					}

					// This is for odin-2026-03-nightly
					if os.Permission_Flag.Execute_User in stat.mode {
						// // This is for odin-2025-07 (codecrafters version)
						// if stat.mode & 0o100 != 0 {

						if filename == "" {
							fmt.printf("%s is %s\n", arg, full)
						} else {
							redirect_output(
								fmt.tprintf("%s is %s\n", arg, full),
								filename,
								append_file,
							)
						}
						break outer
					}
				}
			}
			fmt.printf("%s: not found\n", arg)
		}
	}
}

cmd_pwd :: proc(args: []string, filename: string, append_file: bool) {
	// This is for odin-2026-03-nightly
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.printf("pwd: %w\n", pwd_err)
	}

	// // This is for odin-2025-07 (codecrafters version)
	// pwd := os.get_current_directory(context.temp_allocator)


	if filename == "" {
		fmt.printf("%s\n", pwd)
	} else {
		redirect_output(fmt.tprintf("%s\n", pwd), filename, append_file)
	}
}

cmd_cd :: proc(args: []string, filename: string, append_file: bool) {
	if len(args) > 1 {
		fmt.print("cd: Too many arguments\n")
	} else {
		path := args[0]
		if strings.has_prefix(args[0], "~") {
			home := os.get_env_alloc("HOME", context.temp_allocator)
			index := strings.index(args[0], "~")
			if index != -1 {
				path = strings.concatenate({home, args[0][index + 1:]})
			}
		}

		// This is for odin-2026-03-nightly
		cd_err := os.change_directory(path)
		if cd_err != nil {
			fmt.printf("cd: %s: No such file or directory\n", path)
		}

		// // This is for odin-2025-07 (codecrafters version)
		// cd_err := os.set_current_directory(path)
		// if cd_err != nil {
		// 	fmt.printf("cd: %s: No such file or directory\n", path)
		// }
	}
}

cmd_history :: proc(args: []string, filename: string, append_file: bool) {
	starting_index := 0
	if len(args) > 0 {
		arg, ok := strconv.parse_int(args[0], 10)
		if ok {
			starting_index = len(commands_history) - arg
		}
	}
	for i in starting_index ..< len(commands_history) {
		num_str := fmt.tprintf("%d", i + 1)
		padding := 5 - len(num_str)
		for _ in 0 ..< padding {
			fmt.printf(" ")
		}
		if filename == "" {
			fmt.printf("%s  %s\n", num_str, commands_history[i])
		} else {
			line := fmt.tprintf("%s  %s\n", num_str, commands_history[i])
			redirect_output(line, filename, append_file)
		}
	}
}

cmd_exit :: proc(args: []string, filename: string, append_file: bool) {
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &original_termios)
	os.exit(0)
}
