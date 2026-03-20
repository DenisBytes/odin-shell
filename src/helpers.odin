package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/posix"

redirect_output :: proc(output: string, filename: string, append_file: bool) {
	// This is for odin-2026-03-nightly
	pwd, pwd_err := os.get_working_directory(context.temp_allocator)
	if pwd_err != nil {
		fmt.printf("shell: could not read current working directory %w\n", pwd_err)
	}

	// // This is for odin-2025-07 (codecrafters version)
	// pwd := os.get_current_directory(context.temp_allocator)


	full := filename
	if filename[0] != '/' {
		full = strings.concatenate({pwd, "/", filename})
	}

	// This is for odin-2026-03-nightly
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
	_, write_err := os.write_string(file, output)
	if write_err != nil {
		fmt.printf("shell: could not write to file %s\n", filename)
		return
	}

	// // This is for odin-2025-07 (codecrafters version)
	// file := os.Handle{}
	// file_err := os.Errno{}
	// if append_file {
	// 	file, file_err = os.open(filename, os.O_WRONLY | os.O_CREATE | os.O_APPEND, 0o644)
	// } else {
	// 	file, file_err = os.open(filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	// }
	// os.write_string(file, output)
	// os.close(file)
}


try_autocomplete :: proc(input_buf: ^[dynamic]byte, tab_count: uint) {
	prefix := string(input_buf^[:])
	if strings.contains(prefix, " ") {
		prefix_filename_index := strings.last_index_byte(prefix, ' ')
		if prefix_filename_index < 0 {
			return
		}

		partial := prefix[prefix_filename_index + 1:]

		last_slash_index := strings.last_index_byte(partial, '/')

		if last_slash_index >= 0 {
			dir_path := partial[:last_slash_index + 1]
			file_prefix := partial[last_slash_index + 1:]

			pwd, open_err := os.open(dir_path)
			if open_err != nil {
				return
			}

			entries, dir_err := os.read_dir(pwd, -1, context.temp_allocator)
			os.close(pwd)
			if dir_err != nil {
				return
			}

			file_matches := [dynamic]string{}
			display_matches := [dynamic]string{}
			for entry in entries {
				if strings.has_prefix(entry.name, file_prefix) {
					// This is for odin-2026-03-nightly
					if entry.type == .Directory {
						// // This is for odin-2025-07 (codecrafters version)
						// if entry.is_dir {
						append(&file_matches, entry.name)
						append(&display_matches, fmt.tprintf("%s/", entry.name))
					} else {
						append(&file_matches, entry.name)
						append(&display_matches, entry.name)
					}
				}
			}

			if len(file_matches) == 0 {
				fmt.printf("\x07")
				return
			}

			if len(file_matches) == 1 {
				clear(input_buf)
				append(input_buf, ..transmute([]byte)prefix[:prefix_filename_index + 1])
				append(input_buf, ..transmute([]byte)partial[:last_slash_index + 1])
				append(input_buf, ..transmute([]byte)display_matches[0])

				if !strings.has_suffix(display_matches[0], "/") {
					append(input_buf, ' ')
				}

				fmt.printf("\r$ %s", string(input_buf^[:]))
				return
			}

			lcp := file_matches[0]
			for m in file_matches[1:] {
				for len(lcp) > 0 && !strings.has_prefix(m, lcp) {
					lcp = lcp[:len(lcp) - 1]
				}
			}

			if len(lcp) > len(partial[last_slash_index + 1:]) {
				clear(input_buf)
				append(input_buf, ..transmute([]byte)prefix[:prefix_filename_index + 1])
				append(input_buf, ..transmute([]byte)partial[:last_slash_index + 1])
				append(input_buf, ..transmute([]byte)lcp)
				fmt.printf("\r$ %s", string(input_buf^[:]))
			}

			if len(lcp) == len(partial[last_slash_index + 1:]) {
				if tab_count == 1 {
					fmt.printf("\x07")
				}

				if tab_count >= 2 {
					slice.sort(display_matches[:])
					fmt.printf("\n%s\n$ %s", strings.join(display_matches[:], "  "), prefix)
					fmt.printf("\r$ %s", string(input_buf^[:]))
				}
			}

		} else {
			pwd, open_err := os.open(".")
			if open_err != nil {
				return
			}
			entries, dir_err := os.read_dir(pwd, -1, context.temp_allocator)
			os.close(pwd)
			if dir_err != nil {
				return
			}

			file_matches := [dynamic]string{}
			display_matches := [dynamic]string{}
			for entry in entries {
				if strings.has_prefix(entry.name, prefix[prefix_filename_index + 1:]) {
					// This is for odin-2026-03-nightly
					if entry.type == .Directory {
						// // This is for odin-2025-07 (codecrafters version)
						// if entry.is_dir {
						append(&file_matches, entry.name)
						append(&display_matches, fmt.tprintf("%s/", entry.name))
					} else {
						append(&file_matches, entry.name)
						append(&display_matches, entry.name)
					}
				}
			}

			if len(file_matches) == 0 {
				fmt.printf("\x07")
				return
			}

			if len(file_matches) == 1 {
				clear(input_buf)
				append(input_buf, ..transmute([]byte)prefix[:prefix_filename_index + 1])
				append(input_buf, ..transmute([]byte)display_matches[0])

				if !strings.has_suffix(display_matches[0], "/") {
					append(input_buf, ' ')
				}

				fmt.printf("\r$ %s", string(input_buf^[:]))
				return
			}

			lcp := file_matches[0]
			for m in file_matches[1:] {
				for len(lcp) > 0 && !strings.has_prefix(m, lcp) {
					lcp = lcp[:len(lcp) - 1]
				}
			}

			if len(lcp) > len(prefix[prefix_filename_index + 1:]) {
				clear(input_buf)
				append(input_buf, ..transmute([]byte)prefix[:prefix_filename_index + 1])
				append(input_buf, ..transmute([]byte)lcp)
				fmt.printf("\r$ %s", string(input_buf^[:]))
			}

			if len(lcp) == len(prefix[prefix_filename_index + 1:]) {
				if tab_count == 1 {
					fmt.printf("\x07")
				}

				if tab_count >= 2 {
					slice.sort(display_matches[:])
					fmt.printf("\n%s\n$ %s", strings.join(display_matches[:], "  "), prefix)
					fmt.printf("\r$ %s", string(input_buf^[:]))
				}
			}
		}

	} else {
		matches := [dynamic]string{}
		for c in BUILTIN_COMMANDS {
			if strings.has_prefix(c, prefix) {
				append(&matches, c)
			}
		}

		path := os.get_env_alloc("PATH", context.temp_allocator)
		dirs, split_dir_err := strings.split(path, ":")
		if split_dir_err != nil {
			fmt.printf("shell: error splitting PATH: %w\n", split_dir_err)
		}

		for dir in dirs {
			f, open_err := os.open(dir)
			if open_err != nil {
				continue
			}
			entries, dir_err := os.read_dir(f, -1, context.temp_allocator)
			os.close(f)
			if dir_err != nil {
				continue
			}
			for entry in entries {
				if strings.has_prefix(entry.name, prefix) &&
				   !slice.contains(matches[:], entry.name) {
					append(&matches, entry.name)
				}
			}
		}

		if len(matches) == 0 {
			fmt.printf("\x07")
			return
		}


		if len(matches) == 1 {
			clear(input_buf)
			append(input_buf, ..transmute([]byte)matches[0])
			append(input_buf, ' ')
			fmt.printf("\r$ %s", string(input_buf^[:]))
			return
		}

		// Longest Common Prefix
		lcp := matches[0]
		for m in matches[1:] {
			for len(lcp) > 0 && !strings.has_prefix(m, lcp) {
				lcp = lcp[:len(lcp) - 1]
			}
		}

		if len(lcp) > len(prefix) {
			clear(input_buf)
			append(input_buf, ..transmute([]byte)lcp)
			fmt.printf("\r$ %s", string(input_buf^[:]))
		}

		if len(lcp) == len(prefix) {
			if tab_count == 1 {
				fmt.printf("\x07")
			}

			if tab_count >= 2 {
				slice.sort(matches[:])
				fmt.printf("\n%s\n$ %s", strings.join(matches[:], "  "), prefix)
				fmt.printf("\r$ %s", string(input_buf^[:]))
			}
		}
	}
}

