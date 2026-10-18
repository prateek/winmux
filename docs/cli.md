# Drive WinMux from the command line

The `winmux` CLI sends commands to the running WinMux app over a Unix socket.
The socket is `com.zimengxiong.winmux/winmux.sock` inside macOS's per-user
temporary directory. Print that directory with `getconf DARWIN_USER_TEMP_DIR`.
Debug builds use `com.zimengxiong.winmux.debug/winmux.sock` instead.

Both the app and CLI get the directory from `confstr(_CS_DARWIN_USER_TEMP_DIR)`,
which reads no environment variables. LaunchServices and a shell can have different
environments; setting `TMPDIR` or `XDG_STATE_HOME` does not change this path.
The app makes the socket again each time it starts.

Run `winmux --help` for commands and `winmux <command> --help` for their options.
`winmux agent skill` prints the bundled agent skill: an agent using it drives
the same CLI through its query, edit and apply workflow.

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
and does not stop the app. A new CLI only connects to the private socket. When an
older app still answers on the legacy path, the CLI's error says to restart it.

A `winmux://` link reaches further: a page or message can contain a command link.
See [who can use URL commands](url-scheme.md#who-can-use-it).
