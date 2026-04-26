package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:sys/posix"

execute_line :: proc(line: string) {
	semi_commands, split_err := split_commands(line)
	if split_err != nil {
		#partial switch e in split_err {
		case Shell_Error:
			#partial switch e {
			case .Parse_Error:
				return
			}
		}
		return
	}
	for semi_cmd in semi_commands {
		pipe_split_commands, pipe_split_err := pipe_split(semi_cmd)
		if pipe_split_err != nil {
			#partial switch e in pipe_split_err {
			case Shell_Error:
				#partial switch e {
				case .Parse_Error:
					continue
				}
			}
			return
		}

		if len(pipe_split_commands) > 1 {
			execute_pipeline(pipe_split_commands)
		} else {
			parse_result, err := parse_input(semi_cmd)
			if err != nil {
				switch e in err {
				case Shell_Error:
					#partial switch e {
					case .Empty_Input:
						continue
					case .Parse_Error:
						continue
					}
				case runtime.Allocator_Error:
					oom_fatal()
				case io.Error:
					oom_fatal()
				}
			}

			ok: bool
			if len(parse_result.stdin_redirect.filename) > 0 {
				parse_result.stdin_redirect.filename, ok = expand_tilde(
					parse_result.stdin_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stdin_redirect.filename,
					)
					last_exit_code = 1
					continue
				}
				parse_result.stdin_redirect.filename = expand_parameters(
					parse_result.stdin_redirect.filename,
				)
			}
			if len(parse_result.stdout_redirect.filename) > 0 {
				parse_result.stdout_redirect.filename, ok = expand_tilde(
					parse_result.stdout_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stdout_redirect.filename,
					)
					last_exit_code = 1
					continue
				}
				parse_result.stdout_redirect.filename = expand_parameters(
					parse_result.stdout_redirect.filename,
				)
			}
			if len(parse_result.stderr_redirect.filename) > 0 {
				parse_result.stderr_redirect.filename, ok = expand_tilde(
					parse_result.stderr_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stderr_redirect.filename,
					)
					last_exit_code = 1
					continue
				}
				parse_result.stderr_redirect.filename = expand_parameters(
					parse_result.stderr_redirect.filename,
				)
			}

			new_args := make([dynamic]string, context.temp_allocator)
			tilde_ok := true
			for arg, i in parse_result.args {
				parse_result.args[i], ok = expand_tilde(arg)
				if !ok {
					username, username_err := strings.split(
						parse_result.args[i][1:],
						"/",
						context.temp_allocator,
					)
					if username_err != nil {oom_fatal()}

					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						username[0],
					)
					last_exit_code = 1
					tilde_ok = false
					break
				}

				parse_result.args[i] = expand_parameters(parse_result.args[i])

				expanded := expand_braces(parse_result.args[i])
				for e in expanded {
					append(&new_args, e)
				}
			}
			if !tilde_ok {continue}

			parse_result.args = new_args[:]

			if handler, ok := handlers[parse_result.command]; ok {
				last_exit_code = handler(parse_result.args, parse_result.stdout_redirect)
				if len(parse_result.stderr_redirect.filename) > 0 {
					redirect_output("", parse_result.stderr_redirect)
				}
			} else {
				full_path, found, err := resolve_command(parse_result.command)
				if err != nil {
					#partial switch e in err {
					case Shell_Error:
						#partial switch e {
						case .Empty_Input:
							continue
						}
					case runtime.Allocator_Error:
						oom_fatal()
					}
				}

				if found {

					pid := posix.fork()
					switch pid {
					case -1:
						fmt.eprintf(
							"%s: fork failed: resource temporarily unavailable\n",
							SHELL_NAME,
						)
						last_exit_code = 1
						continue
					case 0:
						err = exec_external(full_path, parse_result)
						if err != nil {oom_fatal()}
					case:
						status: c.int
						posix.waitpid(posix.pid_t(pid), &status, {})
						if posix.WIFEXITED(status) {
							last_exit_code = i32(posix.WEXITSTATUS(status))
						} else if posix.WIFSIGNALED(status) {
							last_exit_code = 128 + i32(posix.WTERMSIG(status))
						}
					}

				} else {
					fmt.eprintf("%s: command not found: %s\n", SHELL_NAME, parse_result.command)
					last_exit_code = 127
				}
			}
		}
	}
}

