package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:sys/posix"

redirect_output :: proc(output: string, filename: string, append_file: bool) {
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.printf("shell: could not read current working directory %w\n", pwd_err)
	}

	full := filename
	if filename[0] != '/' {
		full = strings.concatenate({pwd, "/", filename}, context.temp_allocator)
	}

	file := &os.File{}
	file_err := os.Error{}
	if append_file {
		file, file_err = os.open(
			filename,
			os.O_WRONLY | os.O_CREATE | os.O_APPEND,
			{.Read_User, .Write_User, .Read_Group, .Read_Other},
		)
	} else {
		file, file_err = os.open(
			filename,
			os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
			{.Read_User, .Write_User, .Read_Group, .Read_Other},
		)
	}
	if file_err != nil {
		fmt.printf("shell: could not create or truncate file %s\n", filename)
		return
	}
	defer os.close(file)
	_, write_err := os.write_string(file, output)
	if write_err != nil {
		fmt.printf("shell: could not write to file %s\n", filename)
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
				fmt.printf("shell: error in creating pipe.\n")
			}
		}


		pid := posix.fork()
		switch pid {
		case -1:
			fmt.printf("shell: error in creating fork.\n")

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
					case Shell_Error.Empty_Input:
						continue
					case:
						fmt.printf("shell: error: %v", err)
					}
				case runtime.Allocator_Error:
					fmt.printf("shell: alloc error: %v", err)
				case io.Error:
					fmt.printf("shell: io error: %v", err)
				}
			}

			if handler, ok := handlers[parse_result.command]; ok {
				handler(
					parse_result.args,
					parse_result.stdout_redirect.filename,
					parse_result.stdout_redirect.append_mode,
				)
				if len(parse_result.stderr_redirect.filename) > 0 {
					redirect_output(
						"",
						parse_result.stderr_redirect.filename,
						parse_result.stderr_redirect.append_mode,
					)
				}

				posix.exit(0)

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
						fmt.printf("shell: alloc error: %v", err)
					}
				}

				if found {
					err = exec_external(full_path, parse_result)
					if err != nil {
						fmt.printf("shell: alloc err: %v", err)
						return
					}
				} else {
					fmt.printf("%s: command not found\n", parse_result.command)
				}
			}

		case:
			if prev_read_fd != -1 {
				// close write end
				posix.close(posix.FD(c.int(prev_read_fd)))
			}

			if i < len(commands) - 1 {
				// close write end
				posix.close(fildes[1])
				prev_read_fd = int(fildes[0])
			}

			append(&pids, pid)
		}
	}

	for pid in pids {
		status: i32
		posix.waitpid(posix.pid_t(pid), &status, {})
	}
}

redirect_fd :: proc(fildes: posix.FD, redirect: Redirect) {
	flags := posix.O_Flags{.WRONLY, .CREAT}
	flags += {.APPEND} if redirect.append_mode else {.TRUNC}
	fd := posix.open(
		strings.clone_to_cstring(redirect.filename, context.temp_allocator),
		flags,
		{.IRUSR, .IWUSR, .IRGRP, .IROTH},
	)

	posix.dup2(fd, fildes)
	posix.close(fd)
}


resolve_command :: proc(command: string) -> (full_path: string, found: bool, err: Error) {
	if len(command) == 0 {
		return "", false, .Empty_Input
	}

	path := os.get_env_alloc("PATH", context.temp_allocator)
	dirs, split_err := strings.split(path, ":")
	if split_err != nil {
		return "", false, split_err
	}

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

	c_command, alloc_err = strings.clone_to_cstring(parse_result.command, context.temp_allocator)
	if alloc_err != nil {
		return alloc_err
	}
	c_cmd := make([dynamic]cstring, context.temp_allocator)
	for s in cmd {
		c_s, err = strings.clone_to_cstring(s, context.temp_allocator)
		if err != nil {
			fmt.printf("shell: error executing command: %w\n", err)
		}
		append(&c_cmd, c_s)
	}
	append(&c_cmd, nil)

	_ = posix.execvp(c_command, raw_data(c_cmd[:]))
	os.exit(1)
}
