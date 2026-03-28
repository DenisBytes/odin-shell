package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"


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
					if entry.type == .Directory {
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

				fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
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
				fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
			}

			if len(lcp) == len(partial[last_slash_index + 1:]) {
				if tab_count == 1 {
					fmt.printf("\x07")
				}

				if tab_count >= 2 {
					slice.sort(display_matches[:])
					fmt.printf(
						"\n%s\n%s%s",
						strings.join(display_matches[:], "  "),
						PROMPT,
						prefix,
					)
					fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
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
					if entry.type == .Directory {
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

				fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
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
				fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
			}

			if len(lcp) == len(prefix[prefix_filename_index + 1:]) {
				if tab_count == 1 {
					fmt.printf("\x07")
				}

				if tab_count >= 2 {
					slice.sort(display_matches[:])
					fmt.printf(
						"\n%s\n%s%s",
						PROMPT,
						strings.join(display_matches[:], "  "),
						prefix,
					)
					fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
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
			fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
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
			fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
		}

		if len(lcp) == len(prefix) {
			if tab_count == 1 {
				fmt.printf("\x07")
			}

			if tab_count >= 2 {
				slice.sort(matches[:])
				fmt.printf("\n%s\n%s%s", strings.join(matches[:], "  "), PROMPT, prefix)
				fmt.printf("\r%s%s", PROMPT, string(input_buf^[:]))
			}
		}
	}
}
