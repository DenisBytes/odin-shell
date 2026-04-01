package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:sys/posix"

/*
 * THINGS I HAVE LEARNED
 * 
 *  A shell is just a parser of commands + creator of processes + extra features like builtin commands, autocomplete, quoting, redirect (1>, 1>>, 2>, 2>>) and pipelines
 *  
 *  If you go to /dev/pts/ you can see all the TTY (in history they were physical teletypewriter, but nowadays are pty = pseudo terminal) 
 *  
 *  A termios is the configuration of the TTY/PTY. You can look at current config with: stty -a
 *    Some output lines:
 *      intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>;
 *      isig icanon iexten echo echoe echok -echonl -noflsh -xcase -tostop -echoprt
 *    A shell needs to overwrite the termios config and make it raw (not canonical basically) to handle, for example, the input chat by char,
 *      instead of the whole line + \n signal (ENTER). But at the end it most restore the original termios config
 *      You do that with posix.tcgetattr (get current termios) and tcsetattr to set differnt flags in the config  
 *
 *  You can fork processes: it does a copy of the state of the current process (More exactly a COW, Copy on Write)
 *  
 *  You can redirect output to other FD (such as a pipe write end (then the content can be read from the pipe read end)) and redirect stdout and stderr to files
 *    you do this with posix.dup2(pipe_write_end, stdout) a.k.a. make stdout FD (1) point to where pipe_write_end fd is pointing to
 *  You can create a pipe to handle communication between processes's stdin and stdout (not stderr apperently) 
 *    For the next process to read form the pipe read end, the write end must be closed (it needs the EOF signal) 
 *    you must do a waitpid() at the end for every child process spawned, otherwise the parent won't block and the child process wont be cleaned up
 *      in the process table. waitpid() will handle the removal of the child processes from the process table
 *        fork() -> child exits
 *          child: execvp() -> becomes "cat ..." or "head ..."
 *          "cat" finishes -> child exists -> becomes zombie
 *        parent: waitpid() -> read exit code (&status) -> zombie removed
 *  
 *  execvp replaces the current odin process memory with a new program (the command you are passing). On success it never returns.
 *  the l, v, p, e in the exec*  functions (execvp, execv, execle, etc...) they are just like options/flags/suffix-system:
 *    - l: args as a list. execl("/bin/ls", "ls", "-la", NULL)
 *    - v: args as an array. execv("/bin/ls", args)
 *    - p: search PATH for the command. execlp("ls", "ls", "-la", NULL)
 *    - e: pass custom ENVs. execve("/bin/ls", args, custom_env)
 *
 *  * */

original_termios: posix.termios

main :: proc() {
	// FD(0) == stdin
	posix.tcgetattr(posix.FD(c.int(0)), &original_termios)

	raw := original_termios
	raw.c_lflag -= {.ICANON, .ECHO}
	posix.tcsetattr(posix.FD(c.int(0)), .TCSANOW, &raw)

	history_file := os.get_env_alloc("HISTFILE", context.temp_allocator)
	if len(history_file) > 0 {

		file_bytes, file_bytes_err := os.read_entire_file(history_file, context.temp_allocator)
		if file_bytes_err == nil {
			history_commands, history_commands_err := strings.split(string(file_bytes[:]), "\n")
			if history_commands_err != nil {
				fmt.printf("history: parsing error: %w\n", history_commands_err)
				return
			}
			for c in history_commands {
				if len(c) != 0 {
					append(&commands_history, strings.clone(c))
				}
			}
		}
	}

	last_append_index = len(commands_history)

	input_str := ""
	history_index := len(commands_history)

	for {
		fmt.printf(PROMPT)
		input_buf: [dynamic]byte
		defer delete(input_buf)

		tab_count: uint = 0
		inner: for {
			char_buf: [1]byte
			n, read_err := os.read(os.stdin, char_buf[:])
			if read_err != nil || n == 0 {
				break
			}

			ch := char_buf[0]

			switch ch {
			// ENTER
			case '\n':
				fmt.printf("\n")
				input_str = string(input_buf[:])
				break inner
			// TAB
			case '\t':
				tab_count += 1
				try_autocomplete(&input_buf, tab_count)
				continue
			// DELETE
			case 127:
				tab_count = 0
				if len(input_buf) > 0 {
					pop(&input_buf)
					fmt.printf("\b \b")
				}
				continue
			// ARROW_UP
			case '\x1b':
				seq: [2]byte
				os.read(os.stdin, seq[:])
				if seq[0] == '[' && seq[1] == 'A' {
					if history_index > 0 {
						history_index -= 1
						fmt.printf("\r%s", PROMPT)
						for _ in 0 ..< len(input_buf) {
							fmt.printf(" ")
						}
						fmt.printf("\r%s", PROMPT)
						history_bytes := transmute([]byte)commands_history[history_index]
						clear(&input_buf)
						append(&input_buf, ..history_bytes)
						fmt.printf("%s", string(input_buf[:]))
					}
				} else if seq[0] == '[' && seq[1] == 'B' {
					if history_index < len(commands_history) - 1 {
						history_index += 1
						fmt.printf("\r%s", PROMPT)
						for _ in 0 ..< len(input_buf) {
							fmt.printf(" ")
						}
						fmt.printf("\r%s", PROMPT)
						history_bytes := transmute([]byte)commands_history[history_index]
						clear(&input_buf)
						append(&input_buf, ..history_bytes)
						fmt.printf("%s", string(input_buf[:]))
					}
				}
				continue
			case:
				tab_count = 0
				append(&input_buf, ch)
				fmt.printf("%c", ch)
			}
		}

		input_clone, _ := strings.clone(input_str)
		append(&commands_history, input_clone)
		history_index = len(commands_history)

		pipe_split_commands, pipe_split_err := pipe_split(input_str)
		if pipe_split_err != nil {
			fmt.printf("zsh: parse error near `|'")
			return
		}

		if len(pipe_split_commands) > 1 {
			execute_pipeline(pipe_split_commands)
		} else {
			parse_result, err := parse_input(input_str)
			if err != nil {
				switch e in err {
				case Shell_Error:
					#partial switch e {
					case .Empty_Input:
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

			} else {

				full_path, found, err := resolve_command(parse_result.command)
				if err != nil {
					switch e in err {
					case Shell_Error:
						#partial switch e {
						case .Empty_Input:
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

				if found {

					pid := posix.fork()
					switch pid {
					case -1:
						fmt.printf("shell: error in creating fork.\n")
					case 0:
						err = exec_external(full_path, parse_result)
						if err != nil {
							fmt.printf("shell: alloc err: %v", err)
							return
						}
					case:
						status: i32
						posix.waitpid(posix.pid_t(pid), &status, {})
					}

				} else {
					fmt.printf("%s: command not found\n", parse_result.command)
				}
			}
		}
	}
}
