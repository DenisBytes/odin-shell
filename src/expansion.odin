package main

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

expand_tilde :: proc(word: string) -> (string, bool) {
	if len(word) == 0 || word[0] != '~' {
		return word, true
	}

	if len(word) == 1 || word[1] == '/' {
		home := os.get_env_alloc("HOME", context.temp_allocator)
		if len(home) == 0 {
			return word, true
		}
		if len(word) == 1 {
			return home, true
		}

		path_with_home, err := strings.concatenate({home, word[1:]}, context.temp_allocator)
		if err != nil {oom_fatal()}
		return path_with_home, true
	}

	slash_idx := strings.index_byte(word, '/')
	username := ""
	rest := ""
	if slash_idx == -1 {
		username = word[1:]
	} else {
		username = word[1:slash_idx]
		rest = word[slash_idx:]
	}

	username_s, clone_err := strings.clone_to_cstring(username, context.temp_allocator)
	if clone_err != nil {oom_fatal()}

	// looks for user details in /etc/passwd with the user username "username_s"
	pw := posix.getpwnam(username_s)
	if pw == nil {
		return word, false
	}

	home_dir, clone_from_err := strings.clone_from_cstring(pw.pw_dir, context.temp_allocator)
	if clone_from_err != nil {oom_fatal()}

	path_with_home, err := strings.concatenate({home_dir, rest}, context.temp_allocator)
	if err != nil {oom_fatal()}

	return path_with_home, true
}


expand_braces :: proc(word: string) -> []string {
	open := -1
	// thanks to depth we keep track which close brace belongs to which open brace
	depth := 0

	fail_result := make([]string, 1, context.temp_allocator)
	fail_result[0] = word
	for c, index in word {
		if c == '{' {
			if open == -1 {
				open = index
			}
			depth += 1
		} else if c == '}' {
			depth -= 1
			if depth == 0 && open != -1 {
				prefix := word[0:open]
				body := word[open + 1:index]
				suffix := word[index + 1:]

				if strings.contains(body, "..") && !strings.contains(body, ",") {
					return expand_brace_range(prefix, body, suffix)
				}
				if strings.contains(body, ",") {
					return expand_brace_comma(prefix, body, suffix)
				}

				return fail_result
			}
		}
	}

	return fail_result
}


expand_brace_comma :: proc(prefix, body, suffix: string) -> []string {
	parts := make([dynamic]string, context.temp_allocator)
	depth := 0
	start := 0

	for c, index in body {
		// skip nested braces
		if c == '{' {
			depth += 1
		}
		if c == '}' {
			depth -= 1
		}

		if c == ',' && depth == 0 {
			append(&parts, body[start:index])
			start = index + 1
		}
	}

	append(&parts, body[start:])
	result := make([dynamic]string, context.temp_allocator)
	for p in parts {
		combined, concat_err := strings.concatenate({prefix, p, suffix}, context.temp_allocator)
		if concat_err != nil {oom_fatal()}
		sub_results := expand_braces(combined)
		for sub_r in sub_results {
			append(&result, sub_r)
		}
	}

	return result[:]
}


expand_brace_range :: proc(prefix, body, suffix: string) -> []string {
	failed, concat_err := strings.concatenate(
		{prefix, "{", body, "}", suffix},
		context.temp_allocator,
	)
	if concat_err != nil {oom_fatal()}

	failed_result := make([]string, 1, context.temp_allocator)
	failed_result[0] = failed

	parts, split_err := strings.split(body, "..", context.temp_allocator)
	if split_err != nil {oom_fatal()}

	num1, ok1 := strconv.parse_int(parts[0])
	num2, ok2 := strconv.parse_int(parts[1])


	if ok1 && ok2 {
		step := 1
		if num1 > num2 {
			step = -1
		}
		if len(parts) == 3 {
			step_num, ok3 := strconv.parse_int(parts[2])
			if !ok3 || step_num == 0 {
				return failed_result
			} else {
				step *= step_num
			}
		}

		result := make([dynamic]string, context.temp_allocator)
		index := num1

		has_padding :=
			(parts[0][0] == '0' && len(parts[0]) > 1) || (parts[1][0] == '0' && len(parts[1]) > 1)
		pad_width := max(len(parts[0]), len(parts[1]))

		for {
			formatted := fmt.tprintf("%d", index)

			if has_padding {
				for len(formatted) < pad_width {
					formatted = fmt.tprintf("%d%s", 0, formatted)
				}
			}

			combined, concat_err := strings.concatenate(
				{prefix, formatted, suffix},
				context.temp_allocator,
			)
			if concat_err != nil {oom_fatal()}

			sub_results := expand_braces(combined)
			for sub_r in sub_results {
				append(&result, sub_r)
			}

			if (step < 0 && index <= num2) || (step > 0 && index >= num2) {
				break
			}

			index += step
		}
		return result[:]
	}
	if len(parts[0]) == 1 && len(parts[1]) == 1 {
		step: rune = 1
		// alphabetic comparison
		if parts[0] > parts[1] {
			step = -1
		}
		result := make([dynamic]string, context.temp_allocator)
		ch := rune(parts[0][0])

		for {
			combined, concat_err := strings.concatenate(
				{prefix, fmt.tprintf("%c", ch), suffix},
				context.temp_allocator,
			)
			if concat_err != nil {oom_fatal()}

			sub_results := expand_braces(combined)
			for sub_r in sub_results {
				append(&result, sub_r)
			}
			if ch == rune(parts[1][0]) {break}
			ch += step
		}

		return result[:]
	}

	return failed_result
}

