# Grilling: CLI surface for the fork's features

Type: grilling
Status: open
Blocked by: 07, 09

## Question

Already settled by [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md): `lens <name> --search`, `lens --presentation list`, `list-windows --lens <name> --search '<text>'` (JSON adds `score` and the matched field), and `palette` as an alias for `lens search`. The Search box's inline Nickel is a function body with `w` and `ctx` bound after a leading `=`; keep `--filter` consistent with it.

Also settled, by [Grilling: tab provider interface](24-grilling-tab-provider-interface.md): `list-tabs [--window-id N] [--refresh] [--json]`, `set-tabs --app-id --pid` (document on stdin), `focus-tab --window-id N --tab-id ID` and `list-tab-providers [--json]`.

Also settled, by [Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md): `config status` (JSON: the helper's state, pid, RSS, recycle count, last error, loaded config path), and `config check <file>` and `config convert`, which exec the `winmux-nickel` helper's one-shot modes and so work with the server down. `--filter '<expr>'` and Search's `=` go through the server to the helper's `eval-filter` request. A Filter that fails or times out shows every window; decide here how the non-interactive commands report that (exit code and stderr).

Which `winmux` subcommands, flags and output formats do the fork's features need so users can drive everything from scripts? WinMux already has the AeroSpace-style command set (moving windows, workspaces, layouts, `list-windows --format`, `--json`, `subscribe`). Decide the additions and their shape:

- Lenses: open a Lens or an ad-hoc Filter and Presentation from the CLI, and run a Filter non-interactively (`winmux list-windows --filter '<nickel|name>'`), including how Nickel diagnostics are reported on stderr and in exit codes. Filters are Nickel since [Prototype: config and scripting language](27-prototype-config-language.md); decide how an inline Filter is written on the command line, given that Nickel enum tags (`'minimized`) collide with zsh single quotes. The candidate is to pass only the function body with `w` and `ctx` bound.
- Filters: validate a Filter or the whole config without applying it, and list the Filter attribute schema (types and descriptions from WinMux's Nickel contracts). Also `winmux config convert` (TOML to Nickel).
- Columns: set the Column count, cycle a Width preset, move a window to Column N, and query Column state.
- Display profiles are deferred (2026-09-30), so their subcommands (show the active profile, force-apply one, subscribe to `displayProfileChanged`) are left for that later effort.
- Conventions across all of them: naming consistent with existing commands, `--json` everywhere, stable window ids, and events on `winmux subscribe` for scripts that react rather than poll.

Already fixed by [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md): `winmux lens <name>`, `winmux lens --filter '<filter|name>' [--presentation grid|strip] [--sort mru,…]` for an ad-hoc Lens, `winmux list-lenses [--json]`, and a `summon [--window-id]` command.
