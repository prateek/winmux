# Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`

Part of {{UMBRELLA}}.

## What to build

WinMux's config becomes one Nickel file, `~/.config/winmux/winmux.ncl`, replacing TOML. A small Rust binary, `winmux-nickel`, evaluates it in a separate process that WinMux spawns and supervises: it returns the static settings as JSON at load and keeps the config's functions (Filters and Policy hooks) to answer calls over a pipe. This issue builds the helper, the Swift side that supervises it, config load at startup and on `reload-config`, and the `winmux config check`, `config convert` and `config status` commands.

## Decisions

**Config language**

- **Nickel replaces TOML.** The config is `~/.config/winmux/winmux.ncl`. WinMux no longer loads a TOML config. There is no CEL or other expression language.
- **Shipped library.** WinMux ships a Nickel file of contracts and defaults, and the user's config is checked against it. Contracts cover the config's shape and the return value of every Policy hook.
- **Functions.** Filters and Policy hooks are Nickel functions written in the config, in the form `fun w ctx => …`. Inline type annotations in a user's config are optional.
- **Named Filters.** Filters are named under a top-level `filters` record or written inline where one is used, and they call each other as functions. The `filters` record is part of this issue's library, so the Filter requests have something to call before Lenses exist.
- **Shapes carry over path for path.** The shapes decided during planning keep their paths and meaning in Nickel: `mode.<mode>.binding`, `lenses.<name>`, `when.<profile>`, and the Columns settings from `columns` through `workspace.<name>.columns.when.<profile>`. This issue's library covers the settings WinMux already has; the fork's additions are filled in by their own issues.
- **`when.<profile>` stays in the shape.** The `when.<profile>` override slot is accepted wherever it was decided. WinMux resolves it at runtime, not Nickel, so it arrives in the static JSON unresolved. The only profile is the implicit `"default"`.
- **Merge priorities are for layering files.** Nickel's `&`, `| default` and `| force` are how a user layers one config file over another. WinMux gives them no other meaning.
- **Editor support.** Nickel's language server (`nls`) and the official `nickel` CLI work on the config unchanged. WinMux does not define a Nickel dialect.

**The helper process**

