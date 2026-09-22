# cpp-dsa-setup

Terminal / VS Code setup for running a single `.cpp` file with stdin
redirected from an input file — the fallback for presenting DSA sessions
when CLion (see `../tools-setup/install-clion.sh`) isn't available or
hasn't been licensed yet.

## Status on this machine

Already good to go, no install needed:

- `g++` (Ubuntu/Mint's default, currently 13.3.0) fully supports
  **C++20** — verified by compiling and running a file using `<concepts>`
  and `<ranges>`.
- VS Code has the `ms-vscode.cpptools-extension-pack` installed already.

So CLion is nice-to-have for the polished IDE experience in front of an
audience, but isn't required to run or present C++ code on this machine.

## Terminal workflow (no VS Code needed)

```bash
g++ -std=c++20 -O2 -Wall -Wextra -o main main.cpp
./main < input.txt
```

Or as one line:

```bash
g++ -std=c++20 -O2 -Wall -Wextra -o main main.cpp && ./main < input.txt
```

## VS Code workflow

`template/` has a ready-to-copy skeleton:

- `main.cpp` — trivial fast-IO C++20 skeleton to swap session code into.
- `input.txt` — sample stdin input matching the skeleton.
- `.vscode/tasks.json` — two tasks:
  - **build** (`Ctrl+Shift+B`) — compiles the currently open file with
    `-std=c++20 -O2 -Wall -Wextra -g`.
  - **run with input.txt** (`Ctrl+Shift+P` → `Run Task` → `run with
    input.txt`) — builds, then runs the binary with stdin piped from
    `input.txt` in the same directory as the source file.

To use for a session: copy `template/` to wherever the day's problem
lives (or just keep reusing it and overwrite `main.cpp`/`input.txt`), open
the folder in VS Code, edit `main.cpp`, edit `input.txt`, run the task.

## Why not just use the debugger for input?

VS Code's C++ debug configs (`launch.json`) don't support stdin
redirection directly — the integrated/external debug console doesn't take
piped input. For DSA sessions, compiling + running with `<` from a task
(or straight from the terminal) is simpler and is what's set up here. If
step-through debugging is ever needed, `gdb` is available directly:

```bash
gdb --args ./main
(gdb) run < input.txt
```