pipe_split :: proc(input: string) -> ([]string, runtime.Allocator_Error) {
	in_single_quote := false
	in_double_quote := false
	is_backslash := false
	commands := [dynamic]string{}
	new_command_index := 0

	for c, index in input {
		if in_single_quote {
			if c == '\'' {
				in_single_quote = false
				continue
			}
		} else if in_double_quote {
			if c == '"' {
				in_double_quote = false
				continue
			}
		} else {
			if is_backslash {
				is_backslash = false
				continue
			}
			if c == '\\' {
				is_backslash = true
				continue
			}
			if c == '"' {
				in_double_quote = true
				continue
			}
			if c == '\'' {
				in_single_quote = true
				continue
			}

			if c == '|' {
				append(&commands, strings.trim_space(input[new_command_index:index]))
				new_command_index = index + 1
				continue
			}
		}
	}

	append(&commands, strings.trim_space(input[new_command_index:]))

	return commands[:], nil
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

			command, args, stdout_filename, stderr_filename, append_file, input_err := parse_input(
				commands[i],
			)
			if input_err != nil {
				fmt.printf("shell: error in parsing. error: %w\n", input_err)
			}

			if handler, ok := handlers[command]; ok {

				handler(args, stdout_filename, append_file)
				if len(stderr_filename) > 0 {
					redirect_output("", stderr_filename, append_file)
				}

				posix.exit(0)

			} else {

				path := os.get_env_alloc("PATH", context.temp_allocator)
				dirs, split_dir_err := strings.split(path, ":")
				if split_dir_err != nil {
					fmt.printf("shell: error splitting PATH: %w\n", split_dir_err)
				}

				found := false
				for dir in dirs {
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

							cmd := make([dynamic]string, context.temp_allocator)
							append(&cmd, full)
							for arg in args {
								append(&cmd, arg)
							}


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
								fmt.printf("shell: error executing command: %w\n", c_command_err)
							}

							c_cmd := make([dynamic]cstring, context.temp_allocator)
							for s in cmd {
								c_s, c_s_err := strings.clone_to_cstring(s, context.temp_allocator)
								if c_s_err != nil {
									fmt.printf("shell: error executing command: %w\n", c_s_err)
								}
								append(&c_cmd, c_s)
							}
							append(&c_cmd, nil)

							posix.execvp(c_command, raw_data(c_cmd[:]))

						}
					}
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
