# Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`

Part of {{UMBRELLA}}.

## What to build

WinMux's config becomes one Nickel file, `~/.config/winmux/winmux.ncl`, replacing TOML. A small Rust binary, `winmux-nickel`, evaluates it in a separate process that WinMux spawns and supervises: it returns the static settings as JSON at load and keeps the config's functions (Filters and Policy hooks) to answer calls over a pipe. This issue builds the helper, its request plumbing (load, the batched Filter request, `eval-filter`, the Policy hook requests and the smoke-run loop, tested against a stand-in record), the Swift side that supervises it, config load at startup and on `reload-config`, and the `winmux config check`, `config convert` and `config status` commands.

## Decisions

**Config language**

- **Nickel replaces TOML.** The config is `~/.config/winmux/winmux.ncl`. WinMux no longer loads a TOML config. There is no CEL or other expression language.
- **Shipped library.** WinMux ships two Nickel files in a directory named `winmux`: `winmux.ncl`, the contracts, and `defaults.ncl`, the defaults. Contracts cover the config's shape and the return value of every Policy hook. The helper adds the directory that holds `winmux/` to Nickel's import path, so a config imports them as `winmux/winmux.ncl` and `winmux/defaults.ncl` without copying anything.
- **The directory prefix is required.** Nickel looks for a relative import in the importing file's own directory before the import path (`nickel-lang-core` 0.19.0, `src/cache.rs`), and the user's config is itself named `winmux.ncl`. A bare `import "winmux.ncl"` in the config would import the config into itself.
- **The config applies the contract itself.** The user's file imports the contracts and applies them: `let W = import "winmux/winmux.ncl" in … | W.Config`. The helper does not apply a contract the file does not name.
- **Defaults are imported, not implied.** This issue introduces `defaults.ncl` and its import path, holding only what this issue's checks need. The user's config imports `defaults.ncl` and merges over it explicitly: `((import "winmux/defaults.ncl") & { … }) | W.Config`. Nothing is merged in behind the file's back, so every default is visible and any of them can be dropped. A config that leaves the import out is a total config and gets no defaults. `config convert` writes the import line, and so does the starter config.
- **Spelling.** Every field name and enum tag the fork adds to the config is spelled with hyphens, never underscores (`reload-on-save`, `move-boundary`, `'accessory-popup`), matching the keys inherited from upstream and the CLI. Nickel accepts hyphens inside identifiers, so `a-b` is one name and subtraction needs spaces.
- **Functions.** Filters and Policy hooks are Nickel functions written in the config. A Filter has the form `fun w ctx => …`. A Policy hook takes `w` and `ctx` and then further arguments, which "Column Policy hooks and Column commands" defines per hook. Inline type annotations in a user's config are optional.
- **Named Filters.** Filters are named under a top-level `filters` record or written inline where one is used, and they call each other as functions. The contract for a Filter and for the `filters` record comes from "Filter contract v1 and `config schema`".
- **Shapes carry over path for path.** The shapes decided during planning keep their paths and meaning in Nickel: `mode.<mode>.binding`, `lenses.<name>`, `when.<profile>`, and the Columns settings from `columns` through `workspace.<name>.columns.when.<profile>`. This issue's contracts cover the settings WinMux already has; the fork's additions are filled in by their own issues.
- **`when.<profile>` stays in the shape.** The `when.<profile>` override slot is accepted wherever it was decided. WinMux resolves it at runtime, not Nickel, so it arrives in the static JSON unresolved. The only profile is the implicit `"default"`.
- **Merge priorities are for layering files.** Nickel's `&`, `| default` and `| force` are how a user layers one config file over another, the shipped `defaults.ncl` included. WinMux gives them no other meaning.
- **Editor support.** Nickel's language server (`nls`) and the official `nickel` CLI work on the config. WinMux does not define a Nickel dialect.

**The helper process**

