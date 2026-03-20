package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

/*
 * THINGS I HAVE LEARNED
 * 
 *  A shell is just a parser of commands + creator of processes + extra features like builtin commands, autocomplete, quoting, redirect (1>, 1>>, 2>, 2>>) and pipelines
 *  
 *  If you go to /dev/pts/ you can see all the TTY (in history they were physical teletypewriter, but nowadays are pty = pseudo terminal) 
 *  
 *  A termios is the configuration of the TTY/PTY. You can look at current config with: stty -a
 *    Some output lines:
 *      intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>;
 *      isig icanon iexten echo echoe echok -echonl -noflsh -xcase -tostop -echoprt
 *    A shell needs to overwrite the termios config and make it raw (not canonical basically) to handle, for example, the input chat by char,
 *      instead of the whole line + \n signal (ENTER). But at the end it most restore the original termios config
 *      You do that with posix.tcgetattr (get current termios) and tcsetattr to set differnt flags in the config  
 *
 *  You can fork processes: it does a copy of the state of the current process (More exactly a COW, Copy on Write)
 *  
 *  You can redirect output to other FD (such as a pipe write end (then the content can be read from the pipe read end)) and redirect stdout and stderr to files
 *    you do this with posix.dup2(pipe_write_end, stdout) a.k.a. make stdout FD (1) point to where pipe_write_end fd is pointing to
 *  You can create a pipe to handle communication between processes's stdin and stdout (not stderr apperently) 
 *    For the next process to read form the pipe read end, the write end must be closed (it needs the EOF signal) 
 *    you must do a waitpid() at the end for every child process spawned, otherwise the parent won't block and the child process wont be cleaned up
 *      in the process table. waitpid() will handle the removal of the child processes from the process table
 *        fork() -> child exits
 *          child: execvp() -> becomes "cat ..." or "head ..."
 *          "cat" finishes -> child exists -> becomes zombie
 *        parent: waitpid() -> read exit code (&status) -> zombie removed
 *  
 *  execvp replaces the current odin process memory with a new program (the command you are passing). On success it never returns.
 *  the l, v, p, e in the exec*  functions (execvp, execv, execle, etc...) they are just like options/flags/suffix-system:
 *    - l: args as a list. execl("/bin/ls", "ls", "-la", NULL)
 *    - v: args as an array. execv("/bin/ls", args)
 *    - p: search PATH for the command. execlp("ls", "ls", "-la", NULL)
 *    - e: pass custom ENVs. execve("/bin/ls", args, custom_env)
 *
 *  * */

original_termios: posix.termios

main :: proc() {
	// FD(0) == stdin
	posix.tcgetattr(posix.FD(c.int(0)), &original_termios)

	raw := original_termios
	raw.c_lflag -= {.ICANON, .ECHO}
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &raw)

	input_str := ""
	history_index := len(commands_history)

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
			// ENTER
			case '\n':
				fmt.printf("\n")
				input_str = string(input_buf[:])
				break inner
			// TAB
			case '\t':
				tab_count += 1
				try_autocomplete(&input_buf, tab_count)
				continue
			// DELETE
			case 127:
				tab_count = 0
				if len(input_buf) > 0 {
					pop(&input_buf)
					fmt.printf("\b \b")
				}
				continue
			// ARROW_UP
			case '\x1b':
				seq: [2]byte
				os.read(os.stdin, seq[:])
				if seq[0] == '[' && seq[1] == 'A' {
					if history_index > 0 {
						history_index -= 1
						fmt.printf("\r$ ")
						for _ in 0 ..< len(input_buf) {
							fmt.printf(" ")
						}
						fmt.printf("\r$ ")
						history_bytes := transmute([]byte)commands_history[history_index]
						clear(&input_buf)
						append(&input_buf, ..history_bytes)
						fmt.printf("%s", string(input_buf[:]))
					}
				} else if seq[0] == '[' && seq[1] == 'B' {
					if history_index < len(commands_history) - 1 {
						history_index += 1
						fmt.printf("\r$ ")
						for _ in 0 ..< len(input_buf) {
							fmt.printf(" ")
						}
						fmt.printf("\r$ ")
						history_bytes := transmute([]byte)commands_history[history_index]
						clear(&input_buf)
						append(&input_buf, ..history_bytes)
						fmt.printf("%s", string(input_buf[:]))
					}
				}
				continue
			case:
				tab_count = 0
				append(&input_buf, ch)
				fmt.printf("%c", ch)
			}
		}

		input_clone, _ := strings.clone(input_str)
		append(&commands_history, input_clone)
		history_index = len(commands_history)

		pipe_split_commands, pipe_split_err := pipe_split(input_str)
		if pipe_split_err != nil {
			fmt.printf("shell: error in parsing. error: %w\n", pipe_split_err)
		}

		if len(pipe_split_commands) > 1 {
			execute_pipeline(pipe_split_commands)
		} else {
			command, args, stdout_filename, stderr_filename, append_file, input_err := parse_input(
				input_str,
			)
			if input_err != nil {
				fmt.printf("shell: error in parsing. error: %w\n", input_err)
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
							pid := posix.fork()
							switch pid {
							case -1:
								fmt.printf("shell: error in creating fork.\n")
							case 0:
								if len(stdout_filename) > 0 {
									flags := posix.O_Flags{.WRONLY, .CREAT}
									flags += {.APPEND} if append_file else {.TRUNC}
									fd := posix.open(
										strings.clone_to_cstring(stdout_filename),
										flags,
										{.IRUSR, .IWUSR, .IRGRP, .IROTH},
									)
									posix.dup2(fd, 1)
									posix.close(fd)
								}
								if len(stderr_filename) > 0 {
									flags := posix.O_Flags{.WRONLY, .CREAT}
									flags += {.APPEND} if append_file else {.TRUNC}
									fd := posix.open(
										strings.clone_to_cstring(stderr_filename),
										flags,
										{.IRUSR, .IWUSR, .IRGRP, .IROTH},
									)
									posix.dup2(fd, 2)
									posix.close(fd)
								}
								c_command, c_command_err := strings.clone_to_cstring(
									command,
									context.temp_allocator,
								)
								if c_command_err != nil {
									fmt.printf(
										"shell: error executing command: %w\n",
										c_command_err,
									)
								}
								c_cmd := make([dynamic]cstring, context.temp_allocator)
								for s in cmd {
									c_s, c_s_err := strings.clone_to_cstring(
										s,
										context.temp_allocator,
									)
									if c_s_err != nil {
										fmt.printf("shell: error executing command: %w\n", c_s_err)
									}
									append(&c_cmd, c_s)
								}
								append(&c_cmd, nil)
								posix.execvp(c_command, raw_data(c_cmd[:]))
								os.exit(1)
							case:
								status: i32
								posix.waitpid(posix.pid_t(pid), &status, {})
							}

							// // This is for odin-2025-07 (codecrafters version)
							// pid, _ := os.fork()
							// switch pid {
							// case 0:
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
							// case:
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
}
