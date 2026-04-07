package main

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:strings"

// Parse_Error already handled by this func, caller should just continue
parse_input :: proc(raw_input: string) -> (result: Parse_Result, err: Error) {
	io_err: io.Error
	alloc_err: runtime.Allocator_Error
	cmd_builder: strings.Builder
	args_builder: strings.Builder
	defer strings.builder_destroy(&cmd_builder)
	defer strings.builder_destroy(&args_builder)

	input := strings.trim_left(raw_input, " ")
	if len(input) == 0 {
		return {}, .Empty_Input
	}

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
	brace_depth := 0
	args := [dynamic]string{}

	arg: strings.Builder
	defer strings.builder_destroy(&arg)

	arg, alloc_err = strings.builder_make_none()
	if alloc_err != nil {
		return {}, alloc_err
	}

	stdin_filename := ""
	stdout_filename := ""
	stdout_append := false
	stderr_filename := ""
	stderr_append := false

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

			if c == '}' && brace_depth == 0 {
				if index + 1 < len(input) && input[index + 1] != ' ' {
					_, io_err = strings.write_rune(&arg, c)
					if io_err != nil {
						return {}, io_err
					}
					continue
				}
				// if '}' is last or has has whitespace next (white space before is already prev iteration below)
				fmt.eprintf("%s: parse error near `}'\n", SHELL_NAME)
				return {}, .Parse_Error
			}
			if c == '{' {
				brace_depth += 1
			}
			if c == '}' {
				brace_depth -= 1
			}

			if c == ' ' {
				if brace_depth > 0 {
					fmt.eprintf("%s: parse error near `}'\n", SHELL_NAME)
					return {}, .Parse_Error
				}
				if strings.builder_len(arg) > 0 {
					append(&args, strings.clone(strings.to_string(arg), context.temp_allocator))
					strings.builder_reset(&arg)
				}
				continue
			}
			if c == '>' {
				if strings.to_string(arg) == "2" {
					strings.builder_reset(&arg)
					if raw_args[index + 1] == '>' {
						remaining := strings.trim(raw_args[index + 2:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stderr_filename = strings.trim(first_word[0], " ")
						stderr_append = true
					} else {
						remaining := strings.trim(raw_args[index + 1:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stderr_filename = strings.trim(first_word[0], " ")
					}
				} else if strings.to_string(arg) == "1" {
					strings.builder_reset(&arg)
					if raw_args[index + 1] == '>' {
						remaining := strings.trim(raw_args[index + 2:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stdout_filename = strings.trim(first_word[0], " ")
						stdout_append = true
					} else {
						remaining := strings.trim(raw_args[index + 1:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stdout_filename = strings.trim(first_word[0], " ")
					}
				} else {
					if raw_args[index + 1] == '>' {
						remaining := strings.trim(raw_args[index + 2:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stdout_filename = strings.trim(first_word[0], " ")
						stdout_append = true
					} else {
						remaining := strings.trim(raw_args[index + 1:], " ")
						first_word, split_err := strings.split(
							remaining,
							" ",
							context.temp_allocator,
						)
						if split_err != nil {
							return {}, split_err
						}
						stdout_filename = strings.trim(first_word[0], " ")
					}
				}
				break
			}

			if c == '<' {
				if strings.builder_len(arg) > 0 {
					append(&args, strings.clone(strings.to_string(arg), context.temp_allocator))
					strings.builder_reset(&arg)
				}

				remaining := strings.trim(raw_args[index + 1:], " ")
				first_word, split_err := strings.split(remaining, " ", context.temp_allocator)
				if split_err != nil {
					return {}, split_err
				}
				stdin_filename = first_word[0]
				break
			}

			_, io_err = strings.write_rune(&arg, c)
			if io_err != nil {
				return {}, io_err
			}
		}
	}

	if strings.builder_len(arg) > 0 {
		append(&args, strings.clone(strings.to_string(arg), context.temp_allocator))
	}

	result = {
		command = cmd,
		args = args[:],
		stdin_redirect = Redirect{filename = stdin_filename, append_mode = false},
		stdout_redirect = Redirect{filename = stdout_filename, append_mode = stdout_append},
		stderr_redirect = Redirect{filename = stderr_filename, append_mode = stderr_append},
	}
	err = {}

	return
}


// | support a.k.a. redirect stdout of first command to stdin second command
// Ex: ls -l | grep ".md"
pipe_split :: proc(input: string) -> ([]string, Error) {
	in_single_quote := false
	in_double_quote := false
	is_backslash := false
	commands := [dynamic]string{}
	new_command_index := 0
	skip_next := false

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
			if skip_next {
				skip_next = false
				continue
			}
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
				if index + 1 < len(input) && input[index + 1] == '|' {
					skip_next = true
					continue
				} else {
					trimmed := strings.trim_space(input[new_command_index:index])
					if len(trimmed) == 0 {
						fmt.eprintf("%s: parse error near `|'\n", SHELL_NAME)
						return {}, .Parse_Error
					} else {
						append(&commands, trimmed)
						new_command_index = index + 1
						continue
					}
				}
			}
		}
	}

	trimmed := strings.trim_space(input[new_command_index:])
	if len(trimmed) == 0 {
		fmt.eprintf("%s: parse error near `|'\n", SHELL_NAME)
		return {}, .Parse_Error
	} else {
		append(&commands, trimmed)
	}


	return commands[:], nil
}

// ; support
split_commands :: proc(input: string) -> ([]string, Error) {
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

			if c == ';' {
				trimmed := strings.trim_space(input[new_command_index:index])
				if len(trimmed) == 0 {
					fmt.eprintf("%s: parse error near `;;'\n", SHELL_NAME)
					return nil, .Parse_Error
				} else {
					append(&commands, trimmed)
					new_command_index = index + 1
					continue
				}
			}
		}
	}

	trimmed := strings.trim_space(input[new_command_index:])
	if len(trimmed) > 0 {
		append(&commands, trimmed)
	}

	return commands[:], nil
}
