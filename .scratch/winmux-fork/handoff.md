# Handoff: building the WinMux fork foundation

Planning is finished and the build is under way: the deployment target, Nickel config, dogfood release, Filter contract, Global MRU and config hot reload issues have landed on `fork`, on top of upstream `v0.5.6`, and `0.5.6-dogfood.1` is published. Lens core, the list and Accessory window defaults have landed too; the shipped `floating` Lens reaches floating windows across workspaces. This note orients an agent that is about to build. It holds only what the issues, the map and the code don't. Last updated 2026-10-03.

## Start here

- **The work:** the umbrella issue [Fork foundation: Nickel config, Lenses, fixed Columns and the CLI](https://github.com/prateek/winmux/issues/1) and its thirteen child issues on `prateek/winmux`, linked as sub-issues with blocked-by dependencies. Each child is one buildable slice and stands alone. Build in dependency order; the Lens issues and the Column issues are independent of each other once the Nickel config lands.
- **Done:** [Raise the deployment target to macOS 26](https://github.com/prateek/winmux/issues/2), landed as `9aac8be2`. The issue stays open for one check that needs an installed build: the double-sided flip animating.
- **Done, with checks left:** [Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`](https://github.com/prateek/winmux/issues/3). A debug build was run on scratch config and state directories and passed the startup, reload, kill and breaker checks. Two Done-when items are left, both needing someone at the screen: the Settings panes, and sidebar renames surviving a restart.
- **Done, with checks left:** [Dogfood releases: cut a signed build from `fork` and install it through the tap](https://github.com/prateek/winmux/issues/14). `0.5.6-dogfood.1` is published and the cask points at it. Nobody has installed it yet, so the issue's install, upgrade and Sparkle checks are open. The by-eye checks of the two issues above were done in a debug build, with the recording on pull request #15 and the screenshots on #16.
- **Done:** [Filter contract v1 and `config schema`](https://github.com/prateek/winmux/issues/5). Lenses and the Lens flags on `list-windows` now call Filters. The records were checked in tests against the real helper and on live windows in a debug build, with the recording on pull request #21.
- **Done:** [Global MRU (`lastFocusedSeq`)](https://github.com/prateek/winmux/issues/6). Lenses now sort by it; `list-windows --format '%{window-last-focused-seq}'` prints it. A debug build showed it on live windows (pull request #23); a screen lock and a native fullscreen Space were covered only by tests.
- **Done:** [Config hot reload](https://github.com/prateek/winmux/issues/4). A debug build showed a save reloading the config and a file it imports, the error notification and its dedupe, the mode staying active, the breaker, `reload-on-save = false` and the Settings toggle, with the recordings on pull request #24. A newly added import, a config file created after startup and a burst of writes were checked in tests only.
- **Done:** [Lens core and the `'list` Presentation with Search](https://github.com/prateek/winmux/issues/7). A debug build on scratch config showed the list, Search, inline Nickel, marks, Summon, the mouse and the CLI, with the captures on pull request #26. A Lens over a native fullscreen Space was not tried, and the debounce and display deadline were checked in tests only. The Accessory defaults live run subsequently checked an `'accessory-popup` row, Enter raising it and shift-enter refusing to Summon it.
- **Done:** [Accessory window defaults and the `floating` Lens](https://github.com/prateek/winmux/issues/10). Bundle identity supplies the floating default; live activation policy supplies Filter records and popup classes. The debug live run used owned neutral Accessory and Dock apps and checked both popup gates, popup Enter and shift-enter, floating Focus and Summon across workspaces, and live policy changes. A real browser autofill dropdown was represented by a controlled Dock-app popup rather than opened in a browser.
- **Next:** [Thumbnail cache and the `'miniatures` Presentation](https://github.com/prateek/winmux/issues/9) and [Fixed Columns](https://github.com/prateek/winmux/issues/11) are unblocked.
- **Glossary:** `CONTEXT.md` at the repo root. Use its terms and avoid the words it lists under _Avoid_.
- **ADR:** `docs/adr/0001-nickel-helper-process.md`.

## How to read an issue

- **Decisions** are settled. Don't reopen them; if the code makes one impossible, stop and tell Prateek.
- **Defaults chosen for you** are starting points no ticket settled. Change one if the code argues for it, and say so in the pull request.
- **Open details** remain in one issue only, the strip. Both can only be answered by running a build.
- When an issue and a ticket disagree, the issue is right. The issues apply later amendments.
- If an issue body needs correcting, edit the draft in `.scratch/winmux-fork/build/` and update the issue from it, so the two stay the same. The drafts use `{{UMBRELLA}}` and `{{CHILDREN}}` placeholders for the issue numbers.
- **How far to trust the issues.** They were drafted by agents from the tickets, reviewed once against the tickets and the code, then patched. The review's three errors and the gaps it found were fixed, and the issues were checked against each other for names, key defaults and import paths. Nobody has re-read all twelve end to end since the patch. Treat a claim about existing code (a file path, a function name, a current default) as probably right, and check it before building on it.

## Where the reasoning lives

Read these only when an issue's reasoning isn't enough.

- `.scratch/winmux-fork/map.md`: every decision in one line, in the order made, with links.
- `.scratch/winmux-fork/issues/`: the 35 decision tickets, each resolved or marked out of scope.
- `.scratch/winmux-fork/research/` and `prototypes/`: evidence and throwaway code. `prototypes/28-nickel-spike/` is the working Swift-to-Nickel spike the helper grows from.
- `.scratch/winmux-fork/build/review.md`: the review of the issues against the tickets and code, with the source for every default.

## Not being built

Tabs, trackpad gestures, Display profiles, the `'grid` Presentation and proactive registration of Accessory apps are deferred. The config keeps a `when.<profile>` slot with one implicit profile, `"default"`.

## Open with Prateek

- **Landing.** `AGENTS.md` at the repo root has the process: a pull request against `fork`, with screenshots or video of anything visible, squash-merged after CI and Prateek's review. The first build issue went straight onto `fork` before this was the rule.
- **Running a release.** Ask before each run; see `AGENTS.md`.
- **Decisions belong to him.** For a discrete choice, ask with a recommended answer first; he usually takes it. Don't settle a product question for him, and don't reopen one he has settled.

## Repo setup

- **The build lands on the `fork` branch.** It is the default branch of `prateek/winmux` and Orca's default worktree base (`fork/fork`). It holds the planning files, `CONTEXT.md` and the ADR. `main` only mirrors upstream `main`; don't build on it. The branch was called `wayfind-fork` until 2026-10-01, and GitHub redirects the old name.
- This checkout is a worktree on the local branch `fork`, tracking `fork/fork` (the remote is also named `fork`). The worktree directory is still named `wayfind-fork`. Its base is upstream `main` at `470eedb`, which is tag `v0.5.6`.
- Remotes: `origin` is upstream `ZimengXiong/winmux` (HTTPS), `fork` is `prateek/winmux` (SSH), `aerospace` is AeroSpace.
- Push over SSH. The `gh` HTTPS token lacks `workflow` scope, and GitHub rejects any push that brings upstream `.github/workflows/*` changes into the fork.
- `prateek/winmux` is public, so keep usernames, home paths, hardware serials and machine names out of issues and committed files.
- Build with `swift build`; the `Makefile` has the packaging targets. `swift build -c release --product winmux` builds the CLI alone.
- Ignored and large: `.build/` (about 390 MB) and `prototypes/28-nickel-spike/target/` (about 1 GB). Both are caches and safe to delete.

## The machine this was planned on

- A Mac mini with one virtual display and no trackpad, not Prateek's laptop. Check `sysctl -n hw.model` and the display list before relying on anything measured here.
- It has upstream WinMux 0.5.6 from the `ZimengXiong/homebrew` cask on the bundled default config, not Prateek's earlier dogfood build. His old config is kept at `~/.config/winmux.dogfood-backup-20260930`.
- The upstream cask ships no CLI, so `/opt/homebrew/bin/winmux` is a copy built from `v0.5.6`. It warns about a client/server version mismatch and works. A build from this repo will replace both.
- Ghost Pepper 2.4.4 is installed from the upstream cask; it was the test app for Accessory windows.
- Neither WinMux nor Ghost Pepper was running when planning ended. Starting WinMux re-tiles the windows on the session, so ask first.

## Things not captured elsewhere

- **Prior art.** The `codex-columns` branch of the fork (153 commits: columnar zones, scenes, rules, an overview) overlaps the Column issues. Prateek chose upstream `main` as the base anyway. Mine it; don't build on it.
- **A possible dotfiles bug, outside this work.** `g95nc`'s `discard` step appears to wipe BetterDisplay's "associate with display" setting; the evidence is in `research/05-*`. Mention it to Prateek; don't fix it here.
- **Research limits.** The first research agents had no web fetch. Apple API facts come from SDK headers, and each findings file flags its own unverified points.
- **Window capture.** `WindowScreenshot` in `Sources/AppBundle/util/` wraps the one-shot ScreenCaptureKit call and caches the `SCWindow` list, refetching only when a window id is missing. The thumbnail issue builds its cache on it. The capture's default size is the window's size in points, so callers pass a pixel size.
- **Deprecation warnings.** The macOS 26 target surfaces about 30 that were left alone: `onChange(of:perform:)`, `CVDisplayLink` and `activateIgnoringOtherApps`. Only code in `Sources/WinMuxApp` fails the Release build on a warning.
- **Working on the Nickel config.**
  - `make helper` builds `winmux-nickel`; `make check` builds it and runs its tests before the Swift ones. A debug build of WinMux and the Swift tests find it in `nickel-helper/target/`, release before debug, or through `WINMUX_NICKEL_HELPER`. Swift tests that need it skip when it is missing.
  - After changing `nickel-helper/nickel/winmux/defaults.ncl`, run `make default-config`. A helper test fails while `resources/default-config.json` is out of date.
  - `nickel-helper/src/records.rs` is the one definition of the Filter contract's records. After changing a record, run `make contract`; a helper test fails while `nickel/winmux/contract.ncl` is out of date. A field's doc comment is its description in `config schema`. The hook argument table in the same file is still a stand-in, which the Column hooks issue replaces.
  - `Sources/AppBundle/nickel/ContractRecords.swift` builds the same records from live windows. A Swift test compares its field names with `config schema --json`, so a field added on one side fails until the other has it.
  - `winmux debug-windows --window-id <id>` prints the window's record as `WinMux.windowRecord`, and with `--filter-context` the current Filter context as `WinMux.filterContext`. It is the way to see a record in a running build until a Lens exists.
  - `MacApp.accessory` reads the bundle's `LSUIElement` once at registration, accepting plist booleans, numbers and strings. `app.activationPolicy` is read live. Popup-container records use `accessory-popup` under accessory policy and `app-popup` otherwise; their workspace remains empty. App policy is captured before the AX round-trip, alongside the window class.
  - `lastFocusedSeq` is written in `updateFocusCache`, where a refresh reads macOS's focused window, and goes to that window, not to `focus`. A window in macOS native fullscreen is numbered too, though it is never `ctx.focused`. A test that needs a confirmed focus calls `refreshWithMacOsFocus(on:)`; `focusWindow()` alone does not number a window.
  - `ctx.previous` is the most recently focused window other than the focused one, read from `lastFocusedSeq`. When that window closes, the one focused before it takes its place. A window never focused is never `ctx.previous`. A minimized window can be, and so can one in macOS native fullscreen, including while macOS has it focused and `ctx.focused` is some other window.
  - Never-focused windows sort by window id. macOS numbers windows from one counter shared by every process, in creation order, and does not reuse a number; this was checked on macOS 26 with two processes creating windows alternately. So window id order is creation order, the same across restarts. The `created` sort key of a Lens should use it too.
  - The number is kept by window id, not on the `Window` object. Locking the screen makes WinMux drop every window and register new objects on unlock, and the numbers have to survive that. `setUpWorkspacesForTests` resets them, since tests reuse window ids.
  - A Filter's contract is `Dyn -> Dyn -> Bool`. The record contracts are not applied on each call: the helper's structs already check every record, and applying them made a Filter three to seven times slower.
  - A minimized window's origin is in its layout reason: `LayoutReason.macos` holds a workspace name with its project and whether the window returns there. Read `layoutReason.origin` for where it came from and `returnWorkspaceName` for where it goes back to.
  - A window in macOS native fullscreen is never `ctx.focused` or `ctx.mouse`. It has a Space of its own, and WinMux's focus never points at one. The Lens panel uses `canJoinAllSpaces` and `fullScreenAuxiliary`; opening over a real native fullscreen Space has not been live-checked.
  - A window WinMux first sees minimized, such as one minimized before WinMux started, has no origin and reports `workspace = ""`. `Window.wasSeenUnminimized` tells the two apart.
  - `columns` is not a key of `Config` yet. When the Column issues add it, the Swift parser must either parse it or drop it, as it drops `filters`: the helper returns a record of hooks as an empty record, and the parser rejects a top-level key it does not know.
  - `project` in a record is the project's id, the key `project-labels` uses, such as `default`. No ticket chose between the id and the display name.
  - A record or array built in Rust and handed to Nickel must be wrapped in `Term::Closurize`, which `host.rs` does. Without it a contract applied to a nested record trips an assertion in debug builds of `nickel-lang-core` and passes silently in release builds.
  - WinMux's parser rejects a top-level key it does not know, so `parseConfig` drops the keys only the helper reads: `filters`, `lenses` and `contract-version`. `lenses` is parsed directly from JSON into `LensConfig` before those keys are removed from the TOML bridge.
  - Supervisor behaviour (timeouts, restarts, the breaker, memory recycling) is tested against a stub helper, a Python script written out by `NickelSupervisorTest`. Extend the stub for new failure cases instead of starting WinMux.
  - The startup fallback (a failed first load leaves WinMux on the built-in defaults with the reason on screen) lives in `initAppBundle` and has no test. `ReadConfigTest` covers the load and its failure message.
  - The Swift parser still takes TOMLKit types; the helper's JSON is converted to a `TOMLTable` in `parseConfig.swift`. Its error text still says TOML things such as "actual type is 'integer'".
  - `reload-on-save` replaced `auto-reload-config`. A config that still sets the old key fails to load, with Nickel's "extra field" diagnostic. `config convert` renames it.
  - The config watcher is one FSEvents stream over the directories of the watched files: the config file where it is or would be, and the imports of the last load that succeeded, minus the shipped library. After a failed load, any file Nickel can import anywhere under those directories counts too. A save when the config file is missing changes nothing, so a checkout that briefly removes it does not put the shipped defaults in effect. A reload that a later one overtook is dropped. Events are filtered on a queue of the watcher's own, and only a change to a file's contents counts, not one to its attributes. The helper's `load` reply carries the library directory for that. A file is matched by its path as written and with its links resolved, because macOS reports resolved paths and a config directory is often a link into a dotfiles checkout.
  - `reloadConfig` and `applyConfig` are not called from tests: applying a config unregisters the login item and deletes launch agent files in the real home directory. The pieces around them are tested instead: `ConfigWatchList`, `ConfigFileWatcher`, `ConfigReloadScheduler`, `ConfigReloadNotifications` and `Config.modeToKeep`.
  - A failed reload is recorded in the supervisor with `recordFailedReload`, so `config status` shows whichever came last, a failed reload or a crash. It is also written to the unified log: `log show --predicate 'subsystem == "<app id>" && category == "config"'`.
  - The Settings panes copy the config into `@State` when they are created. A config reload bumps `ShortcutSettingsModel.settingsRevision`, and the Behavior and Appearance panes take it as their `.id`, so they are created again with the loaded values.
  - Nickel prints a function in a diagnostic as `%<closure@0x…>`, with an address that differs in every helper process. Compare diagnostics with the addresses taken out.
  - CI runs only for `main` and pull requests, so nothing runs on a push to `fork`. `make check` now needs cargo, and `ci.yml` installs only swiftly; whether the `macos-26` runner has Rust is unchecked.
- **Recording CLI output.** Terminal's title bar shows the username, and `osascript` to Terminal raises a permission prompt, so mask the title bar with `ffmpeg drawbox` instead of retitling the window. Run a `.command` script that starts with `clear`, and keep `cliclick` out of it: Terminal has no Accessibility grant.
- **Driving the UI for screenshots.** `cliclick` and System Events work from the build machine. Raise the Settings window first (`AXRaise` and `set frontmost`), and move it clear of WinMux's own sidebar, which expands under the pointer and takes the clicks. Capture one window with `screencapture -l <window id>`, record with `screencapture -v -V <seconds>`, and upload with `gh attach --repo prateek/winmux <pr> <files>`; without `--repo` it targets upstream.
- **Live runs.** Prateek wants one on every pull request with something to see, without being asked. A process started from an Orca terminal inherits Orca's Accessibility and Screen Recording grants, so a debug build runs without a prompt. Hide Orca and any app with private content before recording, unhide after, and save and restore window frames over Accessibility. `/Users/Shared/` is a neutral place for scratch config that shows on screen. In zsh, `log` is a builtin: call `/usr/bin/log`. Don't `wait` in a shell that started WinMux with `nohup ... &`; it waits on WinMux too. WinMux's SwiftUI buttons expose their label as the accessibility description, not the title.
- **Running a debug build.** `make run` fails: it copies the binary to `.debug/` without `Sparkle.framework`. Run `.build/debug/WinMuxApp` instead. Set `XDG_CONFIG_HOME` and `XDG_STATE_HOME` to scratch directories to keep Prateek's own config out of it; his `~/.config/winmux/winmux.toml` is upstream's and would be converted on first launch.
- **Nickel binaries.** Nickel's 1.18 macOS release binaries link libiconv from `/nix/store` and won't run outside Nix. To try one, repoint it with `install_name_tool -change <nix libiconv path> /usr/lib/libiconv.2.dylib` and re-sign with `codesign -f -s -`. `nickel-lang-core` 0.19.0 builds from source, which is what the helper uses.
- **Releases.** `script/dogfood-release <version>` cuts one from `fork`; `--dry-run` publishes nothing. Builds are signed with the self-signed `WinMux Dogfood Signing` identity, which lives in its own keychain on the build machine and keeps Accessibility and Screen Recording grants across upgrades. The hardened runtime is off for these builds, because a self-signed app cannot load its own `Sparkle.framework` with it on. The build number is the commit count of `fork`. The old `codex-columns` line ended at build 1889, so until `fork` passes that many commits Sparkle will not offer the new line to a machine still on `0.51.0-dogfood.15`; that machine reinstalls the cask once.

## Lens implementation for the next builder

- `Sources/AppBundle/lens/` owns candidate collection, sort, Search, session state, lifecycle and inline evaluation. `SwitcherPalette` is the list panel and reads that state. Extend the Presentation there rather than making another eligible-window pipeline.
- AX candidate record reads overlap, preserve candidate order and omit failed/gone windows. The Filter context reuses those records and tolerates failed extra record reads. Opening tickets are cleared on throwing exits without cancelling a newer open.
- Candidates combine workspace windows and the global minimized container, plus opted-in popup classes. Explicit `--all` must not discard a minimized window with no known origin. Popup classes now follow live activation policy; bundle identity controls the floating default for newly registered windows.
- `LensConfig` resolves the implicit `default` profile and merges custom keys over defaults. A session snapshots entries, names, settings and key commands; reloading config does not replace them. Filter functions remain in the helper.
- Search uses user-facing workspace and project names, while Filter records retain their existing ids. Its matcher is shared by the list and scripts. Each word chooses the highest tier times field weight, with title/app winning weighted ties. JSON uses `score` and `matched-field` (comma-separated when words match several fields).
- `LensInlineSearch` debounces for 150 ms, keeps the last good rows after the 50 ms display deadline and rejects late replies; the helper retains its 100 ms deadline. The helper’s new `check-filter` request validates ad-hoc bodies before opening and script bodies even over an empty scope.
- Lens Focus restores minimized windows to their retained origin, recreating the workspace if cleanup removed it; unknown origins use the current workspace. Workspace commands restore before moving; Close does not restore. Popup Focus raises it natively; popup Summon and workspace moves fail without moving it into a tiling tree.
- `restoreLensWindow` and `SummonCommand` restore minimized/hidden windows before acting. Summon preserves floating layout and uses today’s normal tiling arrival path. The Column issue should attach its `place` policy there; Summon must not run `arrive`.
- Lens actions pass a workspace fallback to target resolution for minimized and opted-in popup windows that live outside every workspace. Focus targets only the selection; other commands target marks in mark order.
- `move-node-to-workspace <n>` from a Lens counts workspaces in the selected window's project, not the one on screen. Marks survive a change of Search, so a hidden marked window is still acted on. A failed action is written to the unified log, category `lens`, because the Lens has closed by then. An inline result that arrives after the 50 ms display deadline is dropped, as the issue decides, so a Filter that always takes longer never applies.
- The shipped `search` record is empty so its sort/Presentation contract defaults remain overridable. `floating` uses the default named `filters.floating`, list Presentation, MRU and empty `popups`, with no binding. Both its Filter and Lens settings are overridable. Disabled `list-windows --lens` and `lens` both exit 2 with the same message and empty stdout. Escape, Tab and arrows (including modifier variants) are reserved at load; row hover uses global pointer movement so scrolling cannot take keyboard selection. Inline JSON inputs are built once per open. Configured key equivalents are intercepted before the Search field can consume Command shortcuts such as Cmd+X.
- CLI help is maintained in `subcommandDescriptionsGenerated.swift` and `cmdHelpGenerated.swift`; this fork has no adoc generator. `nonTomlRootKeys` names keys excluded from the TOML bridge accurately because Swift now parses Lens JSON itself.
- `docs/lenses.md` documents the config, CLI, Search and keys. The draft for Lens core and the list records its build details. Its live run used isolated config/state and owned neutral demo windows; the captures are on pull request #26. The Accessory defaults live run covered classification and the formerly unreachable popup rows/actions. Native fullscreen Spaces remain unverified.

## Accessory implementation for the next builder

- The bundle signal enters `isDialogHeuristic`; popup detection still runs first. Ordinary Dock apps retain the existing heuristics. The float is a binding default, so the future Column Policy hooks can replace it.
- Policy changes update records and the class of windows already in the popup container. They do not reclassify an existing window between a workspace and the popup container; activation-policy watching remains out of scope. A close-button-less dialog opened under regular policy stays reachable in `floating`.
- The helper keeps Filter functions and exports their callable config paths as Lens metadata. `list-lenses --json` reports `lenses.<name>.filter`, a `when.default.filter` path when overridden, or `null` when absent. A path is not the source alias; the shipped floating path resolves to `filters.floating`.
- A titled AppKit window without `.closable` can still expose a disabled `AXCloseButton`. The neutral demo in `prototypes/09-accessory-defaults-demo/` overrides `accessibilityCloseButton()` to return nil. Its regular-policy stage registers the app before the accessory-policy stage; there is no proactive registration.
- Automatic workspace ordinals change when an empty workspace disappears. Keep an owned window on each demo workspace before parking private windows elsewhere. Terminal may restore old windows at launch; inspect them before recording, mask identifying title bars, and close only the owned CLI window.

## Suggested skills

- `utils-agent:orca-cli`: create the worktree for each child issue.
- `mattpocock:implement`: build one child issue. It was not installed in the first build session; the issue was built without it.
- `mattpocock:tdd`: test-first at the seams each issue's "Done when" list names.
- `mattpocock:domain-modeling`: when a term needs to change, so `CONTEXT.md` stays current.
- `mattpocock:diagnosing-bugs`: for the two strip questions that need a running build.
- `core:testing-philosophy` and `core:writing-for-humans`: for tests and for replies and pull request text.
