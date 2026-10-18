# Run a command from a URL

WinMux accepts `winmux://run/<arg>/<arg>/…`. Each path segment after `run` is one CLI argument. It is percent-decoded once, with no shell splitting or quoting rules.

```sh
open 'winmux://run/mode/window'
open 'winmux://run/lens/overview'
open 'winmux://run/workspace/2'
```

These run `winmux mode window`, `winmux lens overview` and `winmux workspace 2`. Encode a space as `%20`, a literal slash inside an argument as `%2F`, and a percent sign as `%25`. A plus sign stays a plus sign.

The CLI still validates each argument. Percent-encoding does not make an otherwise invalid command or workspace id valid.

The scheme and `run` host are case-insensitive. User names, passwords, ports, queries, fragments, missing arguments, empty segments (including a trailing slash) and invalid UTF-8 escapes are refused. URLs run one at a time in arrival order. During ordinary startup they wait until WinMux is ready; while first-run setup waits for the person, they are refused.

## Commands with input or output

A URL has no stdin or terminal to print into. WinMux refuses:

- Help (`--help` or `-h`), `subscribe`, every `list-*` command, `debug-windows`, `debug-lens-trace`, `doctor`, `config`, `place` (it only explains a placement), `reload-config --dry-run` and every `agent` subcommand.
- `workspace --stdin`, `move-node-to-workspace --stdin` and `lens --filter -`.
- `exec-and-forget`, as on the CLI.
- `trigger-binding` for a binding that runs `exec-and-forget` or another `trigger-binding`. A binding is otherwise a list of commands a URL could run itself.

All other commands use the same command runner as the CLI socket, including its disabled-server and first-run refusals. `enable on` can enable a disabled server. Incidental output from a successful command, such as `reload-config`, goes to the unified log at info level. Refusals and failed commands go to error level. Inspect them with:

```sh
log show --info --predicate 'subsystem == "com.zimengxiong.winmux" AND category == "url"'
```

Debug builds use subsystem `com.zimengxiong.winmux.debug`.

## Turn URL commands off

Set the top-level Bool `url-scheme = false` in the Nickel config. Its default is `true`. A saved config reload applies to the next URL; no app restart is needed. The bundle stays registered for the scheme, and logs a refusal naming `url-scheme` while it is off.

## Who can use it

Anything that can open a URL as you can run any command a URL allows. That reaches further than the CLI socket, which only programs already running as you can use (see [The CLI socket moves out of `/tmp`, and the docs say who can use it](https://github.com/prateek/winmux/issues/124)): a web page, an email or a chat message can hold a `winmux://` link, and a page can open one when you click. Browsers ask before opening another app's scheme, and some let you allow a site for good. WinMux adds no confirmation dialog. The worst a link can do is what the commands above can: switch workspaces, move, resize or close windows, change modes, reload the config or turn the server off. A link cannot name a shell command to run. The config's own hooks, such as `on-mode-changed`, still run after a command from a URL as they do after the same command from the CLI, so a hook that runs `exec-and-forget` runs its script.

Only open command links you trust. Turn `url-scheme` off if you do not use them.
