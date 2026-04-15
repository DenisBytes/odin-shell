# odin-shell

Implementing a zsh shell from scratch in Odin.

# NOT AI SLOP

AI has NOT been used to implement any piece of this code. 
AI has been used only to review the codebase. All implementation, architecture, design, debugging, etc... has been done by a human.

## Features

### Builtin Commands
- `echo`, `type`, `pwd`, `cd`, `exit`, `history`

### Command Execution
- External program execution via `PATH` lookup
- Process forking with `fork`/`execvp`
- Exit code tracking (`$?` semantics)

### Parsing & Quoting
- Single and double quote handling with escape sequences
- Backslash escaping outside quotes
- Semicolon (`;`) command chaining
- Brace parsing with error detection

### I/O Redirection
- Stdout redirection (`>`, `>>`, `1>`, `1>>`)
- Stderr redirection (`2>`, `2>>`)
- Stdin redirection (`<`)

### Pipelines
- Multi-command pipelines (`cmd1 | cmd2 | cmd3`)
- Proper pipe fd management and per-stage forking
- Exit code from last pipeline stage (zsh semantics)

### Expansions
- Tilde expansion (`~`, `~/path`, `~user`)
- Brace expansion — comma lists (`{a,b,c}`)
- Brace expansion — numeric ranges (`{1..10}`, `{01..05}`, `{1..10..2}`)
- Brace expansion — alphabetic ranges (`{a..z}`)
- Nested brace expansion

### Tab Completion
- Command name completion (builtins + `PATH` executables)
- File and directory path completion
- Longest common prefix completion
- Double-tab to list all matches

### History
- Arrow key (up/down) history navigation
- `HISTFILE` persistence (load on start, append on exit)
- `history` builtin with `-w`, `-a`, `-r` flags
- `history N` to show last N entries

### Terminal
- Raw mode input (char-by-char via termios)
- Termios restore on exit

### Planned
- Glob expansion (`*`, `?`, `**`)
- Environment variable expansion (`$VAR`, `${VAR}`)
- `&&` and `||` operators
- Job control (`&`, `fg`, `bg`, `jobs`)
- Signal handling (`SIGINT`, `SIGTSTP`)
- Aliases and functions
- Prompt customization
