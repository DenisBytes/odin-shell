package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

original_termios: posix.termios

main :: proc() {
	// FD(0) == stdin
	posix.tcgetattr(posix.FD(c.int(0)), &original_termios)

	raw := original_termios
	raw.c_lflag -= {.ICANON, .ECHO}
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &raw)

	input_str := ""

	for {
		fmt.printf("$ ")
		input_buf: [dynamic]byte
		defer delete(input_buf)

		tab_count: uint = 0
		inner: for {
			char_buf: [1]byte
			n, read_err := os.read(os.stdin, char_buf[:])
			if read_err != nil || n == 0 {
				break
			}

			ch := char_buf[0]

			switch ch {
			case '\n':
				fmt.printf("\n")
				input_str = string(input_buf[:])
				break inner
			case '\t':
				tab_count += 1
				try_autocomplete(&input_buf, tab_count)
				continue
			case 127:
				tab_count = 0
				if len(input_buf) > 0 {
					pop(&input_buf)
					fmt.printf("\b \b")
				}
				continue
			case:
				tab_count = 0
				append(&input_buf, ch)
				fmt.printf("%c", ch)
			}
		}


		command, args, stdout_filename, stderr_filename, append_file, input_err := parse_input(
			input_str,
		)
		if input_err != nil {
			fmt.printf("shell: error in parsing error: %w\n", input_err)
		}

		if handler, ok := handlers[command]; ok {

			handler(args, stdout_filename, append_file)
			if len(stderr_filename) > 0 {
				redirect_output("", stderr_filename, append_file)
			}

		} else {

			path := os.get_env_alloc("PATH", context.temp_allocator)
			dirs, split_dir_err := strings.split(path, ":")
			if split_dir_err != nil {
				fmt.printf("shell: error splitting PATH: %w\n", split_dir_err)
			}

			found := false
			outer: for dir in dirs {
				full := strings.concatenate({dir, "/", command})
				if os.exists(full) {
					found = true
					stat, stat_err := os.stat(full, context.temp_allocator)
					if stat_err != nil {
						fmt.printf("shell: error reading file stat: %w\n", stat_err)
					}

					// This is for odin-2026-03-nightly
					if os.Permission_Flag.Execute_User in stat.mode {
						// // This is for odin-2025-07 (codecrafters version)
						// if stat.mode & 0o100 != 0 {

						// This is for odin-2026-03-nightly
						cmd := make([dynamic]string, context.temp_allocator)
						append(&cmd, full)
						for arg in args {
							append(&cmd, arg)
						}

						// // This is for odin-2025-07 (codecrafters version)
						// cmd := make([dynamic]string, context.temp_allocator)
						// for arg in args {
						// 	append(&cmd, arg)
						// }

						// This is for odin-2026-03-nightly
						state, stdout, stderr, exec_err := os.process_exec(
							os.Process_Desc{command = cmd[:]},
							context.temp_allocator,
						)
						if exec_err != nil {
							fmt.printf("shell: error executing process: %w\n", exec_err)
							return
						}
						if len(stdout_filename) > 0 {
							redirect_output(string(stdout), stdout_filename, append_file)
						} else if len(stdout) > 0 {
							fmt.printf("%s\n", string(stdout))
						}
						if len(stderr_filename) > 0 {
							redirect_output(string(stderr), stderr_filename, append_file)
						} else if len(stderr) > 0 {
							fmt.printf("%s\n", string(stderr))
						}

						// // This is for odin-2025-07 (codecrafters version)
						// pid, _ := os.fork()
						// if pid == 0 {
						// 	if len(stdout_filename) > 0 {
						// 		flags := posix.O_Flags{.WRONLY, .CREAT}
						// 		flags += {.APPEND} if append_file else {.TRUNC}
						// 		fd := posix.open(
						// 			strings.clone_to_cstring(stdout_filename),
						// 			flags,
						// 			{.IRUSR, .IWUSR, .IRGRP, .IROTH},
						// 		)
						// 		posix.dup2(fd, 1)
						// 		posix.close(fd)
						// 	}
						// 	if len(stderr_filename) > 0 {
						// 		flags := posix.O_Flags{.WRONLY, .CREAT}
						// 		flags += {.APPEND} if append_file else {.TRUNC}
						// 		fd := posix.open(
						// 			strings.clone_to_cstring(stderr_filename),
						// 			flags,
						// 			{.IRUSR, .IWUSR, .IRGRP, .IROTH},
						// 		)
						// 		posix.dup2(fd, 2)
						// 		posix.close(fd)
						// 	}
						// 	os.execvp(command, cmd[:])
						// 	os.exit(1)
						// } else {
						// 	status: i32
						// 	posix.waitpid(posix.pid_t(pid), &status, {})
						// }


						break outer
					}
				}
			}
			if !found {fmt.printf("%s: command not found\n", command)}
		}
	}
}