- **WinMux never links Nickel.** `nickel-lang-core` leaks memory on almost every call that touches its stdlib (nickel-lang/nickel#1908), and dropping the engine frees nothing. All evaluation happens in `winmux-nickel`, which WinMux replaces to throw the leak away.
- **The helper owns the whole config.** At load it evaluates the file and returns the static part (gaps, bindings, Width presets, Lens records minus their functions, and every other non-function setting) as plain JSON. It keeps the functions for later calls. Static data and functions always come from the same evaluation.
- **Transport.** WinMux spawns the helper as a child process and talks JSON lines over its stdin and stdout: one request per line, one reply per line, a request id on every message. Not XPC.
- **One helper, strict FIFO.** One helper process serves all requests in order. No pool. All Nickel state lives on one thread (`NickelValue` is not `Send`).
- **How functions are held.** The helper keeps one `VmContext` for the loaded config and holds each function as a `Closure` (value plus environment), not a bare value. A call evaluates `Term::app(function, argument)` with `eval_full_closure`. Nothing is re-parsed per call. Holding only the value fails for functions wrapped by a function contract.
- **Typed marshalling.** WinMux sends plain JSON. The helper turns each host record into a Nickel value through a typed Rust struct. The struct knows which fields are Nickel enum tags and converts them, and it rejects a record with a missing field before any Nickel runs. This check is required: Nickel's contracts are lazy and do not catch a missing host field before the function body runs. Host values are built directly as Nickel values, with no Nickel source text generated.
- **Stand-in record.** This issue builds the marshalling, the requests and the smoke-run loop, and tests them against one small stand-in record that has a String field, a Bool field, an enum-tag field and a nested record. The real records (Window, App, Monitor, Filter context, Column), their Nickel contracts and the synthetic values the smoke run passes come from "Filter contract v1 and `config schema`", which generates the contracts, the structs and the `config schema` output from one definition. Shape the marshalling so that issue can supply the definition without rewriting it.
- **Results and diagnostics.** A result is fully evaluated and walked back to JSON. An error reply carries Nickel's own diagnostic text, the same text the `nickel` CLI prints, including "did you mean" hints and contract blame. A failed call does not poison the helper; it keeps serving.
- **RSS in every reply.** Each reply reports the helper's resident memory.

**Requests**

- **Load.** Evaluates the config file, checks contracts, and runs the smoke run. On success it returns the static JSON plus the resolved list of imported files. On failure it returns the diagnostic.
- **Smoke-run loop.** At load the helper calls every Filter and Policy hook in the config against synthetic, fully populated arguments, and any error fails the load. A typo such as `w.bundelId` therefore fails at load, not at first use, because reading a missing field is an error in Nickel. The loop takes its synthetic arguments as data: a list of argument sets per kind of function, each run as one pass. This issue runs it with one pass of stand-in values. "Filter contract v1 and `config schema`" supplies the real values and the two passes (context windows set, then `null`).
- **Filter, batched.** One request per Lens open: the Filter context plus all windows, answered with one match bit per window. The request names the Lens. The helper looks up `lenses.<name>.filter` and calls it once per window. The Lens record itself is defined by "Lens core and the `'list` Presentation with Search"; this issue's tests use a stand-in config whose `lenses.<name>` records hold only a `filter`.
- **Policy hooks.** One request per `arrive`, `place` or `move-boundary` call. The request names the hook and carries its arguments as a JSON list, since hooks differ in how many they take. This issue builds the request and reply plumbing only.
- **`eval-filter`.** Evaluates a Filter given as text (a function body with `w` and `ctx` bound) in the loaded config's environment, so it can call named Filters. It is compiled per request and not cached.

**Supervision**

- **Startup.** WinMux waits for the first load before it starts managing windows, with a 2 s timeout. If the load fails or times out, WinMux runs on built-in defaults, the same as with no config file, and shows the diagnostic. No last-good config is cached on disk.
- **Recycling.** WinMux replaces the helper on every config reload and when its reported RSS passes 256 MB. The replacement is spawned, loads the config and passes the smoke run in the background. WinMux then swaps it in between requests and closes the old helper's stdin, which ends it.
- **Timeouts.** A Filter request gets 100 ms. A Policy hook request gets 50 ms. A request that times out means the helper is hung: WinMux kills it with SIGKILL and respawns it. Request ids keep a late reply from being matched to a newer request.
- **What callers get on failure.** A timed-out, failed or unanswerable request returns a failure with the diagnostic, never a stale result. Callers apply their own fallback: a Lens shows every window with a banner, and a Policy hook falls back to the built-in behaviour as if no hook were configured.
- **Crashes.** WinMux restarts a crashed helper at once. If the helper crashes again, the next restarts wait 1, 2 and 4 s, doubling up to a cap of 30 s.
- **Circuit breaker.** After 3 crashes within a minute WinMux stops respawning, shows a notification, keeps the static config it has, and answers every request with the failure above. `reload-config` resets the breaker.

**`reload-config`**

- **Swap.** `reload-config` spawns a fresh helper, which loads the file, checks contracts and runs the smoke run. On success WinMux applies the static config and swaps helpers atomically. Requests in flight finish on the old helper.
- **Failure keeps the old config.** If the load fails, the old helper and config stay, a notification shows the error, and `reload-config` exits non-zero and prints the Nickel diagnostic.
- **Open Lens.** A Lens that is open during a reload keeps its already-filtered entries until it closes.

**CLI**

- **`winmux config status`** prints JSON: the helper's state (`ready`, `restarting` or `failed`), pid, RSS, recycle count, last error, and the loaded config path.
- **`winmux config check [<file>]`** loads the file and runs the smoke run without applying anything, and prints the diagnostic on failure. The file argument is optional.
- **`winmux config convert`** translates an existing `winmux.toml` to Nickel, once. The helper reads the TOML through Nickel's own `import` of `.toml` files; printing the result as Nickel source is code this issue writes. The output imports `winmux/winmux.ncl` and `winmux/defaults.ncl`, merges the converted settings over the defaults and applies `W.Config`. The AeroSpace config importer emits Nickel too.
- **One binary, two modes.** `winmux-nickel serve` is the JSON-lines loop. `winmux-nickel check <file>` and `winmux-nickel convert <file>` are the one-shot mode. The `winmux` CLI execs the one-shot commands directly, so `config check` and `config convert` work when the WinMux server is not running.
- **Exit codes** for the new commands: 0 success, 1 runtime failure (server down, helper unavailable), 2 bad usage or a bad Filter.

**Settings UI**

- **Settings panes are read-only in the first version.** The panes under `Sources/AppBundle/ui/settings/` that write keys and bindings back into the config file (the toggles in `ConfigSettingsViews.swift`, the shortcut recorder and the advanced shortcut editor) show the loaded values and cannot change them. Each pane has an "Open config" button that opens the config file in the user's editor. WinMux does not patch a Nickel file.
- **Sidebar edits go to a state file, not the config.** Renaming a workspace or a project and setting a project's colour in the sidebar write `[workspace-sidebar]` keys into the TOML today (`Sources/AppBundle/ui/sidebar/WorkspaceSidebarConfigEdits.swift`, called from `Sources/AppBundle/tree/WorkspaceProjects.swift` and `Sources/AppBundle/ui/sidebar/WorkspaceSidebarActions.swift`). They keep working: WinMux writes them to a state file it owns. The config declares the starting names and colours, and a value in the state file overrides the config's value for the same workspace or project. Nothing in WinMux writes to the config file.

**Build and signing**

- **Crate.** The helper is a Rust crate at `nickel-helper/` in this repo, built with `cargo build --release`. Rust becomes a build dependency (Rust 1.89 or later, edition 2024).
- **Dependency pin.** `nickel-lang-core` is pinned to `=0.19.0` with `default-features = false`, which drops the REPL, formatter, doc and markdown dependencies. The crate is 0.x and may break on minor releases. Upgrade deliberately with each Nickel CLI release, and only when the helper's calls and the smoke run still pass.
- **Location.** The binary ships at `WinMux.app/Contents/Helpers/winmux-nickel`. Dev builds find it through the `WINMUX_NICKEL_HELPER` environment variable, falling back to the path next to the running executable.
- **Signing.** The release build signs the helper with the app's identity. It needs no TCC grants.
- **Size.** About 15 MB stripped. It links the system `libiconv`.

## Not in this issue

- The definitions of the Window, App, Monitor, Filter context and Column records, their Nickel contracts and Rust structs, the contract for a Filter and the `filters` record, the smoke run's synthetic values and its two passes, the `contract-version` integer, and `winmux config schema`: "Filter contract v1 and `config schema`". This issue builds the requests, the marshalling and the smoke-run loop those definitions plug into, and tests them with a stand-in record.
- Reloading when the file is saved, the file watcher, and resetting the circuit breaker on a file change: "Config hot reload". This issue returns the list of imported files that the watcher needs.
- Lens records, the banner shown when a Filter fails, `lens --filter` and Search's `=` prefix: "Lens core and the `'list` Presentation with Search".
- What `arrive`, `place` and `move-boundary` receive, return and fall back to, and `place --dry-run`: "Column Policy hooks and Column commands".
- Width presets and the Columns settings: "Fixed Columns: slots, the count invariant, Width presets".
- The default Lenses, their Triggers and the `lens` mode in `defaults.ncl`, and the `config-reloaded` event on `subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events". This issue already carries upstream's settings and bindings over into `defaults.ncl` (see the defaults below).
- Deferred: Tab provider `transform` and `focus` requests, gesture bindings, and Display profile matching.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Where the sidebar state file lives.** `$XDG_STATE_HOME/winmux/sidebar.json`, falling back to `~/.local/state/winmux/sidebar.json`. A missing or unreadable file means no overrides. Deleting it returns every name and colour to what the config declares.
- **Wire names.** The requests are `load`, `filter`, `hook` and `eval-filter`. A reply is `{id, ok, result, rss}` on success and `{id, ok, error, rss}` on failure. `config status` prints the keys `state`, `pid`, `rss`, `recycles`, `last-error` and `config-path`.
- **Where the library ships.** `WinMux.app/Contents/Resources/nickel/winmux/`, with `Contents/Resources/nickel` on the import path. A dev build reads the same files from the `nickel-helper/` crate. `nls` and the `nickel` CLI find them when `NICKEL_IMPORT_PATH` is set to that directory, and the starter config says so in a comment.
- **Built-in defaults.** `resources/default-config.json` is the static JSON of `defaults.ncl`. It is checked in, `make default-config` regenerates it, and a helper test fails when it is out of date; a build step would have needed the helper before every `swift build`. WinMux applies that JSON when no helper can load anything: a missing binary, a failed or timed-out first load, or the breaker open at startup. With no config file and a working helper, the helper loads `defaults.ncl` as the config, so the default functions are live.
- **What `defaults.ncl` holds.** Upstream's settings and bindings, every value marked `| default`, generated from upstream's `default-config.toml` with `convert`. Without them a WinMux with no config file has no bindings. `resources/default-config.toml` is gone; a copy stays as a helper test fixture.
- **How the settings reach the Swift parser.** The parser was written against TOMLKit types (about 54 functions). The static JSON is turned into a `TOMLTable` and handed to it unchanged, so the parser and its tests stay. `Config`'s contracts check shape and scalar types; values with a syntax of their own (commands, key names, monitor patterns) are still checked by the Swift parser, whose errors are shown the same way as a Nickel diagnostic.
- **Recycle threshold.** 256 MB is a constant in the Swift supervisor, not a config setting.
- **How the CLI finds the helper.** `WINMUX_NICKEL_HELPER`, then next to the `winmux` executable, then inside the app bundle that LaunchServices returns for WinMux's bundle id.
- **`config check` with no argument.** It checks the file WinMux would load. A file that fails the check exits 2.
- **`config convert` input and output.** It prints Nickel to stdout. With no path it reads the TOML file WinMux would have loaded, using the existing search order in `Sources/AppBundle/config/ConfigFile.swift`.
- **`[[on-window-detected]]` in `convert`.** Each entry becomes a commented-out `arrive` branch in the output, and `convert` prints a warning on stderr that names it. `on-window-detected` is not a key of `W.Config`, so these rules do nothing until "Column Policy hooks and Column commands" lands. Upstream's default config has none, so only a user's own rules are affected.
- **Bindings in `convert`.** A TOML config replaced the default bindings wholesale. Merging over `defaults.ncl` would add the default bindings back, so when the TOML defines `mode`, the output merges over `std.record.remove "mode" defaults` and says so in a comment.
- **Keys `convert` does not translate.** Deprecated TOML keys (`after-login-command`, `use-liquid-glass` and the like) are printed as they are and then fail `config check` with Nickel's diagnostic.
- **Names of the settings WinMux already has.** The same keys and nesting as the TOML: `gaps`, `workspace-sidebar`, `mode.main.binding` and so on.
- **Existing `config` and `reload-config` flags.** `config --get`, `--all-keys`, `--major-keys` and `--config-path`, and `reload-config --dry-run` and `--no-gui`, keep working and read the static JSON. The server's `--config-path` argument keeps working and names a Nickel file.
- **Search paths and the starter config.** The existing search order carries over with `.ncl` in place of `.toml`, `XDG_CONFIG_HOME` included. The first-launch bootstrap writes its starter config as Nickel.
- **`TOMLKit`.** It stays as a dependency while the AeroSpace importer in Swift parses TOML with it, and goes when that importer moves into the helper.
- **Where the signing step goes.** A post-build script in `project.yml` builds the helper with cargo, copies it to `Contents/Helpers` and signs it with the app's identity before Xcode seals the bundle. "Dogfood releases" verifies the signature under the dogfood identity.
- **What `eval-filter` can see.** `w`, `ctx` and `filters`, the config's named Filters. The text is compiled as its own source that imports the loaded config, so a `let` at the top of the config file is not in scope.
- **Hook arguments.** Until "Column Policy hooks and Column commands" defines them, the helper knows `arrive`, `columns.place` and `columns.move-boundary`, each taking a Window and a Filter context. `W.Config` does not accept the hooks yet.
- **A hung helper and the breaker.** A helper killed for a timeout is respawned at once and is not counted as a crash. The restart delays start over once the helper has stayed up for five minutes. A load gets the same 2 s at reload as at startup.
- **Notifications.** The breaker and a failed load use WinMux's existing message window, the one config errors already used.
- **Removing a name in the sidebar.** Resetting a name or colour removes the override from the state file. It cannot hide a name the config declares.
- **`config check` and `convert` with no file.** The CLI uses the default locations and does not know a `--config-path` the server was started with. With no config file, `check` checks the shipped defaults.
- **Settings panes.** The Configuration pane shows the file's text and cannot edit it. The unused `ShortcutGeneralView` is deleted with the writers it called.
- **Licences.** `nickel-lang-core` depends on `malachite`, which is LGPL-3.0, and the helper links it statically. `legal/README.md` records it.
- **Latency limits.** From Swift on Apple silicon, a 50-window Filter request that takes more than 10 ms fails the check, and so does a `place`-sized hook request that takes more than 2 ms. The spike measured about 2 ms and 0.2 ms.

## Done when

- [x] `cargo build --release` in `nickel-helper/` produces `winmux-nickel`, with `nickel-lang-core` pinned to `=0.19.0`.
- [x] The release app contains `Contents/Helpers/winmux-nickel`, signed with the app's identity. A dev build finds the helper through `WINMUX_NICKEL_HELPER`.
- [ ] WinMux starts with a valid `~/.config/winmux/winmux.ncl`, applies its gaps and bindings, and `winmux config status` prints JSON with state `ready`, a pid, RSS, recycle count, last error and the loaded config path. Not yet checked: needs a running WinMux.
- [x] WinMux does not link `nickel-lang-core`: the Swift package has no Nickel dependency.
- [x] A config that imports `winmux/winmux.ncl` and `winmux/defaults.ncl` loads from `~/.config/winmux/winmux.ncl` with no copy of either file beside it. A setting the config leaves out has its value from `defaults.ncl`, and a config without the `defaults.ncl` import gets no defaults.
- [x] A config that sets a key the contracts do not know fails to load with Nickel's diagnostic.
- [ ] With a config that has a contract error, WinMux starts on built-in defaults and shows the Nickel diagnostic. The same happens when the helper does not answer within 2 s. Not yet checked in a running WinMux; the load failure and the 2 s timeout are covered by supervisor tests.
- [x] In a helper test, a Filter that reads a misspelled field of the stand-in record fails the load in the smoke run, and the diagnostic names the field and suggests the correct one.
- [ ] `winmux reload-config` with a valid change applies it and `config status` shows a new pid and a higher recycle count. With a broken file it exits non-zero, prints the diagnostic, shows a notification, and the old config and helper keep working. Not yet checked in a running WinMux; the swap and the kept helper are covered by supervisor tests.
- [x] In a helper test, a batched Filter request that names a Lens of the stand-in config and carries 50 stand-in records returns 50 match bits.
- [x] In a helper test, a stand-in record with a missing field is rejected with an error that names the field, before any Nickel runs, and a JSON string in the enum-tag field reaches Nickel as an enum tag.
- [x] In a helper test, an `eval-filter` request whose body calls a Filter named under `filters` returns that Filter's result.
- [x] A request for a Policy hook returns the hook's result as JSON, or a failure after 50 ms.
- [x] A Filter that loops returns a failure after 100 ms, the helper is killed and respawned, and the next request succeeds.
- [ ] Killing the helper with `kill -9` brings up a new one at once; `config status` shows `restarting`, then `ready`. After a second kill the restart waits 1 s. Covered by a supervisor test; not yet observed through `config status`.
- [ ] Killing it 3 times within a minute trips the breaker: a notification shows, `config status` reports `failed`, the static config stays applied, and `winmux reload-config` brings the helper back. Covered by a supervisor test; not yet observed in a running WinMux.
- [x] Pushing the helper's RSS past the threshold replaces it without a failed or delayed request, and the recycle count goes up.
- [x] `winmux config check <file>` exits 0 for a valid file and exits 2 with the diagnostic for a broken one, with the WinMux server stopped. With no argument it checks the file WinMux would load.
- [x] `winmux config convert` turns an existing `winmux.toml` into Nickel on stdout, with the WinMux server stopped. The output imports `winmux/defaults.ncl`, applies `W.Config` and passes `winmux config check`. A `[[on-window-detected]]` entry comes out as a commented-out `arrive` branch with a warning on stderr.
- [ ] `winmux config --get`, `--all-keys`, `--major-keys` and `--config-path`, and `winmux reload-config --dry-run`, work against a Nickel config. Not yet checked: needs a running WinMux.
- [x] On first launch with no config file, WinMux writes a Nickel starter config that passes `winmux config check`.
- [ ] The Settings panes show the loaded values, offer an "Open config" button that opens the config file, and never write to the file. Not yet checked: needs a running WinMux.
- [ ] Renaming a workspace, renaming a project and changing a project's colour in the sidebar still work and survive a restart. The config file is byte-for-byte unchanged afterwards, and deleting the state file restores the names and colours the config declares. Not yet checked in a running WinMux; the state file and its override are covered by tests.
- [x] From Swift on Apple silicon, a 50-window Filter request takes no more than 10 ms and a hook request no more than 2 ms.

## Sources

- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Task: Nickel binding spike](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/28-task-nickel-binding-spike.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md)
- [Nickel binding spike (prototype)](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/28-nickel-spike/README.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
