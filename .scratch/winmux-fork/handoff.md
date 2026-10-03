# Handoff: building the WinMux fork foundation

Planning is finished and the build is under way: the deployment target, Nickel config, dogfood release, Filter contract, Global MRU and config hot reload issues have landed on `fork`, on top of upstream `v0.5.6`, and `0.5.6-dogfood.1` is published. Lens core, the list, Accessory window defaults, the thumbnail cache and miniatures have landed too; the shipped `floating` Lens reaches floating windows across workspaces. Strip, `recent`, `app-windows` and cmd-tab ownership have landed as well. The fixed Columns model has a tested first slice; its config, width editing, focused-empty outline and live validation remain. This note orients an agent that is about to build. It holds only what the issues, the map and the code don't. Last updated 2026-10-03.

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
- **Done, with checks left:** [Thumbnail cache and the `'miniatures` Presentation](https://github.com/prateek/winmux/issues/9). The cache, `overview`, miniature settings and contracts are built. The debug run checked geometry, trays, Search, Focus/Summon, paging, Accessory styling and presentation conversion over owned windows. The first debug session stalled; an isolated restart recovered refreshes without answering permission dialogs, and recorded fresh departure captures and advancing miniatures. The original stall is unexplained. The captureScreenshot benchmark used 50 distinct owned windows. The signed-build screen-recording indicator is **not checkable: it needs a release build, which is Prateek's**; leave this check for Prateek.
- **Done, with checks left:** [Strip Presentation and the cmd+tab takeover](https://github.com/prateek/winmux/issues/8). Debug live runs checked the strip and native-chord ownership, local panel releases, Secure Input, config/mode/disable restoration and normal/signal/hard-kill recovery. Real wake and real unlock remain unchecked. Release-build behavior, fast user switching and a second display remain checks for Prateek; none was run on this machine.
- **Built model, with work left:** [Fixed Columns: slots, the count invariant, Width presets](https://github.com/prateek/winmux/issues/11). Slots, normalization, placement, movement and sparse fractional layout have 20 model tests. Config activation, width operations, divider drag, the outline and the live run remain; Columns are not user-configurable yet. No release check was performed.
- **Next:** Finish **Fixed Columns: slots, the count invariant, Width presets**. Then [Column Policy hooks and Column commands](https://github.com/prateek/winmux/issues/12) is buildable: its other blockers are closed. [Default config, Triggers, the `lens` leader mode, `subscribe` events](https://github.com/prateek/winmux/issues/13) still waits for **Column Policy hooks and Column commands**.
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
- **Window capture.** `WindowScreenshot` in `Sources/AppBundle/util/` wraps the one-shot ScreenCaptureKit call and caches the `SCWindow` list, refreshing on registration/destruction and refetching missing ids for direct capture callers. The thumbnail cache builds on it. The capture's default size is the window's size in points, so callers pass a pixel size.
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
  - `columns` is still not a key of `Config`: the model slice does not enable it from config. The next slice must parse top-level and `workspace.<name>.columns` from JSON before the TOML bridge (as for `lenses`), or remove helper-only fields. The parser rejects unknown keys. This issue adds count, widths, width-presets and when-profile records, with no hooks. Hook functions are exported by the helper as empty records.
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
- `docs/lenses.md` documents the config, CLI, Search and keys. The draft for Lens core and the list records its build details. Its live run used isolated config/state and owned neutral demo windows; the captures are on pull request #26. The Accessory defaults live run covered classification and the formerly unreachable popup rows/actions. The thumbnail live run tried an active native fullscreen Space: opening the Lens returned to the managed desktop. Inactive fullscreen entries retained their capture.

## Thumbnail and miniatures implementation for the next builder

- `Window.thumbnail` is one `WindowThumbnail` holding an observable last-good `CGImage` and its
  capture date. `Window.miniatureFrame` preserves the unparked frame. Closing clears the image
  and queued work; a completion after close cannot repopulate it. Capture failure preserves it.
  Hidden apps are checked before and after capture so a hide cannot replace their last good frame.
  Capture sizing preserves portrait aspect ratio and covers the 560-point workspace width plus
  its 4% current-workspace enlargement at the highest attached display scale. Shrink never
  enlarges a cell beyond that base width.
- `ThumbnailCache` owns scheduling; `ThumbnailCaptureGate` owns all queue decisions. Park and
  focus loss use the 800 ms throttle. Command minimization bypasses it and waits up to 200 ms
  before minimizing; already-minimized captures cannot replace a good frame. Native focus
  observation precedes logical-focus guards, so opening a popup still captures the window
  that lost focus. A Presentation passes its session token for live refreshes, which bypass
  the throttle. Park and minimize work take priority. `closeLens(token)` drops queued
  refreshes; event ownership survives dismissal. Running captures may complete. The strip
  should reuse these APIs and the window-owned image.
- `WindowScreenshot` runs on `ScreenshotWorker`, away from the main actor. Its shareable-window
  list includes off-screen windows. Registration/destruction refresh it while retaining the
  previous list; invalidation during a fetch forces a follow-up fetch. Capture sizing prefers
  the current applied layout aspect to an older parked frame. Cache captures set
  `cachedOnly: true` so opening a Lens never fetches the list. Direct callers retain missing-id
  lookup. Enumeration checks the existing grant; WinMux does not request one explicitly.
  macOS may still present bypass permission dialogs for the capture API.
- `MiniatureSession` extends `LensSession`; `MiniatureLayout` is pure scale, grid, page and
  navigation geometry. Entries still come from `lensWindows` and the Lens Filter result. No
  second eligibility pipeline exists. The view uses retained workspace ids for trays, with
  snapshot cells labeled “Previous …” for retained origins outside the sidebar order. Unknown-origin minimized windows and popup
  windows have no miniature cell; list conversion keeps them in the session snapshot.
- The panel uses the focused monitor's visible rect, `isOpaque = false`, 60% black and
  behind-window HUD blur. It draws cached images immediately, then refreshes current-page
  non-Frozen entries every 500 ms through the shared gate. The session snapshots window
  geometry; window moves while a Lens is open do not rebuild its geometry.
- `MiniaturesConfig` resolves partial `when.default` overrides and exports hyphenated settings.
  The Nickel contract validates incompatible fields before inserting list defaults and checks
  resolved profile combinations. Shipped overview priority -1 overrides the contract's -2 list
  fallback while remaining below explicit user settings. No chosen default changed.
- `ThumbnailAppearance` owns Frozen dimming, age and pause looks. `MiniaturesView` adds selection,
  marks, app icons and the Accessory outline/tag. Search dims entries in place and shares Lens
  ranking. Arrows support nearest and by-workspace; scrolling pages. Presentation conversion
  preserves the selected id even when the set of displayed entries changes.
- Landing geometry is computed only while a configured Summon modifier is held and on selection
  changes. It must never call the mutating append-binding helper. Today's preview uses the
  tree's appended-slot geometry; Column Policy hooks should supply the placement result at
  `updateMiniatureLanding`. Summon still uses the existing command path and does not run arrive.
- `docs/lenses.md` documents overview and the settings. The build draft records the live results
  and remaining checks. The overview opened over 50 owned windows in 109.2 ms at the CLI;
  debug tracing observed at most two captures in flight. The recordings show geometry,
  retained trays, badges, Search, mouse and keyboard actions, Summon landing, Accessory tags,
  paging and list conversion. Both owned clocks painted behind the non-opaque overlay with
  blur disabled for readable evidence. Opening from active native fullscreen returned to
  the managed desktop. The initial session stopped updating captures; an isolated restart
  recovered them without answering permission dialogs. Fresh park captures and advancing
  miniatures were then recorded. The initial stall is unexplained. The release-build indicator
  remains Prateek's check.
- The fixes from the second review (gate order, a floating window's capture shape, `by-workspace`
  arrow order, draw order of overlapping floating windows, the `'hide` opening selection, scroll
  thresholds and the minimize command's re-check) were made after the live run and are covered
  by tests only. `lensLog.debug` logs each capture start with the in-flight count.
- For live runs, hiding apps before the build starts worked: Terminal and Orca stayed icon-only
  and their restored windows were preserved. Keep them hidden throughout capture and never
  select their tray entries. Save and restore frames, unhide the apps afterwards, and leave
  permission prompts and protected updater dialogs unanswered.

## Accessory implementation for the next builder

- The bundle signal enters `isDialogHeuristic`; popup detection still runs first. Ordinary Dock apps retain the existing heuristics. The float is a binding default, so the future Column Policy hooks can replace it.
- Policy changes update records and the class of windows already in the popup container. They do not reclassify an existing window between a workspace and the popup container; activation-policy watching remains out of scope. A close-button-less dialog opened under regular policy stays reachable in `floating`.
- The helper keeps Filter functions and exports their callable config paths as Lens metadata. `list-lenses --json` reports `lenses.<name>.filter`, a `when.default.filter` path when overridden, or `null` when absent. A path is not the source alias; the shipped floating path resolves to `filters.floating`.
- A titled AppKit window without `.closable` can still expose a disabled `AXCloseButton`. The neutral demo in `prototypes/09-accessory-defaults-demo/` overrides `accessibilityCloseButton()` to return nil. Its regular-policy stage registers the app before the accessory-policy stage; there is no proactive registration.
- Automatic workspace ordinals change when an empty workspace disappears. Keep an owned window on each demo workspace before parking private windows elsewhere. Terminal may restore old windows at launch; inspect them before recording, mask identifying title bars, and close only the owned CLI window.

## Strip and takeover implementation for the next builder

- `StripLayout.swift` owns width/cap/count geometry, the 100 ms gesture deadline and session input/release rules. The invoking chord is carried with `lensInvocation` TaskLocal state; shell calls sample live CG flags. Shift reverses cycling but is excluded from committing and release-binding modifiers. A release already seen before Filter evaluation completes commits immediately and dismisses even with no Enter commands. `LensLifecycle` accumulates forward/reverse Trigger steps while opening, applies them when the session becomes ready and never toggles a strip closed. Initial selection skips entry 0 only when it is focused; reverse-first starts at the end. Removing entries preserves the selected id or chooses its surviving successor. A letter's Lens `keys` binding wins before converting the same session to a list; Search accepts only the invoking base modifiers or none. An unrelated global binding dismisses the strip before it runs, so release cannot undo its action. Clicks resolve Enter using the release modifiers, and commit immediately while the invoking modifiers remain held.
- `SwitcherPalettePanel` delays its strip presentation, makes the existing non-activating panel key without activating WinMux, and cancels display/refresh work on dismissal or conversion. Both local and global `flagsChanged` feed release. This local path is essential: a key panel's release does not reach the global monitor. Carbon callbacks and panel keys share `LensSession.stripInput`, so a global binding cannot swallow a Lens action or Search hand-off. Closed windows are removed from the open strip without taking another eligible snapshot.
- `StripView` reuses `MiniatureEntryView`, the thumbnail appearance and existing cache/gate. The row is centered on the focused monitor, fits its width, caps at nine, scrolls around selection and counts hidden entries at both ends. Summon landing is drawn on the screen rather than inside a miniature. Current-workspace selections show neither Summon label nor landing spot. Both thumbnail presentations read the onscreen snapshot, so active native-fullscreen windows are live. No second eligibility or capture pipeline exists.
- Shipped `recent` is every ordinary eligible window in Global MRU order; `app-windows` uses `filters.same-app`, with null-focus safety. Main-mode cmd-tab/cmd-shift-tab/cmd-backtick are ordinary bindings. Existing `alt-enter = summon` is retained in both contracts. For an ad-hoc named Filter use `--filter same-app`; a body would be `--filter 'filters.same-app w ctx'`, not the function value `filters.same-app` alone.
- `SymbolicHotkeyReconciler` is synchronous, locked and tested with fake table/store seams. `SystemSymbolicHotkeys` supplies the dynamic CGS adapter, all-build exit handlers and launch repair. `applyHotkeyEnabledState` derives ownership from successful current registrations; wake and distributed `com.apple.screenIsUnlocked` repair and re-apply. It lazily scans the live table for cmd-tab candidates, caches their ids across mode changes and rescans on repair. Idle reconcile does no table work, and marker writes happen only on changes. It only disables enabled cmd-tab pair matches, persists original chords before disable, verifies writes, restores only unchanged marker ids and leaves backtick on. A re-enabled wanted id is retaken in the same pass; changed chords and enabled no-longer-wanted ids are dropped. Repair retains errors from both restore and retake, and later success clears them. Signal sources restore off the main queue before normal cleanup; a two-second exit deadline bounds blocked cleanup. `SignalTermination.eventHandler` returns a Sendable callback so installation from MainActor cannot make background restoration actor-isolated. No-op signal dispositions reset on exec; the real `exec-and-forget` child reported all three defaults. HotKey 0.2.1 is vendored solely to expose Carbon's registration error.
- The fixes from the second review were made after the live runs and are covered by tests only: `StripGesture.step` and `owns` decide what is the strip's (the invoking key and Tab or backtick, with exactly the invoking modifiers, Shift free), for a ready strip and an opening one alike; any other chord drops the strip, opening or drawn, and runs its global binding. A release during opening is recorded by `LensLifecycle.openingFlagsChanged` and committed when the session is ready, and a press after it is ignored. A key bound to an empty command list closes only a strip's release. `restoreAndShutDown` is what every exit path calls, so a reconcile during cleanup cannot retake the chords. An unreadable owned id stays in the marker, and an empty candidate scan is repeated.
- `winmux doctor` reports held ids, marker ids and failures. In the unbundled debug executable the UserDefaults domain is **`WinMuxApp`**, not the debug socket/logging app id. A bundled build uses its bundle domain; upstream has no compatible repair marker. Hard kill leaves native cmd-tab off until this build relaunches. Recovery is relaunch then normal quit; verify the live table and empty marker. Another cmd-tab owner can cause two overlays; this is documented rather than prevented.
- The debug live run found the starting panel approach works, including an owned Secure Input field. `lsappinfo` kept the owned app frontmost before/during/after. Global flags fired with the secure field key; local flags committed with the strip key. No temporary Carbon fallback or event tap was necessary. Fast user switching, real wake/unlock, two-display behavior and release behavior remain unverified. A posted unlock notification plus a manually re-enabled id exercised repair live; tests cover both wake reasons and unlock. Signal handlers are outside debug conditionals, but only the debug executable was run.
- Live driver traps: installed cliclick inserts a 100 ms pause even with `-w 0`; a true short tap needs an isolated driver without that pause. Arrow events can leave Fn held, preventing Carbon matches until `cliclick ku:fn`. A separate successful Carbon probe established this before diagnosing the feature. Cliclick `kp` cannot type backtick or ordinary letters; a task-local physical-key helper supplied those. `WINMUX_DEBUG_STRIP_EVENTS=1` logs global/local flags and strip ready/draw timing. Debug live evidence covers rapid opening cycles, cmd-held click, cross-workspace Option-click, global workspace-next and SIGTERM. A full-row crop is possible when the strip is in front of the untouched dialog. The copied `.debug` binary lacks Sparkle beside it; live runs used `.build/debug/WinMuxApp`. Retained command sessions keep apps alive where background shell jobs did not. `screencapture -v` refuses to overwrite an existing movie: use unique paths, require recorder exit 0 and inspect result frames, since an old file otherwise looks like a successful new capture. No cache stall recurred during these sessions; restart before treating stale frames as a strip bug, as the miniature live notes explain.

## Suggested skills

- `utils-agent:orca-cli`: create the worktree for each child issue.
- `mattpocock:implement`: build one child issue. It was not installed in the first build session; the issue was built without it.
- `mattpocock:tdd`: test-first at the seams each issue's "Done when" list names.
- `mattpocock:domain-modeling`: when a term needs to change, so `CONTEXT.md` stays current.
- `mattpocock:diagnosing-bugs`: for the two strip questions that need a running build.
- `core:testing-philosophy` and `core:writing-for-humans`: for tests and for replies and pull request text.

## Columns implementation for the next builder

- `TreeNode.columnSlot` holds the one-based slot on occupied root children; empty slots have no node. Binding to another parent clears the old slot. Flatten transfers the Column wrapper's slot to its replacement. Tab-group creation and `join-with` transfer the destination slot to their new wrapper. Frozen window/container records retain optional slots and decode older records without them.
- `Workspace.columns: ColumnState?` is the enable gate, currently populated only in tests. `ColumnState` in `tree/Columns.swift` owns count, declared/current fractional widths, an optional directly focused slot and a weak reference to the last root. Config resolution and reload are not implemented yet; attach their resolved settings here, reset declared/current widths on reload and let the invariant fold a lowered count.
- `enforceColumnInvariant` in `tree/Columns.swift` runs immediately after flatten normalization in `tree/normalizeContainers.swift`. The root is exempt from flatten while Columns are on. The pass recovers a wrapped old root, forces horizontal tiles, keeps valid unique slots, folds unindexed/excess nodes through built-in placement, applies weights and sorts children by slot while preserving MRU. Opposite-orientation normalization exempts Column nodes and still runs inside them.
- `columnPlacementSlot`, `columnBinding` and `bindToColumn` own built-in placement. `bindingDataForNewTilingWindow` branches here before automatic tab insertion. Empty-slot binding uses a temporary one-child wrapper to transport the slot through the existing `BindingData`; normalization removes it after binding. The next issue's `place` hook can choose the slot/Overflow policy before these binding operations. Workspace moves and Summon currently rely on invariant folding; the next issue must route them through `place` too.
- `moveAcrossColumnBoundary` is called at root-level movement and when `moveOut` reaches a Column edge. Attach `move-boundary` here. Inside a Column existing movement still applies. No new commands have been added.
- `layoutTiles` in `layout/layoutRecursive.swift` has a root-only Columns branch that positions children by slot and stored fractions and reserves gaps beside empty slots. Width-editing operations, resize, balance and divider drag remain to be implemented; do not treat the existing fractional store as those operations.
- Precedence resolution, Nickel contracts, the outline and focus observation wiring are still missing. The outline can read `focusedSlot`; the command that sets it belongs to **Column Policy hooks and Column commands**. Summon landing preview remains today's geometry until its placement-preview seam is replaced.
- `Sources/AppBundleTests/FixedColumnsTest.swift` exercises the model without `reloadConfig` or `applyConfig`, which touch the real home directory. `docs/columns.md` states the model's availability and remaining work. Complete its accepted config examples only once the real helper accepts them.