- **WinMux never links Nickel.** `nickel-lang-core` leaks memory on almost every call that touches its stdlib (nickel-lang/nickel#1908), and dropping the engine frees nothing. All evaluation happens in `winmux-nickel`, which WinMux replaces to throw the leak away.
- **The helper owns the whole config.** At load it evaluates the file and returns the static part (gaps, bindings, Width presets, Lens records minus their functions, and every other non-function setting) as plain JSON. It keeps the functions for later calls. Static data and functions always come from the same evaluation.
- **Transport.** WinMux spawns the helper as a child process and talks JSON lines over its stdin and stdout: one request per line, one reply per line, a request id on every message. Not XPC.
- **One helper, strict FIFO.** One helper process serves all requests in order. No pool. All Nickel state lives on one thread (`NickelValue` is not `Send`).
- **How functions are held.** The helper keeps one `VmContext` for the loaded config and holds each function as a `Closure` (value plus environment), not a bare value. A call evaluates `Term::app(function, argument)` with `eval_full_closure`. Nothing is re-parsed per call. Holding only the value fails for functions wrapped by a function contract.
- **Typed marshalling.** WinMux sends plain JSON. The helper has a typed Rust struct per host record (`Window`, `App`, Filter context, Column). The struct knows which fields are Nickel enum tags and converts them, and it rejects a record with a missing field before any Nickel runs. This check is required: Nickel's contracts are lazy and do not catch a missing host field before the function body runs. Host values are built directly as Nickel values, with no Nickel source text generated.
- **One source for the records.** The Nickel contracts for these records and the Rust structs must come from one definition, because "Filter contract v1 and `config schema`" generates the contracts, the structs and the `config schema` output from the same source. Shape the marshalling so that issue can supply the definition without rewriting it.
- **Results and diagnostics.** A result is fully evaluated and walked back to JSON. An error reply carries Nickel's own diagnostic text, the same text the `nickel` CLI prints, including "did you mean" hints and contract blame. A failed call does not poison the helper; it keeps serving.
- **RSS in every reply.** Each reply reports the helper's resident memory.

**Requests**

- **Load.** Evaluates the config file, checks contracts, and runs the smoke run. On success it returns the static JSON plus the resolved list of imported files. On failure it returns the diagnostic.
- **Smoke run.** At load the helper calls every Filter and Policy hook against synthetic, fully populated records, so a typo such as `w.bundelId` fails at load, not at first use. Reading a missing field is an error in Nickel, so this catches typos in every branch the synthetic records take.
- **Filter, batched.** One request per Lens open: the Filter context plus all windows, answered with one match bit per window. The helper looks up the Filter and calls it once per window.
- **Policy hooks.** One request per `arrive`, `place` or `move-boundary` call. This issue builds the request and reply plumbing only.
- **`eval-filter`.** Evaluates a Filter given as text (a function body with `w` and `ctx` bound) in the loaded config's environment, so it can call named Filters. It is compiled per request and not cached.

**Supervision**

- **Startup.** WinMux waits for the first load before it starts managing windows, with a 2 s timeout. If the load fails or times out, WinMux runs on built-in defaults, the same as with no config file, and shows the diagnostic. No last-good config is cached on disk.
- **Recycling.** WinMux replaces the helper on every config reload and when its reported RSS passes 256 MB. The replacement is spawned, loads the config and passes the smoke run in the background. WinMux then swaps it in between requests and closes the old helper's stdin, which ends it.
- **Timeouts.** A Filter request gets 100 ms. A Policy hook request gets 50 ms. A request that times out means the helper is hung: WinMux kills it with SIGKILL and respawns it. Request ids keep a late reply from being matched to a newer request.
- **What callers get on failure.** A timed-out, failed or unanswerable request returns a failure with the diagnostic, never a stale result. Callers apply their own fallback: a Lens shows every window with a banner, and a Policy hook falls back to the built-in behaviour as if no hook were configured.
- **Crashes.** WinMux restarts a crashed helper with backoff: 1, 2, 4 s, capped at 30 s.
- **Circuit breaker.** After 3 crashes within a minute WinMux stops respawning, shows a notification, keeps the static config it has, and answers every request with the failure above. `reload-config` resets the breaker.

**`reload-config`**

- **Swap.** `reload-config` spawns a fresh helper, which loads the file, checks contracts and runs the smoke run. On success WinMux applies the static config and swaps helpers atomically. Requests in flight finish on the old helper.
- **Failure keeps the old config.** If the load fails, the old helper and config stay, a notification shows the error, and `reload-config` exits non-zero and prints the Nickel diagnostic.
- **Open Lens.** A Lens that is open during a reload keeps its already-filtered entries until it closes.

**CLI**

- **`winmux config status`** prints JSON: the helper's state (`ready`, `restarting` or `failed`), pid, RSS, recycle count, last error, and the loaded config path.
- **`winmux config check [<file>]`** loads the file and runs the smoke run without applying anything, and prints the diagnostic on failure.
- **`winmux config convert`** translates an existing `winmux.toml` to Nickel, once. The helper reads the TOML through Nickel's own `import` of `.toml` files; printing the result as Nickel source is code this issue writes. The AeroSpace config importer emits Nickel too.
- **One binary, three modes.** `winmux-nickel serve` is the JSON-lines loop. `winmux-nickel check <file>` and `winmux-nickel convert <file>` are one-shot. The `winmux` CLI execs the one-shot modes directly, so `config check` and `config convert` work when the WinMux server is not running.
- **Exit codes** for the new commands: 0 success, 1 runtime failure (server down, helper unavailable), 2 bad usage or a bad Filter.

**Build and signing**

- **Crate.** The helper is a Rust crate at `nickel-helper/` in this repo, built with `cargo build --release`. Rust becomes a build dependency (Rust 1.89 or later, edition 2024).
- **Dependency pin.** `nickel-lang-core` is pinned to `=0.19.0` with `default-features = false`, which drops the REPL, formatter, doc and markdown dependencies. The crate is 0.x and may break on minor releases. Upgrade deliberately with each Nickel CLI release, and only when the helper's calls and the smoke run still pass.
- **Location.** The binary ships at `WinMux.app/Contents/Helpers/winmux-nickel`. Dev builds find it through the `WINMUX_NICKEL_HELPER` environment variable, falling back to the path next to the running executable.
- **Signing.** The release build signs the helper with the app's identity. It needs no TCC grants.
- **Size.** About 15 MB stripped. It links the system `libiconv`.

## Not in this issue

- The field list of `Window`, `App`, Monitor, Filter context and Column, the `contract-version` integer, the smoke run's synthetic records (including the second pass with absent context windows), and `winmux config schema`: "Filter contract v1 and `config schema`". This issue builds the marshalling and smoke-run mechanism those definitions plug into.
- Reloading when the file is saved, the file watcher, and resetting the circuit breaker on a file change: "Config hot reload". This issue returns the list of imported files that the watcher needs.
- Lens records, the banner shown when a Filter fails, `lens --filter` and Search's `=` prefix: "Lens core and the `'list` Presentation with Search". This issue builds only the batched Filter request and `eval-filter`.
- What `arrive`, `place` and `move-boundary` receive, return and fall back to, and `place --dry-run`: "Column Policy hooks and Column commands".
- Width presets and the Columns settings: "Fixed Columns: slots, the count invariant, Width presets".
- The contents of the default config and the `config-reloaded` event on `subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events".
- Deferred: Tab provider `transform` and `focus` requests, gesture bindings, and Display profile matching.

## Depends on

Nothing.

## Open details

- How a user's config reaches the shipped contracts and defaults library: an import path the helper adds, a path the user writes, or the helper applying the contract itself. The spike used a stand-in file next to the config.
- How a batched Filter request names the function to call: a Filter name, a Lens name, or a path into the config.
- The wire names of the requests other than `eval-filter`, and the JSON field names of requests, replies and `config status`. Only the contents are decided.
- Where built-in defaults come from when the helper cannot load anything (missing binary, startup timeout, breaker open at startup). The defaults live in the shipped Nickel library, which needs the helper to evaluate.
- Whether the 256 MB recycle threshold is a config setting or a constant. It was decided as tunable, not where.
- Whether the first restart after a crash is immediate or waits 1 s. The decision reads "restarts at once with backoff (1, 2, 4 s, capped at 30 s)".
- How the `winmux` CLI finds `winmux-nickel` when it is installed outside the app bundle and the server is down. `WINMUX_NICKEL_HELPER` and "next to the executable" were decided for dev builds.
- `config check` with no file argument presumably checks the config path WinMux would load; the tickets do not say. The exit code for a file that fails the check is also not stated; the convention above suggests 2.
- Where `config convert` writes its output (stdout or a file) and what it takes as input when no path is given.
- What `config convert` emits for existing `[[on-window-detected]]` entries, and whether they keep working until `arrive` lands. The `arrive` hook replaces them, and its semantics belong to "Column Policy hooks and Column commands".
- How the settings WinMux already has are named in Nickel. `convert` implies each has a Nickel form; the natural reading is the same key names and nesting as the TOML.
- The existing config surface that the tickets do not mention: the `config --get`, `--all-keys`, `--major-keys` and `--config-path` flags, `reload-config --dry-run` and `--no-gui`, the server's `--config-path` argument, the `XDG_CONFIG_HOME` and dotfile search paths, the first-launch bootstrap that writes a starter config, and the Settings panes that edit the TOML file in place (`Sources/AppBundle/ui/settings/`). Settle which carry over, and whether the Settings panes become read-only, are removed, or write Nickel.
- Whether `TOMLKit` stays as a dependency once `convert` reads TOML through Nickel.
- `script/dogfood-release`, named in the decision as the script that signs the helper, is not on this branch. Add the signing step wherever the release build lives here (`makefile`, `project.yml`) and note it in the PR.

## Done when

- [ ] `cargo build --release` in `nickel-helper/` produces `winmux-nickel`, with `nickel-lang-core` pinned to `=0.19.0`.
- [ ] The release app contains `Contents/Helpers/winmux-nickel`, signed with the app's identity. A dev build finds the helper through `WINMUX_NICKEL_HELPER`.
- [ ] WinMux starts with a valid `~/.config/winmux/winmux.ncl`, applies its gaps and bindings, and `winmux config status` prints JSON with state `ready`, a pid, RSS, recycle count, last error and the loaded config path.
- [ ] WinMux does not link `nickel-lang-core`: the Swift package has no Nickel dependency.
- [ ] With a config that has a contract error, WinMux starts on built-in defaults and shows the Nickel diagnostic. The same happens when the helper does not answer within 2 s.
- [ ] A config whose Filter reads a misspelled field fails at load, and the diagnostic names the field and suggests the correct one.
- [ ] `winmux reload-config` with a valid change applies it and `config status` shows a new pid and a higher recycle count. With a broken file it exits non-zero, prints the diagnostic, shows a notification, and the old config and helper keep working.
- [ ] A batched Filter request for a Filter named under `filters`, with 50 windows, returns 50 match bits. A window record with a missing field is rejected by the helper with an error that names the field, before any Nickel runs.
- [ ] An `eval-filter` request whose body calls a Filter named under `filters` returns that Filter's result.
- [ ] A request for a Policy hook returns the hook's result as JSON, or a failure after 50 ms.
- [ ] A Filter that loops returns a failure after 100 ms, the helper is killed and respawned, and the next request succeeds.
- [ ] Killing the helper with `kill -9` brings up a new one; `config status` shows `restarting`, then `ready`.
- [ ] Killing it 3 times within a minute trips the breaker: a notification shows, `config status` reports `failed`, the static config stays applied, and `winmux reload-config` brings the helper back.
- [ ] Pushing the helper's RSS past the threshold replaces it without a failed or delayed request, and the recycle count goes up.
- [ ] `winmux config check <file>` exits 0 for a valid file and non-zero with the diagnostic for a broken one, with the WinMux server stopped.
- [ ] `winmux config convert` turns an existing `winmux.toml` into Nickel that passes `winmux config check`, with the WinMux server stopped.
- [ ] A 50-window Filter request takes about 2 ms and a `place` request about 0.2 ms from Swift on Apple silicon, in line with the spike.

## Sources

- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Task: Nickel binding spike](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/28-task-nickel-binding-spike.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md)
- [Nickel binding spike (prototype)](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/28-nickel-spike/README.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
