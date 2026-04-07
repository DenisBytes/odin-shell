package main

import "core:os"
import "core:strings"
import "core:sys/posix"

expand_tilde :: proc(word: string) -> string {
	if len(word) == 0 || word[0] != '~' {
		return word
	}

	if len(word) == 1 || word[1] == '/' {
		home := os.get_env_alloc("HOME", context.temp_allocator)
		if len(home) == 0 {
			return word
		}
		if len(word) == 1 {
			return home
		}

		path_with_home, err := strings.concatenate({home, word[1:]}, context.temp_allocator)
		if err != nil {
			return word

		}
		return path_with_home
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
	if clone_err != nil {
		return word
	}

	// looks for user details in /etc/passwd with the user username "username_s"
	pw := posix.getpwnam(username_s)
	if pw == nil {
		return word
	}

	home_dir, clone_from_err := strings.clone_from_cstring(pw.pw_dir, context.temp_allocator)
	if clone_from_err != nil {
		return word
	}

	path_with_home, err := strings.concatenate({home_dir, rest}, context.temp_allocator)
	if err != nil {
		return word
	}

	return path_with_home
}
