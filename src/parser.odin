package main

import "base:runtime"
import "core:fmt"
import "core:strings"

parse_input :: proc(
	raw_input: string,
) -> (
	string,
	[]string,
	string,
	string,
	bool,
	runtime.Allocator_Error,
) {
	input := strings.trim_left(raw_input, " ")
	cmd_builder, raw_cmd_err := strings.builder_make_none()
	if raw_cmd_err != nil {
		fmt.printf("shell: error allocating in memory: %w\n", raw_cmd_err)
		return "", []string{}, "", "", false, raw_cmd_err
	}
	args_builder, raw_args_err := strings.builder_make_none()
	if raw_args_err != nil {
		fmt.printf("shell: error allocating in memory: %w\n", raw_args_err)
		return "", []string{}, "", "", false, raw_args_err
	}

	cmd := ""
	raw_args := ""
	is_backslash := false

	if input[0] == '\'' {
		for c, index in input[1:] {
			if is_backslash {
				is_backslash = false
				switch c {
				case:
					strings.write_rune(&cmd_builder, c)
				}
				continue
			}
			if c == '\\' {
				is_backslash = true
				continue
			}
			if c == '\'' {
				cmd = strings.to_string(cmd_builder)
				raw_args = input[index + 2:]
				break
			}


			strings.write_rune(&cmd_builder, c)
		}
	} else if input[0] == '"' {
		for c, index in input[1:] {
			if is_backslash {
				is_backslash = false
				switch c {
				case:
					strings.write_rune(&args_builder, c)
				}
				continue
			}
			if c == '\\' {
				is_backslash = true
				continue
			}
			if c == '"' {
				cmd = strings.to_string(args_builder)
				raw_args = input[index + 2:]
				break
			}
			strings.write_rune(&args_builder, c)
		}
	} else {
		cmd, _, raw_args = strings.partition(input, " ")
	}


	in_single_quote := false
	in_double_quote := false
	is_backslash = false
	args := [dynamic]string{}

	arg, arg_builder_err := strings.builder_make_none()
	if arg_builder_err != nil {
		fmt.printf("shell: error allocating in memory: %w\n", arg_builder_err)
		return "", []string{}, "", "", false, arg_builder_err
	}

	stdout_filename := ""
	stderr_filename := ""
	append_file := false

	for c, index in raw_args {
		if in_single_quote {
			if c == '\'' {
				in_single_quote = false
				continue
			}
			strings.write_rune(&arg, c)
		} else if in_double_quote {
			if is_backslash {
				is_backslash = false
				switch c {
				case:
					strings.write_rune(&arg, c)
				}
				continue
			}
			if c == '"' {
				in_double_quote = false
				continue
			}
			if c == '\\' {
				is_backslash = true
				continue
			}


			strings.write_rune(&arg, c)
		} else {
			if is_backslash {
				strings.write_rune(&arg, c)
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


			if c == ' ' {
				if strings.builder_len(arg) > 0 {
					append(&args, strings.clone(strings.to_string(arg)))
					strings.builder_reset(&arg)
				}
				continue
			}
			if c == '>' {
				if strings.to_string(arg) == "2" {
					strings.builder_reset(&arg)
					if raw_args[index + 1] == '>' {
						stderr_filename = strings.trim(raw_args[index + 2:], " ")
						append_file = true
					} else {
						stderr_filename = strings.trim(raw_args[index + 1:], " ")
					}
				} else if strings.to_string(arg) == "1" {
					strings.builder_reset(&arg)
					if raw_args[index + 1] == '>' {
						stdout_filename = strings.trim(raw_args[index + 2:], " ")
						append_file = true
					} else {
						stdout_filename = strings.trim(raw_args[index + 1:], " ")
					}
				} else {
					if raw_args[index + 1] == '>' {
						stdout_filename = strings.trim(raw_args[index + 2:], " ")
						append_file = true
					} else {
						stdout_filename = strings.trim(raw_args[index + 1:], " ")
					}
				}
				break
			}

			strings.write_rune(&arg, c)
		}
	}

	if strings.builder_len(arg) > 0 {
		append(&args, strings.clone(strings.to_string(arg)))
	}

	return cmd, args[:], stdout_filename, stderr_filename, append_file, nil
}
