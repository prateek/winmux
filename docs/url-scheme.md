# Run a command from a URL

WinMux accepts `winmux://run/<arg>/<arg>/…`. Each path segment after `run` is one CLI argument. It is percent-decoded once, with no shell splitting or quoting rules.

```sh
open 'winmux://run/mode/window'
open 'winmux://run/lens/overview'
open 'winmux://run/workspace/2'
```

These run `winmux mode window`, `winmux lens overview` and `winmux workspace 2`. Encode a space as `%20`, a literal slash inside an argument as `%2F`, and a percent sign as `%25`. For example, `winmux://run/move-node-to-workspace/My%20Desk` passes `My Desk` as one argument. A plus sign stays a plus sign.

The scheme and `run` host are case-insensitive. User names, passwords, ports, queries, fragments, missing arguments, empty segments (including a trailing slash) and invalid UTF-8 escapes are refused. URLs run one at a time in arrival order. During ordinary startup they wait until WinMux is ready; while first-run setup waits for the person, they are refused.

## Commands with input or output

A URL has no stdin or terminal to print into. WinMux refuses:

- Help (`--help` or `-h`), `subscribe`, every `list-*` command, `debug-windows`, `debug-lens-trace`, `doctor`, `config` and every `agent` subcommand.
- `place --dry-run` and `place --json`. Plain `place` places the focused window; `column-count <count>` sets the count.
- `workspace --stdin`, `move-node-to-workspace --stdin` and `lens --filter -`.

All other commands use the same command runner as the CLI socket, including its disabled-server, first-run and `exec-and-forget` refusals. `enable on` can enable a disabled server. Incidental output from a successful command, such as `reload-config`, goes to the unified log at info level. Refusals and failed commands go to error level. Inspect them with:

```sh
log show --info --predicate 'subsystem == "com.zimengxiong.winmux" AND category == "url"'
```

Debug builds use subsystem `com.zimengxiong.winmux.debug`.

## Turn URL commands off

Set the top-level Bool `url-scheme = false` in the Nickel config. Its default is `true`. A saved config reload applies to the next URL; no app restart is needed. The bundle stays registered for the scheme, and logs a refusal naming `url-scheme` while it is off.

## Who can use it

Anything that can open a URL as you can run any command a URL allows, including a web page or a note whose link you click. Browsers usually ask before opening another app's scheme. WinMux adds no confirmation dialog. This has the same trust boundary as the CLI socket; see [The CLI socket moves out of `/tmp`, and the docs say who can use it](https://github.com/prateek/winmux/issues/124).

Only open command links you trust. Turn `url-scheme` off if you do not use them.
