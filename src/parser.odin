package main

import "base:runtime"
import "core:io"
import "core:strings"

parse_input :: proc(raw_input: string) -> (result: Parse_Result, err: Error) {
	io_err: io.Error
	alloc_err: runtime.Allocator_Error
	cmd_builder: strings.Builder
	args_builder: strings.Builder

	if len(raw_input) == 0 {
		return {}, Shell_Error.Empty_Input
	}

	input := strings.trim_left(raw_input, " ")
	cmd_builder, alloc_err = strings.builder_make_none()
	if alloc_err != nil {
		return {}, alloc_err
	}
	args_builder, alloc_err = strings.builder_make_none()
	if alloc_err != nil {
		return {}, alloc_err
	}

	cmd := ""
	raw_args := ""
	is_backslash := false

	if input[0] == '\'' {
		for c, index in input[1:] {
			if c == '\'' {
				cmd = strings.to_string(cmd_builder)
				raw_args = input[index + 2:]
				break
			}

			_, io_err = strings.write_rune(&cmd_builder, c)
			if io_err != nil {
				return {}, io_err
			}
		}
	} else if input[0] == '"' {
		for c, index in input[1:] {
			if is_backslash {
				is_backslash = false
				switch c {
				case:
					_, io_err = strings.write_rune(&args_builder, c)
					if io_err != nil {
						return {}, io_err
					}
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
			_, io_err = strings.write_rune(&args_builder, c)
			if io_err != nil {
				return {}, io_err
			}
		}
	} else {
		cmd, _, raw_args = strings.partition(input, " ")
	}


	in_single_quote := false
	in_double_quote := false
	is_backslash = false
	args := [dynamic]string{}

	arg: strings.Builder

	arg, alloc_err = strings.builder_make_none()
	if alloc_err != nil {
		return {}, alloc_err
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
			_, io_err = strings.write_rune(&arg, c)
			if io_err != nil {
				return {}, io_err
			}
		} else if in_double_quote {
			if is_backslash {
				is_backslash = false
				switch c {
				case:
					_, io_err = strings.write_rune(&arg, c)
					if io_err != nil {
						return {}, io_err
					}
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

			_, io_err = strings.write_rune(&arg, c)
			if io_err != nil {
				return {}, io_err
			}
		} else {
			if is_backslash {
				_, io_err = strings.write_rune(&arg, c)
				if io_err != nil {
					return {}, io_err
				}
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

			_, io_err = strings.write_rune(&arg, c)
			if io_err != nil {
				return {}, io_err
			}
		}
	}

	if strings.builder_len(arg) > 0 {
		append(&args, strings.clone(strings.to_string(arg)))
	}

	result = {
		command = cmd,
		args = args[:],
		stdout_redirect = Redirect{filename = stdout_filename, append_mode = append_file},
		stderr_redirect = Redirect{filename = stderr_filename, append_mode = append_file},
	}
	err = {}

	return
}