expand_parameters :: proc(word: string) -> string {
	alloc_err: runtime.Allocator_Error
	io_err: io.Error
	has_dollar_sign := strings.contains(word, "$")
	if !has_dollar_sign {
		return word
	}

	result: strings.Builder

	result, alloc_err = strings.builder_make_none(context.temp_allocator)
	if alloc_err != nil {
		oom_fatal()
	}

	i := 0
	for i < len(word) {
		if word[i] == '$' {
			i += 1
			if i >= len(word) {
				_, io_err = strings.write_rune(&result, '$')
				if io_err != nil {
					oom_fatal()
				}
				break
			}
			switch word[i] {
			case '?':
				_ = strings.write_i64(&result, i64(last_exit_code))
				i += 1
				continue
			case '$':
				_ = strings.write_int(&result, os.get_pid())
				i += 1
				continue
			case '0':
				_ = strings.write_string(&result, SHELL_NAME)
				i += 1
				continue
			case '{':
				after := word[i + 1:]
				idx := strings.index_byte(after, '}')
				if idx == -1 {
					_, io_err = strings.write_rune(&result, '$')
					if io_err != nil {
						oom_fatal()
					}
					_, io_err = strings.write_rune(&result, rune(word[i]))
					if io_err != nil {
						oom_fatal()
					}
					i += 1
					continue
				} else {
					body := word[i + 1:i + 1 + idx]
					value := expand_param_braced(body)
					_ = strings.write_string(&result, value)
					i = i + 1 + idx + 1
					continue
				}
			case:
				start := i
				for i < len(word) && (is_alnum(word[i])) {
					i += 1
				}
				if i == start {
					_, io_err = strings.write_rune(&result, '$')
					if io_err != nil {
						oom_fatal()
					}
					continue
				}
				env_name := word[start:i]
				env_value := os.get_env_alloc(env_name, context.temp_allocator)
				_ = strings.write_string(&result, env_value)
				continue
			}

		} else {
			_, io_err = strings.write_rune(&result, rune(word[i]))
			if io_err != nil {
				oom_fatal()
			}
			i += 1
			continue
		}
	}
	return strings.to_string(result)
}

expand_param_braced :: proc(body: string) -> string {
	if strings.contains(body, ":-") {
		idx := strings.index(body, ":-")
		env_name := body[:idx]
		default := body[idx + 2:]
		env_value := os.get_env_alloc(env_name, context.temp_allocator)
		if len(env_value) > 0 {
			return env_value
		}
		return default
	} else if strings.contains(body, ":=") {
		idx := strings.index(body, ":=")
		env_name := body[:idx]
		default := body[idx + 2:]
		env_value := os.get_env_alloc(env_name, context.temp_allocator)
		if len(env_value) > 0 {
			return env_value
		}
		_ = os.set_env(env_name, default)
		return default
	} else if strings.contains(body, ":+") {
		idx := strings.index(body, ":+")
		env_name := body[:idx]
		alt := body[idx + 2:]
		env_value := os.get_env_alloc(env_name, context.temp_allocator)
		if len(env_value) > 0 {
			return alt
		}
		return ""
	} else if strings.contains(body, "%") {
		idx := strings.index_byte(body, '%')
		env_name := body[:idx]
		suffix := body[idx + 1:]
		env_value := os.get_env_alloc(env_name, context.temp_allocator)
		if strings.contains(env_value, suffix) {
			if env_value[len(env_value) - len(suffix):] == suffix {
				return env_value[:len(env_value) - len(suffix)]
			}
		}
		return env_value
	} else if strings.contains(body, "#") {
		idx := strings.index_byte(body, '#')
		env_name := body[:idx]
		prefix := body[idx + 1:]
		env_value := os.get_env_alloc(env_name, context.temp_allocator)
		if strings.contains(env_value, prefix) {
			if env_value[:len(prefix)] == prefix {
				return env_value[len(prefix):]
			}
		}
		return env_value
	} else {
		env_value := os.get_env_alloc(body, context.temp_allocator)
		return env_value
	}
}


is_alnum :: proc(b: byte) -> bool {
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || (b >= '0' && b <= '9') || b == '_'
}
