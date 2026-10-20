# Drive WinMux from the command line

The `winmux` CLI sends commands to the running WinMux app over a Unix socket.
The socket is `com.zimengxiong.winmux/winmux.sock` inside macOS's per-user
temporary directory. Print that directory with `getconf DARWIN_USER_TEMP_DIR`.
Debug builds use `com.zimengxiong.winmux.debug/winmux.sock` instead.

Both the app and CLI get the directory from `confstr(_CS_DARWIN_USER_TEMP_DIR)`,
which reads no environment variables. LaunchServices and a shell can have different
environments; setting `TMPDIR` or `XDG_STATE_HOME` does not change this path.
The app makes the socket again each time it starts; if the socket is removed
while WinMux runs, restart WinMux.

Run `winmux --help` for commands and `winmux <command> --help` for their options.
`winmux agent skill` prints one self-contained `SKILL.md` for configuring and
driving WinMux, even when WinMux is not running. Install it for Claude or Codex:

```sh
mkdir -p ~/.claude/skills/winmux
winmux agent skill > ~/.claude/skills/winmux/SKILL.md
mkdir -p ~/.agents/skills/winmux
winmux agent skill > ~/.agents/skills/winmux/SKILL.md
```

On a wide display, `winmux find-focus` makes the focused window easy to find:
it dims every screen around the window and draws an accent border inside its
frame. The mark holds for 0.8 seconds, then fades over 0.4 seconds; any key or
click ends it early. Press Option-semicolon, then `c`, to run it in the default
windowing mode, which stays on.

## Focus history and window marks

- `winmux focus-back` restores and focuses the previously confirmed focused window,
  switching workspace and project when needed. After macOS confirms focus, a second
  call returns. It exits 1 with `No previously focused window` when none exists.
- `winmux mark a` assigns a window to register `a`: the window `WINMUX_WINDOW_ID`
  names, or else the most recent window of `WINMUX_WORKSPACE`, or else the focused
  window. A Lens action sets `WINMUX_WINDOW_ID` to its target, a hook sets one or
  both, and a process `exec-and-forget` starts inherits them. Registers are exactly one lowercase letter `a`
  to `z`. Reassigning a register moves it to the new window; a window can hold
  several registers. Bare `winmux mark` prints that window's registers in letter
  order, separated by spaces, or nothing when it has none. Both forms exit 1 when
  there is no such window.
- `winmux jump a` restores and focuses the marked window, including a minimized or
  hidden-app window. Marks survive workspace and project moves. An empty register
  or a closed window exits 1 with `Register a is empty`; jumping to the focused
  window succeeds.
- `winmux list-marks` prints `register | window-id | app | title` in register order,
  with padded columns. `--json` prints an array with `register`, `window-id`,
  `app-name` and `window-title`; it has no `--format` option.

From a window in macOS native fullscreen, `focus-back` stays in it and `mark` marks
the most recent other window on that window's workspace, or exits 1 when there is
none, because WinMux's focus never points at a window in native fullscreen.

Marks live only for the WinMux process: restarting clears them. These are window
marks, separate from the marks a Lens toggles with Tab.
Unlike `focus-back`, upstream `focus-back-and-forth` also falls back to
never-focused windows and empty workspaces.

## Capture Policy hooks

Run `winmux debug-hooks on`, reproduce the behavior, and read the printed
`hook-capture.jsonl` path, or run `winmux subscribe hook-called` while capturing.
`winmux debug-hooks off` stops capture and prints its path and record count.
`winmux debug-hooks` (or `status`) prints whether it is on, its path, stop time
and count. Each form accepts `--json`, with `capturing`, `path`, `until`,
`records` and `error`; `error` is null unless a write failed since the last fresh `on`.

Capture is off on startup and survives config reloads. Turning it on from off
truncates the file; another `on` while capturing keeps its records and restarts
the fixed 15 minutes. The file lives in WinMux's state directory
(`$XDG_STATE_HOME/winmux`, or `~/.local/state/winmux`), readable only by you; a
debug build writes `hook-capture-debug.jsonl` there instead. The record count is
this WinMux process's capture, so a restart reports 0 for a file a previous run
wrote. A file write failure stops capture and logs the reason. `off` after the
deadline says the capture stopped itself. See [the hook guide](columns.md) for record contents
and preview behavior. This command is unavailable in config or command URLs.

## Who can drive WinMux

Any process running as you, agents included, has the CLI's full reach: every
command, every window title, closing windows and running bindings. By decision,
there is no caller boundary and no read-only mode.

Other users on the Mac cannot reach the new socket because its containing
directory is owned by you and mode 700. The app creates the directory privately,
tightens its permissions on restart, and refuses a symlink, a non-directory or
a directory owned by someone else.

For older CLIs, the legacy `/tmp/<app id>-<user>.sock` path also answers until
**The legacy `/tmp` socket stops answering** lands. That compatibility endpoint
does not have the new directory's protection. A blocked legacy endpoint is logged
and does not stop the app. A new CLI only connects to the private socket. When only the legacy
path answers, the CLI's error says to restart WinMux.

A `winmux://` link reaches further: a page or message can contain a command link.
See [who can use URL commands](url-scheme.md#who-can-use-it).
