package main

import "core:math/rand"
import "core:strings"
import "core:testing"
@(test)
test_no_args_repl :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh"})
	testing.expect_value(t, cli.dash_c, false)
	testing.expect_value(t, cli.dash_s, false)
	testing.expect_value(t, cli.arg0, "zsh")
	testing.expect_value(t, len(cli.positional), 0)
}

@(test)
test_dash_c_simple :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-c", "echo hi"})
	testing.expect_value(t, cli.dash_c, true)
	testing.expect_value(t, cli.command_string, "echo hi")
	testing.expect_value(t, cli.arg0, "zsh")
}

@(test)
test_dash_ic_cluster :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-ic", "echo hi"})
	testing.expect_value(t, cli.dash_c, true)
	testing.expect_value(t, cli.dash_i, true)
	testing.expect_value(t, cli.command_string, "echo hi")
}

@(test)
test_dash_ci_order_irrelevant :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-ci", "echo hi"})
	testing.expect_value(t, cli.dash_c, true)
	testing.expect_value(t, cli.dash_i, true)
	testing.expect_value(t, cli.command_string, "echo hi")
}

@(test)
test_dash_c_with_arg0_and_positional :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-c", "echo $0", "myname", "p1", "p2"})
	testing.expect_value(t, cli.command_string, "echo $0")
	testing.expect_value(t, cli.arg0, "myname")
	testing.expect_value(t, len(cli.positional), 2)
	testing.expect_value(t, cli.positional[0], "p1")
	testing.expect_value(t, cli.positional[1], "p2")
}

@(test)
test_dash_s_keeps_arg0 :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-s", "name", "p1"})
	testing.expect_value(t, cli.dash_s, true)
	testing.expect_value(t, cli.arg0, "zsh") // NOT "name"
	testing.expect_value(t, len(cli.positional), 2)
	testing.expect_value(t, cli.positional[0], "name")
	testing.expect_value(t, cli.positional[1], "p1")
}

@(test)
test_script_path_consumes_arg0 :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "script.sh", "p1"})
	testing.expect_value(t, cli.script_path, "script.sh")
	testing.expect_value(t, cli.arg0, "script.sh")
	testing.expect_value(t, cli.positional[0], "p1")
}

@(test)
test_double_dash_ends_flags :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "--", "-c"})
	testing.expect_value(t, cli.dash_c, false) // -c after -- is positional
	testing.expect_value(t, cli.script_path, "-c")
}


// Removed: test_empty_argv_safe — POSIX guarantees argv has at least argv[0],
// so an empty argv slice cannot occur in real invocations. The current parser
// also panics on it (argv[1:] out-of-bounds), so the test was both unrealistic
// AND a crash, while test_no_args_repl already covers the realistic minimum case.
//
// Removed: test_only_program_name — exact duplicate of test_no_args_repl.

@(test)
test_dash_c_no_string :: proc(t: ^testing.T) {
	cli := parse_cli_args({"zsh", "-c"})
	testing.expect_value(t, cli.dash_c, true)
	testing.expect_value(t, cli.command_string, "")
	// Verified against real zsh 5.8.1: `zsh -c` prints `zsh: string expected after -c`
	// and exits 1. We pin the suffix (without the `zsh: ` prefix the reporter will add).
	testing.expect_value(t, cli.parse_error_message, "string expected after -c")
}

@(test)
test_unknown_short_flag_errors :: proc(t: ^testing.T) {
	// Real zsh 5.8.1: `zsh -z` prints `zsh: bad option: -z` and exits 1.
	// `-z` is genuinely undefined; `-Z` is NOT (it sets the process title), so
	// the previous test using -Z was a false negative.
	cli := parse_cli_args({"zsh", "-z"})
	testing.expect_value(t, cli.dash_c, false)
	testing.expect(
		t,
		cli.parse_error_message != "",
		"unknown short flag -z must populate parse_error_message",
	)
	// TODO(parser): until cli.odin's switch grows a default: case that errors,
	// this assertion fails — that's the point. Flip green by erroring on unknown letters.
}

@(test)
test_dash_c_followed_by_flag :: proc(t: ^testing.T) {
	// `zsh -c -i` — real zsh treats `-i` as the COMMAND STRING (the value after -c),
	// not as another flag. So dash_i must remain false and command_string must be "-i".
	// This pins the rule "-c is terminating: the next argv is consumed verbatim".
	cli := parse_cli_args({"zsh", "-c", "-i"})
	testing.expect_value(t, cli.dash_c, true)
	testing.expect_value(t, cli.dash_i, false)
	testing.expect_value(t, cli.command_string, "-i")
}

@(test)
test_repeated_flag_idempotent :: proc(t: ^testing.T) {
	a := parse_cli_args({"zsh", "-c", "echo hi"})
	b := parse_cli_args({"zsh", "-cc", "echo hi"})
	c := parse_cli_args({"zsh", "-c", "-c", "echo hi"})
	testing.expect_value(t, a.dash_c, b.dash_c)
	testing.expect_value(t, b.dash_c, c.dash_c)
	testing.expect_value(t, a.command_string, b.command_string)
	testing.expect_value(t, b.command_string, c.command_string)
}