redirect_output :: proc(output: string, redirect: Redirect) {
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.eprintf("%s: could not read current working directory %w\n", SHELL_NAME, pwd_err)
	}

	full := redirect.filename
	if redirect.filename[0] != '/' {
		concat_err: runtime.Allocator_Error
		full, concat_err = strings.concatenate(
			{pwd, "/", redirect.filename},
			context.temp_allocator,
		)
		if concat_err != nil {oom_fatal()}
	}

	file := &os.File{}
	file_err := os.Error{}
	if redirect.append_mode {
		file, file_err = os.open(
			redirect.filename,
			os.O_WRONLY | os.O_CREATE | os.O_APPEND,
			{.Read_User, .Write_User, .Read_Group, .Read_Other},
		)
	} else {
		file, file_err = os.open(
			redirect.filename,
			os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
			{.Read_User, .Write_User, .Read_Group, .Read_Other},
		)
	}
	if file_err != nil {
		fmt.eprintf("%s: could not create or truncate file %s\n", SHELL_NAME, redirect.filename)
		return
	}
	defer os.close(file)
	_, write_err := os.write_string(file, output)
	if write_err != nil {
		fmt.eprintf("%s: could not write to file %s\n", SHELL_NAME, redirect.filename)
		return
	}
}


execute_pipeline :: proc(commands: []string) {
	prev_read_fd := -1
	pids := make([dynamic]posix.pid_t, context.temp_allocator)

	for i in 0 ..< len(commands) {
		fildes: [2]posix.FD
		if i < len(commands) - 1 {
			if posix.pipe(&fildes) != .OK {
				fmt.eprintf("%s: pipe failed: too many open files\n", SHELL_NAME)
			}
		}


		pid := posix.fork()
		switch pid {
		case -1:
			fmt.eprintf("%s: fork failed: resource temporarily unavailable\n", SHELL_NAME)
			last_exit_code = 1
			continue
		case 0:
			if prev_read_fd != -1 {
				// write end already closed in parent

				// redirect output form stdin to fildes[0] (read end)
				posix.dup2(posix.FD(c.int(prev_read_fd)), 0)

				// close read end
				posix.close(posix.FD(c.int(prev_read_fd)))
			}


			if i < len(commands) - 1 {
				// close read end
				posix.close(fildes[0])

				// redirect output form stdout to fildes[1] (write end)
				posix.dup2(fildes[1], 1)

				// close write end
				posix.close(fildes[1])
			}

			parse_result, err := parse_input(commands[i])
			if err != nil {
				switch e in err {
				case Shell_Error:
					#partial switch e {
					case .Empty_Input:
						last_exit_code = 1
						posix.exit(last_exit_code)
					case .Parse_Error:
						last_exit_code = 1
						posix.exit(last_exit_code)
					}
				case runtime.Allocator_Error:
					oom_fatal()
				case io.Error:
					oom_fatal()
				}
			}


			ok: bool
			if len(parse_result.stdin_redirect.filename) > 0 {
				parse_result.stdin_redirect.filename, ok = expand_tilde(
					parse_result.stdin_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stdin_redirect.filename,
					)
					last_exit_code = 1
					posix.exit(last_exit_code)
				}
				parse_result.stdin_redirect.filename = expand_parameters(
					parse_result.stdin_redirect.filename,
				)
			}
			if len(parse_result.stdout_redirect.filename) > 0 {
				parse_result.stdout_redirect.filename, ok = expand_tilde(
					parse_result.stdout_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stdout_redirect.filename,
					)
					last_exit_code = 1
					posix.exit(last_exit_code)
				}
				parse_result.stdout_redirect.filename = expand_parameters(
					parse_result.stdout_redirect.filename,
				)
			}
			if len(parse_result.stderr_redirect.filename) > 0 {
				parse_result.stderr_redirect.filename, ok = expand_tilde(
					parse_result.stderr_redirect.filename,
				)
				if !ok {
					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						parse_result.stderr_redirect.filename,
					)
					last_exit_code = 1
					posix.exit(last_exit_code)
				}
				parse_result.stderr_redirect.filename = expand_parameters(
					parse_result.stderr_redirect.filename,
				)
			}

			new_args := make([dynamic]string, context.temp_allocator)
			tilde_ok := true
			for arg, i in parse_result.args {
				parse_result.args[i], ok = expand_tilde(arg)
				if !ok {
					username, username_err := strings.split(
						parse_result.args[i][1:],
						"/",
						context.temp_allocator,
					)
					if username_err != nil {oom_fatal()}

					fmt.eprintf(
						"%s: no such user or named directory: %s\n",
						SHELL_NAME,
						username[0],
					)
					last_exit_code = 1
					tilde_ok = false
					break
				}

				parse_result.args[i] = expand_parameters(parse_result.args[i])

				expanded := expand_braces(parse_result.args[i])
				for e in expanded {
					append(&new_args, e)
				}
			}
			if !tilde_ok {posix.exit(last_exit_code)}

			parse_result.args = new_args[:]

			if handler, ok := handlers[parse_result.command]; ok {
				last_exit_code = handler(parse_result.args, parse_result.stdout_redirect)
				if len(parse_result.stderr_redirect.filename) > 0 {
					redirect_output("", parse_result.stderr_redirect)
				}

				posix.exit(last_exit_code)

			} else {
				full_path, found, err := resolve_command(parse_result.command)
				if err != nil {
					#partial switch e in err {
					case Shell_Error:
						#partial switch e {
						case .Empty_Input:
							last_exit_code = 1
							posix.exit(last_exit_code)
						}
					case runtime.Allocator_Error:
						oom_fatal()
					}
				}

				if found {
					err = exec_external(full_path, parse_result)
					if err != nil {
						oom_fatal()
					}
				} else {
					fmt.eprintf("%s: command not found: %s\n", SHELL_NAME, parse_result.command)
					last_exit_code = 127
				}
			}

		case:
			if prev_read_fd != -1 {
				posix.close(posix.FD(c.int(prev_read_fd)))
			}

			if i < len(commands) - 1 {
				posix.close(fildes[1])
				prev_read_fd = int(fildes[0])
			}

			append(&pids, pid)
		}
	}

	for i in 0 ..< len(pids) {
		status: c.int
		posix.waitpid(pids[i], &status, {})

		// process only last command status code
		if i == len(pids) - 1 {
			if posix.WIFEXITED(status) {
				last_exit_code = i32(posix.WEXITSTATUS(status))
			} else if posix.WIFSIGNALED(status) {
				last_exit_code = 128 + i32(posix.WTERMSIG(status))
			}
		}
	}
}

