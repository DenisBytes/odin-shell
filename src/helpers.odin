package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

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