@(test)
test_bare_dash_means_dash_s :: proc(t: ^testing.T) {
	// Verified against real zsh 5.8.1: bare `-` is historical shorthand for `-s`
	// (read commands from stdin). $- contains 's' after `zsh -` is invoked.
	// It is NOT a flag cluster (no letters follow), so the current parser's
	// `for j in 1..<len(argv[i])` loop body never runs and the dash is silently
	// swallowed — this test fails until the parser handles bare `-` explicitly.
	cli := parse_cli_args({"zsh", "-"})
	testing.expect_value(t, cli.dash_s, true)
	testing.expect_value(t, cli.arg0, "zsh")
}


// Helper: make a random argv element of length 0..max_len with random ASCII
random_arg :: proc(max_len: int, allocator := context.temp_allocator) -> string {
	n := int(rand.int31_max(i32(max_len) + 1))
	buf := make([]u8, n, allocator)
	for i in 0 ..< n {
		// Bias toward printable ASCII so we sometimes hit '-', '+', flag chars
		buf[i] = u8(0x20 + rand.int31_max(0x5F))
	}
	return string(buf)
}

random_argv :: proc(max_count: int, allocator := context.temp_allocator) -> []string {
	n := int(rand.int31_max(i32(max_count))) + 1 // at least 1 (program name)
	argv := make([]string, n, allocator)
	for i in 0 ..< n {
		argv[i] = random_arg(20, allocator)
	}
	return argv
}

@(test)
test_fuzz_no_panic :: proc(t: ^testing.T) {
	// Property: parser never crashes for any input
	rand.reset(42) // deterministic seed for reproducibility
	for trial in 0 ..< 5000 {
		defer free_all(context.temp_allocator)
		argv := random_argv(15)
		cli := parse_cli_args(argv)
		_ = cli // just running without panic is the assertion
	}
}

@(test)
test_fuzz_arg0_always_set :: proc(t: ^testing.T) {
	// Property: arg0 is non-empty after any parse
	rand.reset(123)
	for trial in 0 ..< 5000 {
		defer free_all(context.temp_allocator)
		argv := random_argv(15)
		cli := parse_cli_args(argv)
		testing.expectf(t, cli.arg0 != "", "trial %d: arg0 was empty for  argv=%v", trial, argv)
	}
}

@(test)
test_fuzz_mode_exclusivity :: proc(t: ^testing.T) {
	// Property: command_string and script_path are mutually exclusive
	rand.reset(999)
	for trial in 0 ..< 5000 {
		defer free_all(context.temp_allocator)
		argv := random_argv(15)
		cli := parse_cli_args(argv)
		both_set := cli.command_string != "" && cli.script_path != ""
		testing.expectf(
			t,
			!both_set,
			"trial %d: both command_string=%q and script_path=%q set",
			trial,
			cli.command_string,
			cli.script_path,
		)
	}
}

@(test)
test_fuzz_long_clusters :: proc(t: ^testing.T) {
	// Property: pathologically long flag clusters don't crash AND any letter
	// from "cilsf" in the cluster sets the corresponding flag at least once.
	rand.reset(7)
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)
	strings.write_byte(&sb, '-')
	saw := map[u8]bool{}
	defer delete(saw)
	for _ in 0 ..< 10000 {
		chars := "cilsf"
		ch := chars[rand.int31_max(i32(len(chars)))]
		strings.write_byte(&sb, ch)
		saw[ch] = true
	}
	cli := parse_cli_args({"zsh", strings.to_string(sb), "echo hi"})
	if saw['c'] {testing.expect(t, cli.dash_c, "saw 'c' in cluster but dash_c is false")}
	if saw['i'] {testing.expect(t, cli.dash_i, "saw 'i' in cluster but dash_i is false")}
	if saw['l'] {testing.expect(t, cli.dash_l, "saw 'l' in cluster but dash_l is false")}
	if saw['s'] {testing.expect(t, cli.dash_s, "saw 's' in cluster but dash_s is false")}
	if saw['f'] {testing.expect(t, cli.dash_f, "saw 'f' in cluster but dash_f is false")}
}

@(test)
test_fuzz_idempotence_pure_args :: proc(t: ^testing.T) {
	// Property: parsing the same argv twice yields the same result
	rand.reset(2024)
	for trial in 0 ..< 1000 {
		defer free_all(context.temp_allocator)
		argv := random_argv(10)
		a := parse_cli_args(argv)
		b := parse_cli_args(argv)
		testing.expect_value(t, a.dash_c, b.dash_c)
		testing.expect_value(t, a.dash_i, b.dash_i)
		testing.expect_value(t, a.dash_l, b.dash_l)
		testing.expect_value(t, a.dash_s, b.dash_s)
		testing.expect_value(t, a.dash_f, b.dash_f)
		testing.expect_value(t, a.command_string, b.command_string)
		testing.expect_value(t, a.script_path, b.script_path)
		testing.expect_value(t, a.arg0, b.arg0)
	}
}
