# Review of the twelve build issues

Reviewed against `map.md`, `issues/*.md`, `research/*.md`, the prototypes (27, 28, 29, 08), `CONTEXT.md`, ADR 0001 and the code at `v0.5.6` (worktree head `f69ceed9`, `v0.5.6-21`). Paths below are relative to the repo root unless they start with `issues/`, `research/` or `prototypes/`, which are under `.scratch/winmux-fork/`.

## Summary

- Job 1: 3 wrong, 7 gaps, 11 nits (01's second note is a pointer to 08's gap and is not counted). Issues 05 and 11 have no findings; 00 and 01 have nits only.
- Job 2: 122 open details (01: 3, 02: 14, 03: 6, 04: 7, 05: 2, 06: 18, 07: 14, 08: 11, 09: 6, 10: 15, 11: 15, 12: 11). A (already decided) 14, B (settled by the code) 7, C (one sensible default) 91, D (needs the owner) 10 rows. A row marked with two letters is counted under the first.
- The 10 D rows collapse to 4 questions: identifier spelling (hyphen vs underscore), how a Lens opts into popup-class windows, how a user config layers over the shipped defaults, and what happens to the Settings panes that edit the config file.
- The one must-fix that costs an implementer real time is 02 and 04 both claiming to build the batched Filter request, `eval-filter`, the smoke run and the missing-field rejection.
- Could not check: whether `-` is legal inside a Nickel identifier or enum tag (no `nickel` binary on this machine; the spike's `spike` binary only runs its fixed configs). If it is not, the spelling question answers itself and 06's example `['floating, 'accessory-popup]` is not valid Nickel. Also unverified: that a `.nonactivatingPanel` can be key without activating the app (07 row "How a non-activating panel receives keys"); that upstream's binding parser accepts a command list the way callbacks do (12 row "Leaving the `lens` mode"); and the two platform behaviours 07 itself flags (global `flagsChanged` under Secure Input, symbolic-hotkey state across fast user switching).

## Job 1: what is wrong

### 00-umbrella.md

- nit. "One model covers exposé, cmd+tab and cmd-K search" uses `exposé`, which `CONTEXT.md` lists under _Avoid_ for Lens. Explanatory use, but the issue tells implementers to "Use them as written."

### 01-deployment-target.md

Clean. Two notes:

- nit. Ticket 15 says "the three `CGWindowListCreateImage` call sites go"; the draft says five. The draft is right: `rg CGWindowListCreateImage Sources` finds `WinMuxMarketingRenderer.swift:90`, `WindowTabsPanel.swift:36`, `DoubleSidedWindowController.swift:25` and `:36`, and `WindowCapture/main.swift:207`. Worth a sentence so the implementer does not go looking for the discrepancy.
- nit (cross-issue, see 08). 01 decides "Window capture uses ScreenCaptureKit's one-shot capture, `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`", while 08 lists "Which API call" as open.

### 02-nickel-config.md

- **wrong.** 02 and 04 both own the batched Filter request, `eval-filter`, the smoke run and the missing-field rejection. 02, under "Not in this issue": "This issue builds the marshalling and smoke-run mechanism those definitions plug into." and "This issue builds only the batched Filter request and `eval-filter`." 04, under "Not in this issue": "This issue adds the Filter requests and the smoke run to that helper." Duplicated Done-when items: 02 "A batched Filter request for a Filter named under `filters`, with 50 windows, returns 50 match bits. A window record with a missing field is rejected by the helper with an error that names the field, before any Nickel runs." and "An `eval-filter` request whose body calls a Filter named under `filters` returns that Filter's result." against 04 "One batched Filter request carrying the Filter context and every window returns one match bit per window.", "The helper rejects a Window record with a missing field before evaluating any Nickel, and a test covers it." and "An `eval-filter` request with the body `w.class == 'floating` returns match bits, and a body that calls a named Filter works." Also both: 02 "The `filters` record is part of this issue's library" and 04 "Named Filters live in the config's `filters` record". Pick one owner. The natural split: 02 builds the requests and the smoke-run loop against a stand-in record; 04 supplies the record definitions, contracts, synthetic values and `config schema`. Then delete the duplicated Done-when items from the other.
- nit. "One binary, three modes." Ticket 31 says "One binary, two modes" (`serve`, plus the one-shot pair). Counting only.
- nit. "Filters and Policy hooks are Nickel functions written in the config, in the form `fun w ctx => …`." Hooks take more: the prototype writes `columns.place = fun w ctx cols =>`, `columns.move_boundary = fun w ctx cols edge =>` and `arrive = fun w ctx cols =>` (prototypes/27-config-language.html, Nickel tabs; prototypes/28-nickel-spike/config/config.ncl).
- nit. Done-when "A 50-window Filter request takes about 2 ms and a `place` request about 0.2 ms from Swift on Apple silicon, in line with the spike." is a benchmark, not a pass/fail check. Say what fails it (for example, more than 10 ms).

### 03-config-hot-reload.md

- **wrong.** "Today's watcher opens the config file itself with `O_EVTONLY` and loses it on such a rename." The first half is true (`Sources/AppBundle/config/ConfigFileWatcher.swift:9`), the second is not: the source is created with `eventMask: [.write, .delete, .rename, .revoke]` (`:13`), the event runs `reloadConfig()`, and `ReloadConfigCommand.swift:55` calls `syncConfigFileWatcher()` after every reload attempt, success or failure, which reopens the file by path. The decision to watch directories stands (ticket 32: "WinMux watches the containing directories, so an atomic rename is seen"), but its justification should be the two cases today's watcher really misses: imported files (TOML has none, so the one-file watcher never needed them) and a config file created after startup (`ConfigFileWatcher.init?` returns nil when `open` fails, and nothing retries until a reload), which the draft's own open detail asks about.
- nit. Done-when "A Lens open during a save keeps its entries and still acts on a selection." tests the Lens machinery of 06, on which 03 does not depend. Move it to 06 or mark it as a check for after 06 lands.

### 04-filter-contract.md

- **wrong** (shared with 02, see above): double ownership of the Filter requests and smoke run.
- gap. "**`document`** stays in version 1 because WinMux reads `AXDocument` itself." Nothing reads it today: `rg AXDocument Sources` finds only the comment `// kAXDocumentAttribute` at `Sources/AppBundle/util/accessibility.swift:159`. The sentence comes from ticket 33 ("`w.document` stays because WinMux reads it itself"), where it meant "without a Tab provider". 04 should say that reading `kAXDocumentAttribute` per window is new work in this issue, since it is the one field that costs an AX round-trip.
- gap. The Window table says `workspace` is "never unknown". It is unknown for two of the listed classes. `macosMinimizedWindowsContainer` and `macosPopupWindowsContainer` are built with `parent: NilTreeNode.instance` (`Sources/AppBundle/tree/MacosUnconventionalWindowsContainer.swift:18-24` and `:26-34`; the `super.init` lines are 22 and 32), and `nodeWorkspace` is `self as? Workspace ?? parent?.nodeWorkspace` (`Sources/AppBundle/tree/TreeNodeEx.swift:38-40`), so a `'minimized`, `'accessory-popup` or `'app-popup` window has no workspace. Ticket 33 is the source, so this is a contract amendment: give `workspace` a "when unknown" value (`""`) or decide what those windows report. 09's open detail "Popup-class windows have no workspace" is the same gap; 08 inherits it (below).
- gap. Three Done-when items test work that lands in issues depending on 04, not the reverse: "A config with `filters.<name> = fun w ctx => …` loads, and a Lens can use the Filter by name or inline." (Lens records are 06), "A close-button-less window of an app with no Dock icon is `'accessory-popup`. The same app's window is `'floating` while the app is `regular`." and "`w.app.accessory` is `true` for an `LSUIElement` app even while its activation policy is `'regular`." (09 says "Both fields are declared in the Filter contract. This issue supplies their values." and "this issue makes sure each popup-classified window carries the right class"). Either 04 reads `LSUIElement` and assigns the popup classes itself, and 09 drops them, or these move to 09.

### 05-global-mru.md

Clean. The code claims hold: `checkOnFocusChangedCallbacks` is at `Sources/AppBundle/focus.swift:196` and returns early when `refreshSessionEvent?.isStartup == true` (`:197-199`), as the open detail says.

### 06-lens-core-and-list.md

- nit. The example "`std.array.elem w.class ['floating, 'accessory-popup]`" writes a hyphenated enum tag in Nickel. Every Nickel artifact that was run through an evaluator spells it `'accessory_popup` (prototypes/28-nickel-spike/config/config.ncl: `floaters = fun w ctx => std.array.elem w.class ['floating, 'accessory_popup]`). This is the spelling question (D1); until it is settled the example should not pick a side silently.
- The mechanism behind "Both popup Window classes are left out unless the Lens's Filter names them" is undecided (the draft says so in Open details). It is a decision, not a drafting error, so it is listed under D2 rather than here.

### 07-strip-and-cmd-tab.md

- **wrong.** "The reconciler repairs from the marker and re-applies on launch, on wake and on screen unlock. The observers for wake and unlock already exist in `GlobalObserver.swift`." Only the wake observers exist: `NSWorkspace.didWakeNotification` and `NSWorkspace.screensDidWakeNotification` at `Sources/AppBundle/GlobalObserver.swift:106-107`. There is no unlock or session observer (`rg -i 'unlock|sessionDidBecomeActive|DistributedNotificationCenter' Sources/AppBundle/GlobalObserver.swift` finds nothing). The error is inherited from research 25 §5 step 5, which cites "`GlobalObserver.swift:13, 106-107`" for "wake and unlock"; line 13 is the `lockScreenAppBundleId` check inside `onNotif`, not an observer. The unlock observer (`com.apple.screenIsUnlocked` on `DistributedNotificationCenter`) is new work.
- nit. "hotkey" and "symbolic hotkey" throughout; `CONTEXT.md` lists `hotkey` under _Avoid_ for Trigger. Here it names the OS's own mechanism, which is defensible, but say so once ("the system's symbolic hotkeys, Apple's term").

### 08-thumbnails-and-miniatures.md

- gap. "Minimized and hidden-app windows sit in a tray under their workspace." Hidden-app windows have one (`MacosHiddenAppsWindowsContainer` takes `parent: Workspace`, `MacosUnconventionalWindowsContainer.swift:11-16`); minimized windows do not (global container, above), and nothing remembers where they came from: `normalizeLayoutReason.swift:7` processes `macosMinimizedWindowsContainer.children` against `focus.workspace`. A last-known-workspace field on `Window` is needed to draw the tray, and no issue builds it. Same fix as 04's `workspace` gap.
- gap. Open detail "Which API call. The research recommends `captureScreenshot` ... Pick one" is already decided by 01: "Window capture uses ScreenCaptureKit's one-shot capture, `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`, which is macOS 26 only." 08 should follow 01 and only re-measure.

### 09-accessory-defaults-and-floating-lens.md

- nit. Done-when "`winmux config schema` shows `accessory` and `activationPolicy` on App." tests 04's output, not this issue's. Harmless since 09 depends on 04, but it belongs in 04.
- The workspace gap for popup windows is logged under 04.

### 10-fixed-columns.md

- gap. "The fields are `count`, `widths` and `width-presets`, plus the two hook fields" at all four precedence paths contradicts ticket 09: "A profile declares the starting `widths` (fractions) and a global `width-presets` list." The draft's own open detail notices this; the decision text should follow the ticket (read `width-presets` from `columns` only) rather than leave it to the implementer.
- nit. "**Default config, Triggers, the `lens` leader mode, `subscribe` events** covers the `columns-changed` event and shipping `count` off by default." and, in this issue's own Decisions, "`count` is a number or `'off`, and the default is `'off`." Two owners for one default; harmless because both say `'off`.

### 11-column-hooks-and-commands.md

Clean. The code claim "Upstream binds a new window into the tree before the detection callbacks run" holds: `MacWindow.getOrRegister` calls `unbindAndGetBindingDataForNewWindow` before `tryOnWindowDetected` (`Sources/AppBundle/tree/MacWindow.swift:31-52`).

### 12-default-config-and-triggers.md

- gap. "The config WinMux ships gains five default Lenses, their Triggers, a `lens` binding mode ... and Columns set to off." An implementer reads "gains" as "write the five Lens records here", but each sibling already ships its own: 06 "The shipped defaults include a Lens named `search`", 07 "Ship the two Lenses that use it, `recent` on `cmd-tab` and `app-windows` on `cmd-backtick`", 08 "Ship the default `overview` Lens on it", 09 "The default config ships a Lens named `floating`". Say that 12 binds and checks them and must not restate their values. (The restated values match today; the risk is drift.)
- nit. "Depends on" omits "Config hot reload" although `config-reloaded` "fires after every reload attempt" including file-triggered ones. Covered transitively through 02, so a one-line mention is enough.
- The upstream chord list was checked line by line against `resources/default-config.toml:72-160` and is complete and correct; `cmd-tab`, `cmd-backtick`, `alt-slash` and `alt-semicolon` are unbound there, and `backtick`, `slash` and `semicolon` are key names in `Sources/AppBundle/config/KeyMappingPresets.swift:174`, `:43`, `:31`.

## Job 2: the open details

Bucket letters: A already decided, B settled by the code, C one sensible default, D needs the owner. D rows point at the consolidated list at the end.

### 01-deployment-target (3)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| What each `CGWindowListCreateImage` site becomes; the below-window capture | C | Four single-window sites become a one-shot capture of that `SCWindow`. The flip-animation background (`.optionOnScreenBelowWindow`, `DoubleSidedWindowController.swift:28`) is dropped: it is a dev-facing nicety and a display capture excluding windows costs a `SCShareableContent` fetch on an animation path. | research/03 §1: `SCContentFilter(desktopIndependentWindow:)` "captures 'just the independent window passed in'" |
| Port or remove the two dev tools' capture paths | C | Remove `--core-graphics` from `winmux-window-capture` and keep its ScreenCaptureKit path; port the marketing renderer's self-capture to the same one-shot call. | `Sources/WindowCapture/main.swift:207`, `WinMuxMarketingRenderer.swift:90` |
| Sync callers need an async shape or a cached result | C | `estimateWindowPreviewCornerRadiusFromImage` becomes async with the result cached per window id; the flip awaits its capture before animating. | `WindowTabsPanel.swift:26,35` |

### 02-nickel-config (14)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| How the user's config reaches the shipped contracts library | A | The user writes the import and applies the contract, as prototyped and chosen: `let W = import "winmux.ncl" in … | W.Config`. The helper adds its bundle directory to Nickel's import path so that line resolves without copying the file (the spike's stand-in is a workaround, not the shape). | prototypes/27-config-language.html, Nickel tab: "`let W = import "winmux.ncl" in   # shipped by WinMux: contracts, types, defaults`" ending "`} | W.Config`"; ticket 27: "checked against a WinMux-shipped `winmux.ncl` of contracts and defaults" |
| How a batched Filter request names the function | A | By Lens name: the helper looks up `lenses.<name>.filter`. | ticket 28 §1: "WinMux doesn't need that path, since it looks up `lenses.<name>.filter` and calls it per window, so the `filter = filters.same_app` shape stands." |
| Wire names of requests, replies, `config status` fields | C | `load`, `filter`, `hook`, `eval-filter`; replies `{id, ok, result|error, rss}`; `config status` keys `state`, `pid`, `rss`, `recycles`, `last-error`, `config-path` (kebab, matching existing JSON output such as `window-id`). | |
| Where built-in defaults come from when the helper cannot load | C | Generate them at build time: run `winmux-nickel` over the shipped library with an empty user config and embed the static JSON in the app bundle. "Built-in defaults" then means that file. | |
| Is the 256 MB threshold a setting or a constant | C | A constant for now; ticket 31 calls it "a knob", not a config field. | ticket 31: "256 MB is a knob: it's about 1,600 Lens opens at 160 KB each" |
| First restart immediate or after 1 s | A | Immediate; the backoff applies from the second crash. | ticket 31: "A crashed helper restarts at once with backoff (1, 2, 4 s, capped at 30 s)." |
| How the CLI finds the helper outside the bundle with the server down | C | `WINMUX_NICKEL_HELPER`, then next to the `winmux` executable, then the app bundle found by bundle id through LaunchServices. | |
| `config check` with no argument; exit code on failure | A for the shape, C for the rest | The optional argument is decided. No argument checks the file WinMux would load. A file that fails exits 2 (it is the "bad Filter" case of the exit-code rule). | ticket 20: "`config check [<file>]`"; 02: "2 bad usage or a bad Filter" |
| Where `config convert` writes, and its input | C | Stdout; input defaults to the TOML WinMux would have loaded (the existing search order in `Sources/AppBundle/config/ConfigFile.swift`). | |
| What `convert` emits for `[[on-window-detected]]` | C | Each entry becomes a commented-out `arrive` branch with a warning on stderr; nothing keeps working until 11 lands. The upstream default config has no entries (`rg on-window-detected resources/default-config.toml` finds none), so only user rules are affected. | |
| How existing settings are named in Nickel | C | The same keys and nesting as the TOML (`gaps`, `workspace-sidebar`, `mode.main.binding`), as 12 already assumes. Note this ties into D1: inherited keys are kebab-case. | 12: "at the same record paths (`mode.main.binding`, `gaps`, `workspace-sidebar` and so on)" |
| The existing config surface: `config --get/--all-keys/--major-keys/--config-path`, `reload-config --dry-run/--no-gui`, `--config-path`, XDG paths, starter config, Settings panes | D4 for the panes, C for the flags | All flags carry over against the static JSON (`ConfigCmdArgs.swift:10-13`, `ReloadConfigCmdArgs.swift:9-10`, `initAppBundle.swift:108`); search paths carry over with `.ncl` (`ConfigFile.swift:12-15`); the starter config is written as Nickel (`ConfigFile.swift:200`). The Settings panes are D4. | |
| Does `TOMLKit` stay | C | Stays while the AeroSpace importer in Swift reads TOML; drop it when that importer moves to the helper. | `Package.swift:25,54` |
| `script/dogfood-release` is not on this branch | C | As the draft says: add the signing step to `makefile`/`project.yml` and note it in the PR. `ls script/` shows no such script. | |

### 03-config-hot-reload (6)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Files watched after a failed load | C | Keep the last successful import list plus the config file. | |
| Is the shipped library a watched import | C | No; exclude paths inside the app bundle. | |
| Log destination | C | WinMux's existing logging; name the sink in the PR. | |
| What "identical error" compares | C | The full diagnostic text. An edit above the error re-notifies, which counts as "fails differently"; cheaper than normalising positions. | |
| No config file at startup, created later | C | Watch `~/.config/winmux/` from startup even with no file, and load the file when it appears. This is the case today's watcher cannot handle (`ConfigFileWatcher.init?` returns nil). | `ConfigFileWatcher.swift:9-10` |
| The Settings pane toggle that writes `auto-reload-config` | D4 | See the consolidated list. | `ConfigSettingsViews.swift:46` |

### 04-filter-contract (7)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| The single source for contracts, structs and schema | C | A schema definition in `nickel-helper/` (Rust types with a derive that emits the `.ncl` contracts and the schema JSON at build time); a test asserts the three agree, as the Done-when already requires. | |
| Synthetic Window values; more than one Window | C | One `'tiled` window of a `'regular` app with implausible strings (`"winmux-smoke"`), run in the two context cases. Add popup-class windows only if D2 picks the evaluate-at-load mechanism. | |
| Where `contract-version` is declared; older configs | C | A `contract_version` (spelling per D1) field in the shipped library. At version 1 nothing can lag, so a user-declared version is accepted and ignored; a renamed field would fail the smoke run anyway. | |
| Shape of `config schema --json` | C | `{ "contract-version": 1, "records": { "Window": [ { "name", "type", "enum", "description" } ], … } }`. | |
| Does `config schema` work with the server down | C | Yes: a `schema` one-shot mode of `winmux-nickel`, exec'd like `check`. | 02: "The `winmux` CLI execs the one-shot modes directly" |
| `monitor.name` and `monitor.builtin` when unknown | C | `""` and `false`. | |
| `class` when more than one applies; what `'fullscreen` means | B | One class per window, from its parent container, the same mapping `window-layout` prints: `getChildParentRelation` returns exactly one of `.tiling`, `.floatingWindow`, `.macosNativeFullscreenWindow`, `.macosNativeHiddenAppWindow`, `.macosNativeMinimizedWindow`, `.macosPopupWindow`. So `'fullscreen` is macOS native fullscreen; a window under WinMux's own `fullscreen` command stays in the tiling tree and is `'tiled`. A minimized floating window is `'minimized`. | `Sources/AppBundle/command/format.swift:193-206` (`toLayoutResult`) |

### 05-global-mru (2)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Sequence for the window focused at launch | C | Keep the startup early return; the first non-startup refresh assigns it. Harmless either way. | `focus.swift:197-199` |
| A CLI field for the sequence | C | Add `last-focused-seq` to `list-windows --json` and `%{window-last-focused-seq}` to `--format`; say so in the PR. | |

### 06-lens-core-and-list (18)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| How WinMux tells a Filter "names" a popup class | D2 | See the consolidated list. | |
| May `filter` be left out | A | Yes; it means every window. Both evaluated Nickel artifacts write `recent` without one. | prototypes/28-nickel-spike/config/config.ncl: "`recent      = { presentation = 'strip, sort = ['mru] },`"; same line in prototypes/27-config-language.html's Nickel tab |
| Enum spellings: hyphens vs underscores | D1 | See the consolidated list. | |
| `entries = app` in `'list` | C | A row shows icon, app name and window count; `focus` goes to the app's most recently focused window. | |
| `sections` in `'list` | C | Ignored, as the strip does. | |
| Look-setting defaults; which affect a `'list` row | C | The `overview` values (`'dimmed`, `'enlarged`, `['label, 'landing_spot]`) become the field defaults for every Lens, so records can omit them. A `'list` row ignores `frozen_thumbnail` and `accessory_window`; `'label` applies to the selected row. | 12: "The two `'strip` Lenses use the same three values." |
| `cmd-<n>`: palette badge; merge or replace `keys` | A for the binding, C for merging | The Lens default is decided; the palette's cmd-1..9 row pick and badge (`SwitcherPalette.swift:128-131`) go. A Lens's `keys` merges over the defaults field by field (Nickel record merge). | ticket 07: "The defaults are `enter` → `focus`, `shift-enter` → `summon`, `cmd-w` → `close` and `cmd-<n>` → `move-node-to-workspace <n>`." |
| First selection in `'list` | C | The second row when the first row is the focused window, else the first. (`r` opens `recent` as a list; starting on the current window would waste the keystroke.) | |
| How tiers and field weight combine into `score`; JSON key | C | `score` = sum over words of (tier weight × field weight), tiers 6..1, title and app weight 2, workspace and project 1; JSON key `matched-field`. | |
| Does Summon focus afterwards; floating, minimized, hidden-app | C | Yes, Summon focuses the window after `place`. A floating window moves and stays floating; minimized and hidden-app windows are restored the way `focus` restores them. | |
| Two budgets (50 ms box, 100 ms request) | C | The 50 ms is a UI deadline: show "Filter too slow" and keep the last result. The request runs on to the helper's 100 ms limit, where the hang rule applies. Both decided texts hold. | ticket 19: "Each evaluation gets a 50 ms budget"; ticket 31: "A Filter gets 100 ms" |
| `lens --filter` with a bad body | C | A parse or contract error: exit 2, nothing opens. A Filter that fails at run time or times out: opens with every window and the banner. | |
| Ad-hoc Lens default Presentation | C | `'list`. | |
| `lens <name>` while a Lens is open | B | `palette` toggles today (`PaletteCommand` runs `SwitcherPalettePanel.shared.toggle()`). Same name toggles; a different name replaces. | `Sources/AppBundle/command/impl/PaletteCommand.swift:9`, `SwitcherPalette.swift:70` |
| Disabled Lens exit code | C | 2. | |
| `when.<name>` for a name other than `default` | A | Kept inert, never applied. 10 already states it; 06 must match. | map.md Out of scope: "The `when.<profile>` override shape and the monitor-identity research stay decided, and the build runs with one implicit profile."; 10 Done-when: "a `when` record under any other profile name loads and never applies" |
| `list-windows` new flags vs the mandatory scope flag | B | The parser requires one scope flag today. New flags imply `--all` when no scope flag is given and intersect with one when it is. | `Sources/Common/cmdArgs/impl/ListWindowsCmdArgs.swift:67`: "Mandatory option is not specified (--focused\|--all\|--monitor\|--workspace)" |
| `'strip` and `'miniatures` before their issues land | C | The contract accepts them; opening one falls back to `'list` with a log line. | |

### 07-strip-and-cmd-tab (14)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Disable symbolic hotkeys 27 and 220 too | C | No. Carbon takes `cmd-backtick` on its own, and disabling them makes a hard kill take cmd-backtick down with cmd-tab. Add them only if a test shows Carbon losing. | research/25 §1: "Cmd-backtick is handled by AppKit inside the front app after Carbon has already matched the hotkey, so a Carbon hotkey takes it with nothing disabled"; §5 failure table: "After a `SIGKILL`, cmd-backtick goes dead along with cmd-tab" |
| How a non-activating panel receives keys | C | Keep `makeKey()` and drop only `NSApp.activate` (`SwitcherPalette.swift:98-99`), on the AppKit rule that a `.nonactivatingPanel` can become key without activating the app (not verified here; see "could not check"). The Trigger key and its shift variant arrive as Carbon hotkey events while open; esc, arrows and letters as key events to the key panel. No event tap. Verify under Secure Input. | research/03 §6, "Non-activating panel" row: "The strip must not call `NSApp.activate` the way `SwitcherPalette` does today." |
| Opening a strip with no modifiers held | C | Intended: it commits at once and swaps to the previous window. The no-modifier way to browse `recent` is the list, which is why the leader mode maps `r` to it. | ticket 29: "There is no stay-open mode; that's what `'list` is for."; ticket 34: "`r` → `recent` in the `'list` Presentation" |
| `cmd-shift-tab` with no strip open | C | Opens `recent` with the selection on the last entry, matching native. Ship `cmd-shift-tab = 'lens recent'` next to `cmd-tab`; the strip reads Shift in the invoking chord. | |
| A letter that is also a `keys` binding (`cmd-w`) | C | The `keys` binding wins; only letters with no binding hand off to `'list`. | |
| How Summon at release is spelled in `keys` | C | A default `alt-enter = summon` entry; releasing with Option runs it, which is the decided rule "unless a modifier held at release selects another binding" with nothing special-cased. | 07: "Committing runs the command bound to `enter` ... unless a modifier held at release selects another binding." |
| `accessory_window` and `'target_workspace` in a strip | C | `'enlarged` draws the tile at normal size with the dashed outline and "menu-bar app" caption (the prototype's look); `'actual_size` scales it down. `'target_workspace` draws nothing in a strip. | prototypes/29-strip-presentation.html: tile text "`${w.t \|\| (w.acc ? 'menu-bar app' : '')}`" and "`outline:1px dashed #fff8`" for `w.acc` |
| Arrow keys | C | Left and right move the selection, as the prototype does. | prototypes/29-strip-presentation.html: "`if (e.key === 'ArrowRight') return step(1); if (e.key === 'ArrowLeft') return step(-1);`" |
| One match or none | C | One: the selection is on it. None: the strip shows "No windows" and release does nothing. | prototype: "`sel: S.items.length > 1 ? 1 : 0`" |
| Summon hints for a same-workspace window | C | Shown only when the selection is on another workspace; a same-workspace Summon is a no-op. | prototype: "`frozen = w.ws !== curWs; const sm = sel && mods.summon && frozen;`" |
| How many entries fit before scrolling | C | As many as fit the screen width, capped at 9 to start; tune on the real build. | prototype: `<input ... id="max" value="9" min="3" max="20">` |
| Marker storage and visibility | C | Follow research 25 §5: marker in `UserDefaults`, check the `CGError` and read back, log `HotKey` registration failures, add a `winmux doctor` line. | research/25 §5 steps 3 and 7 |
| Restoring an id the user changed meanwhile | C | Restore only if the id is still in the state WinMux left it. | research/25 §5 failure table: "Re-scan on reload and restore only ids in the marker (optionally only if still unchanged)." |
| Secure Input and fast user switching | C | Test during the build; record in the PR. Not a decision. | |

### 08-thumbnails-and-miniatures (11)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| The backdrop setting's name, shape and home | C | `miniatures.backdrop = { darkness = 0.6, blur = true }`; the contract caps `darkness` at 0.95. The strip has no full-screen backdrop, so it lives in the `miniatures` record. | research/30: "Allow the grid backdrop 0% to 95% black." |
| Capturing before a hide | C | There is no hook before cmd+H; the last focus-out capture is what a hidden-app window shows, else the icon. | research/03 §5 item 4: "Hidden-app windows keep their last cached frame, or show the icon." |
| Which API call | A | `captureScreenshot`, as 01 decides and the research recommends; re-measure once. | 01: "Window capture uses ScreenCaptureKit's one-shot capture, `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`"; research/03 §5: "Use `captureScreenshot` for everything except native-fullscreen windows." |
| Native fullscreen on an inactive Space | C | Show the last captured frame or the icon; no `captureSampleBuffer` (per-call stream churn). | research/03 §2: "`captureSampleBuffer` churns streams ... leaked WindowServer memory" |
| Throttle interval | C | 800 ms per window, AltTab's number. | research/03 §3: "The just-focused window is also captured, at most once per 800 ms" |
| Telling a Frozen thumbnail from a fresh one | C | Treat every parked, minimized and hidden-app window as Frozen in v1; do not detect Safari-style freshness. | |
| Refresh cadence for current-workspace windows | C | Re-capture visible windows every 500 ms while the Lens is open, behind the 2-in-flight gate. | |
| `'age_badge` and `'pause_badge` looks | C | Use the grid prototype's styles (`.stale-age`: saturate 0.35, brightness 0.85, with an age badge; pause: a pause glyph). Only `'dimmed` was reviewed. | prototypes/08-grid-presentation.html: "`.stale-dim .body ... filter: brightness(.55)`", "`.stale-age ... filter: saturate(.35) brightness(.85)`" |
| `--presentation miniatures` on a Lens with `sections`, `entries` or `sort` | C | Ignore them. | |
| Capture privacy UI | C | A check, already listed in the umbrella; report the result. | |
| Real numbers | C | Re-measure on the real window set. | |

### 09-accessory-defaults-and-floating-lens (6)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| How "the Filter names them" is detected | D2 | See the consolidated list. | |
| Popup-class windows have no workspace | B | True: `macosPopupWindowsContainer` has a `NilTreeNode` parent, so `nodeWorkspace` is nil. Amend the contract so `workspace` is `""` for popup (and minimized) windows, and add the popup container to the Lens's window source when D2 says the Lens includes them. | `MacosUnconventionalWindowsContainer.swift:26-34` (`super.init(parent: NilTreeNode.instance, …)` at `:32`); `TreeNodeEx.swift:38-40` |
| Which popup class when it is not the close-button case | C | By the app's live policy: `'accessory` → `'accessory-popup`, anything else → `'app-popup`. | |
| focus and Summon on a popup-class window | C | `focus` raises it through `nativeFocus`; Summon refuses with a message (no workspace to leave). | |
| `floating` Lens sort | C | `['mru]`, like `search`. (Also asked in 12.) | |
| Reading `LSUIElement` | B | `DebugWindowsCommand.swift:78` already reads `Bundle(url:).infoDictionary`; read it once at app registration and accept a Bool, a number or a string. | `Sources/AppBundle/command/impl/DebugWindowsCommand.swift:78` |

### 10-fixed-columns (15)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Identifier spelling | D1 | See the consolidated list. | |
| Column index base | C | 1-based: tab indexes and workspace numbers are 1-based in the default config (`alt-1 = 'focus --tab-index 1'`), and the prototype's `place` returns `column = 3` on a three-Column workspace. | `resources/default-config.toml:83`; prototypes/27-config-language.html Nickel `place` tab |
| Minimum Column width | B | Reuse `minimumTiledResizeWeight`, 80 points. | `Sources/AppBundle/mouse/resize/TiledResizeConstraints.swift:5` |
| Default `width-presets` | A | `[1/3, 1/2, 2/3]`. | prototypes/27-config-language.html, Nickel overrides tab: "`width_presets = [1/3, 1/2, 2/3],        # exact rationals`" |
| `widths` omitted or the wrong length | C | Omitted: equal fractions `1/count`. Wrong length: a load error. | |
| Where `width-presets` can be set | A | Only on `columns`; it is global. (Logged in Job 1.) | ticket 09: "A profile declares the starting `widths` (fractions) and a global `width-presets` list." |
| Which Columns are "neighbours" | C | Every other Column, in proportion to its width. | |
| Free resize: proportional or equal | C | Proportional, the same operation as a preset change; equal amounts are what the research flagged as breaking fractions. | research/04 §4 item 2 |
| Stepping from a non-preset width | C | `next` picks the smallest preset above the current width, `prev` the largest below; both wrap. | |
| Which child the invariant pass folds | C | The root child without a slot index, folded with the built-in placement. | 10: "The pass folds any root child beyond the count into a Column, using the built-in placement below." |
| "Nearest" empty Column | C | Index distance from the focused Column; a tie goes left. | |
| `move up`/`move down` at a Column's top or bottom | C | Stop, like the horizontal edge. | |
| `auto-add-new-windows-to-tab-group` on a Columns workspace | C | Ignored there; built-in placement decides. Still applies with `count` off. | `Config.swift:61` |
| Config reload | C | Reset widths to the declared `widths`; fold extras through the invariant pass, as `column-count` does. | |
| Gaps next to an empty Column | C | Reserved, so occupied Columns do not shift when a neighbour empties. | |

### 11-column-hooks-and-commands (15)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Identifier spelling | D1 | See the consolidated list. | |
| Result field names | A | `workspace`, `float`, `column`, `overflow`, `run`, `action`, as prototyped and spiked. | prototypes/27-config-language.html returns tab: "`{ workspace = "comms", column = 3, overflow = 'tab_group }`", "`{ workspace = "comms", column = 3, run = ["layout tabs"] }`"; boundary tab: "`{ action = 'join, overflow = 'tab_group }`"; arrival tab: "`{ float = true }`"; prototypes/28-nickel-spike/config/winmux.ncl `Placement_` |
| A hook that raises or breaks its contract | A for the behaviour, C for telling the user | Falls back to the built-in behaviour like a timeout. Log it and show it as the last error in `config status`; no notification per call. | 02: "A timed-out, failed or unanswerable request returns a failure with the diagnostic, never a stale result. ... a Policy hook falls back to the built-in behaviour as if no hook were configured." |
| A Column index out of range | C | Treated as a contract failure: built-in placement for hooks; exit 2 with a message for the commands. | |
| Hooks with `count` off | C | `place` and `move-boundary` do not run; `arrive` runs with `cols = []`. | |
| Which Columns `arrive` receives | A | The detected workspace's Columns; after routing, `place` is called again with the target's. | prototypes/27-config-language.html arrival tab: "`arrive = fun w ctx cols => ... else columns.place w ctx cols`"; ticket 27: "WinMux routes first, then calls `place` with the target workspace's Columns." |
| Overriding the Accessory float | C | `float = false` in the `arrive` result. | |
| Which paths run which hook | C | Every tiling arrival runs `place` (float-to-tile, un-minimize, leaving native fullscreen, cache restore, `move-node-to-workspace`, drag and drop); only detection runs `arrive`. | ticket 09: "`place` runs when a tiling window arrives on the workspace" |
| `run`: target window; Summon; `--dry-run` | B | Upstream targets the detected window; keep that for every hook. `run` executes for a Summon (it is an arrival) and never for `--dry-run`. | `Sources/AppBundle/tree/WindowDetectedCallbacks.swift:22`: "`callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)`" |
| `squeeze` width and lifetime | C | The extra Column gets the sibling average, taken proportionally from the others; the invariant pass removes it when it empties and re-applies the declared widths. | |
| `move-node-to-column` into an occupied Column | C | `tab-group`, the built-in Overflow action. | |
| `compact` direction and widths | C | Pack toward Column 1; widths stay with the slots. | |
| `column-count` scope | C | The focused workspace; extras fold through the invariant pass. | |
| `list-columns` scope and JSON keys | C | The focused workspace by default, `--workspace <name>` otherwise; keys `index`, `width`, `empty`, `window-ids`. | |
| `place --dry-run` output | C | One line per decision (`column 2 (focused), overflow tab-group, hook columns.place`) and `--json`. | |

### 12-default-config-and-triggers (11)

| Open detail | Bucket | Answer | Citation |
|---|---|---|---|
| Identifier spelling | D1 | See the consolidated list. | |
| Where the defaults live | D3 | See the consolidated list. | |
| How a user config layers over the defaults | D3 | See the consolidated list. | |
| `config-version` | C | Drop it. The Nickel contract replaces it, and the one thing it gates today (`persistent-workspaces`, `parseConfig.swift:161`) needs no gate in a new format. | `resources/default-config.toml:1`, `parseConfig.swift:46,161` |
| Producing the Nickel defaults | C | By hand, once; a test checks that `config convert resources/default-config.toml` yields the same static JSON. | |
| Named Filters in the default config | A | Named, under `filters`: `same_app` for `app-windows` and a floating Filter, as prototyped. | prototypes/27-config-language.html Nickel tab: "`same_app = fun w ctx => ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId`", "`app_windows = { presentation = 'strip, filter = filters.same_app, sort = ['mru] }`" |
| `floating` Lens sort | C | `['mru]`. | |
| Leaving the `lens` mode | C | Each binding is a command list, `lens` first then `mode main`: `o = ["lens overview", "mode main"]`. Upstream accepts a list for callbacks (`on-focused-monitor-changed = ['move-mouse monitor-lazy-center']`); that bindings take the same form is AeroSpace convention, not verified here against the binding parser (see "could not check"). | `resources/default-config.toml:15` |
| Event payload field names | C | `config-reloaded`: `ok`, `error`, `config-path`. `lens-opened`/`lens-closed`: `lens`. `columns-changed`: `workspace`, `count`, `widths`, `occupied`. Existing events carry `windowId`, `workspace`, `appBundleId`, `appName`; follow whichever casing their JSON encoder emits. | `Sources/AppBundle/model/ServerEvent.swift:25-42` |
| Ad-hoc Lenses in events | C | `lens` is `null` and a `filter` field carries the name or body. | |
| `lens-closed` on re-presenting | C | Nothing: one Lens, one open and one close. | |

## Consolidated D list, most blocked first

1. **Identifier spelling: hyphens or underscores in Nickel field names and enum tags?** Raised in 06, 10, 11, 12; also 02's "How the settings WinMux already has are named in Nickel". Blocks the shipped contract, every example in every issue, every Done-when that writes a key, and `config convert`. The decided texts disagree: ticket 33 writes `'hidden-app`, `'accessory-popup`, `'app-popup`; ticket 09 writes `width-presets`, `move-boundary`, `tab-group`, `nearest-empty`; ticket 34 writes `app-windows`; ticket 08 writes `'age_badge`, `'landing_spot`, `'actual_size`, `'by_workspace`; and every Nickel artifact that was actually evaluated uses underscores (prototypes/28-nickel-spike/config/config.ncl: `app_windows`, `'accessory_popup`, `'tab_group`, `'nearest_empty`, `columns.move_boundary`; the same in prototype 27's Nickel tab, whose Errors tab shows real nickel 1.18 output). The hyphenated forms appear only in prose. Recommended: underscores for everything the fork adds (fields, hook names, enum tags, Lens names), since that is what was evaluated and what Nickel's own stdlib uses, and the CLI keeps kebab-case command names (`move-node-to-column`, `column-width`) and key chords (`cmd-tab`). Inherited upstream keys (`workspace-sidebar`, `enable-normalization-flatten-containers`) stay kebab unless Prateek wants `convert` to rename them, which is the one cost of this choice: a file with both styles. Alternative: kebab everywhere, which keeps the inherited keys uniform and matches the tickets' prose, at the risk that `-` inside identifiers is awkward or illegal in Nickel (unchecked here).

2. **How does a Lens opt into popup-class windows?** Raised in 06 and 09. Blocks the Lens window source, the smoke run's inputs and the `floating` Lens. The decided rule is "unless the Filter names them" (ticket 06: "They appear only when the Filter mentions them."; ticket 11: "Lenses drop them unless a Filter mentions them"), written when a Filter was a CEL string. A Nickel function's result cannot show what it "names", and ticket 24 already judged that "spotting references inside Nickel functions is hard" and chose no reference gating for tabs. Recommended: an explicit Lens field, `popups = ['accessory_popup]` (default `[]`), which changes the decided mechanism from "the Filter names them" to "the Lens asks for them"; the Filter still decides per window. Alternative: the helper scans the Filter's parsed term for the two tags at load, following `filters.<name>` references, and reports the result with the static config; it keeps the decided wording but is the kind of reference-spotting ticket 24 rejected.

3. **How does a user's config layer over the shipped defaults, and where do the defaults live?** Raised in 12 (two rows) and implied by 02's "Where built-in defaults come from". Blocks 12, the starter config and the output of `config convert` (does a converted TOML config still get the five Lenses and the `lens` mode?). Recommended: the defaults are a shipped Nickel file the starter config imports and merges over explicitly, `(import "winmux/defaults.ncl") & { … }`, with no implicit merging; `config convert` emits that import line; a user who wants a total config deletes it. This follows 02's own rule that merge operators are only for layering files: "Nickel's `&`, `| default` and `| force` are how a user layers one config file over another. WinMux gives them no other meaning." Alternative: `| default` values inside the contracts file, so every user config merges over the defaults implicitly; simpler to write, but a default binding or Lens can then only be removed by overriding it (`enabled = false` for a Lens; nothing for a binding).

4. **What happens to the Settings panes that edit the config file in place?** Raised in 02 and 03. Blocks nothing until 02's implementer touches `Sources/AppBundle/ui/settings/`, but it is a visible feature: `ConfigSettingsViews.swift:46` writes `auto-reload-config` back to the TOML, and the shortcut recorder views (`ShortcutSettingsConfigEdits.swift`, `ShortcutSettingsModelReload.swift`) edit bindings in place. Recommended: make the panes read-only in v1 (show the loaded values, add an "Open config" button that launches the editor) and say so in the PR; a Nickel patcher is a project of its own. Alternative: remove the panes outright.