redirect_fd :: proc(fildes: posix.FD, redirect: Redirect) {
	flags := posix.O_Flags{.WRONLY, .CREAT}
	flags += {.APPEND} if redirect.append_mode else {.TRUNC}

	filename, err := strings.clone_to_cstring(redirect.filename, context.temp_allocator)
	if err != nil {oom_fatal()}

	fd := posix.open(filename, flags, {.IRUSR, .IWUSR, .IRGRP, .IROTH})
	if fd == posix.FD(c.int(-1)) {
		fmt.eprintf("%s: no such file or directory: %s\n", SHELL_NAME, redirect.filename)
		last_exit_code = 1
		posix.exit(last_exit_code)
	}
	posix.dup2(fd, fildes)
	posix.close(fd)
}


// Check if command is found and executable
resolve_command :: proc(command: string) -> (full_path: string, found: bool, err: Error) {
	if len(command) == 0 {
		return "", false, .Empty_Input
	}

	path := os.get_env_alloc("PATH", context.temp_allocator)
	dirs, split_err := strings.split(path, ":")
	if split_err != nil {oom_fatal()}

	found = false

	for dir in dirs {
		full := strings.concatenate({dir, "/", command}, context.temp_allocator)
		if os.exists(full) {
			stat, stat_err := os.stat(full, context.temp_allocator)
			if stat_err != nil {
				// just continue. zsh doesn't show error for broken path
				continue
			}

			if os.Permission_Flag.Execute_User in stat.mode {
				return full, true, {}
			} else {
				continue
			}
		}
	}
	return
}


exec_external :: proc(full_path: string, parse_result: Parse_Result) -> (err: Error) {
	alloc_err: runtime.Allocator_Error
	c_command: cstring
	c_s: cstring

	cmd := make([dynamic]string, context.temp_allocator)
	append(&cmd, full_path)
	for arg in parse_result.args {
		append(&cmd, arg)
	}

	if len(parse_result.stdout_redirect.filename) > 0 {
		redirect_fd(posix.FD(c.int(1)), parse_result.stdout_redirect)
	}
	if len(parse_result.stderr_redirect.filename) > 0 {
		redirect_fd(posix.FD(c.int(2)), parse_result.stderr_redirect)
	}
	if len(parse_result.stdin_redirect.filename) > 0 {
		fd := posix.open(
			strings.clone_to_cstring(parse_result.stdin_redirect.filename, context.temp_allocator),
			posix.O_Flags{},
			{},
		)
		if fd == -1 {
			fmt.eprintf(
				"%s: no such file or directory: %s\n",
				SHELL_NAME,
				parse_result.stdin_redirect.filename,
			)
			posix.exit(1)
		}
		posix.dup2(fd, 0)
		posix.close(fd)
	}

	c_command, alloc_err = strings.clone_to_cstring(parse_result.command, context.temp_allocator)
	if alloc_err != nil {oom_fatal()}

	c_cmd := make([dynamic]cstring, context.temp_allocator)
	for s in cmd {
		c_s, clone_err := strings.clone_to_cstring(s, context.temp_allocator)
		if clone_err != nil {oom_fatal()}

		append(&c_cmd, c_s)
	}
	append(&c_cmd, nil)

	_ = posix.execvp(c_command, raw_data(c_cmd[:]))
	os.exit(1)
}
