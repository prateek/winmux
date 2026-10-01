# Grilling: CLI surface for the fork's features

Type: grilling
Status: resolved
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

## Answer

Resolved 2026-09-30 with Prateek. Display profile and tab commands are left to their deferred efforts.

**Lenses and Filters**

- `lens <name> [--search '<text>'] [--presentation list|strip|miniatures]` opens a configured Lens.
- `lens --filter <name|body> [--presentation …] [--sort mru,…]` opens an ad-hoc Lens.
- `list-lenses [--json]`, `summon [--window-id <id>]`, and `palette` as an alias for `lens search`.
- `list-windows` gains `--lens <name>`, `--filter <name|body>` and `--search '<text>'`. JSON output adds `score` and the matched field when `--search` is given.
- **Writing an inline Filter.** `--filter` takes a Filter name or a function body with `w` and `ctx` bound. A bare identifier that matches a named Filter is the name; anything else is a body. Nickel enum tags start with `'`, so the docs show double quotes (`--filter "w.class == 'floating"`), and `--filter -` reads the body from stdin for anything containing strings.

**Config**

- `config status` (JSON), `config check [<file>]` and `config convert`, as the evaluator ticket decided.
- `config schema [--json]` prints the Filter contract (see [Grilling: the Filter contract's final field list](33-grilling-filter-contract-field-list.md)).

**Columns**

- `focus-column <n>`, `move-node-to-column <n>`, `column-width next|prev|<fraction>`, `compact`, `list-columns [--json]` (index, width, empty, window ids).
- `column-count <n>|off` overrides the count at runtime until the next config reload.
- `place --dry-run --window-id <id>` explains which hook result a window would get. It replaces the `columns place --dry-run --window <id>` proposed in the Columns ticket.

**Conventions**

- **Failure in a script.** A Filter that fails or times out in a non-interactive command prints nothing on stdout and the Nickel diagnostic on stderr. This is the opposite of the interactive Lens, which shows every window with a banner: a script must never act on "all windows" by accident.
- **Exit codes** for the new commands: 0 success, 1 runtime failure (server down, helper unavailable), 2 bad usage or a bad Filter.
- Every new `list-*` command takes `--json`. Flags follow the existing names (`--window-id`).
- **Events on `subscribe`**, added to the existing six: `config-reloaded` (ok, or the error), `lens-opened` and `lens-closed` (with the Lens name), and `columns-changed` (count, widths or occupancy on the focused workspace).
