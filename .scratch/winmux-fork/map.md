# Map: Prateek's WinMux fork

Labels: wayfinder:map

## Destination

A spec per feature for a personal WinMux fork that Prateek runs daily in place of AeroSpace, detailed enough to hand to an implementing agent. The features are filtered Pickers (grid, strip, and a cmd-K style search that finds windows to focus or Summon), fixed Columns with Width presets, Display profiles for switching between the laptop and the ultrawide, and a `winmux` CLI that can drive all of it. Upstream acceptance doesn't constrain the design.

## Notes

- Domain: macOS window management. WinMux is an AeroSpace fork (Swift, i3-style tree, AX-based). Code lives at the root of this repo; the glossary is `CONTEXT.md`. Use its terms (Picker, Filter, Presentation, Trigger, Picker binding, Summon, Column, Width preset, Overflow policy, Display profile).
- Skills for every session: `grilling` + `domain-modeling` for HITL tickets. Resolve research tickets through the `research` skill, writing findings to `.scratch/winmux-fork/research/<ticket-slug>.md` (local tracker, so notes go there, not on branches).
- Standing decisions from charting (2026-09-28):
  - Exposé, cmd+tab, and "can't find floating windows" all collapse into one model: Picker bindings = Trigger + Filter + Presentation (grid or strip), with grouping and sort per binding. The default is windows in MRU order for the strip and grouped by workspace for the grid.
  - Filters must read the Filter context (focused window and app, window and app under the mouse, workspace, project, monitor, previous window, Display profile) as well as window attributes. The language must be better than plain TOML fields. The current lean is JS predicates via JavaScriptCore; the prototype ticket decides.
  - Picker actions: focus by default, Summon on a modifier.
  - Gestures: WinMux intercepts trackpad gestures itself (not BetterTouchTool).
  - AltTab (GPL-3) is inspiration only. Study its design and implementation, but write our own code on top of WinMux's `SwitcherPalette` HUD, so the fork stays MIT. The same goes for the gesture tools: BetterCmdTab, jitouch and MiddleClick are GPL-3 (inspiration only), while yabai, aerospace-swipe and OpenMultitouchSupport are MIT (reusable).
  - Columns: a fixed Column count per Display profile plus cycling Width presets. The Overflow policy is configurable per Display profile, defaulting to tab group.
  - Displays: one at a time (clamshell ultrawide, or laptop only). The display side is glue: `g95nc` stays the BetterDisplay driver, and WinMux reacts to display changes.
  - Screen Recording permission is fine, so grid thumbnails are live.
  - Everything is scriptable (added 2026-09-29): every fork feature (Pickers, Filters, Columns, Display profiles) gets `winmux` subcommands with machine-readable output, alongside the AeroSpace-inherited commands for moving windows and changing layouts, so users can drive WinMux from scripts. Each feature spec includes its CLI surface.
  - The cmd-K search (added 2026-09-29) grows out of the existing `winmux palette` (`SwitcherPalette`), which already fuzzy-searches app name, title and workspace and focuses the pick.
- Dotfiles context: `~/dotfiles/home/dot_config/raycast/scripts/executable_g95nc.sh`, `~/dotfiles/docs/plans/betterdisplay-display-modes-plan.md`.

## Decisions so far

<!-- one line per closed ticket: [title](issues/NN-slug.md): gist -->

- [Research: WinMux layout engine seams for fixed Columns](issues/04-research-layout-engine-for-columns.md): Columns = children of an `h`/tiles root, no new Layout case; Overflow policy hooks new-window insertion; a Column-invariant pass after normalization must counter flatten-replacing-root, point-based width redistribution, and balance/resize. Width presets must be stored as fractions.

- [Research: how WinMux sees Accessory app windows](issues/02-research-accessory-app-windows.md): Accessory apps get registered only after being frontmost once, and their close-button-less windows become invisible popups. Filters covering them need proactive registration, opt-in popup inclusion, and activation policy, subrole and level exposed as attributes.

- [Research: monitor identity and display-change handling for Display profiles](issues/05-research-monitor-identity-and-display-change.md): WinMux has no stable monitor identity. Match profiles on CoreGraphics descriptors: built-in flag for the laptop; UUID or vendor/model/serial for the physical Odyssey and the pinned `G95-HiDPI` virtual screen; name regex as fallback. Apply on the settled `refreshMonitorPolicy` pass and at startup, with a new `displayProfileChanged` event, because a laptop/ultrawide swap fires no existing event.

- [Research: live thumbnails for parked windows, and AltTab's implementation](issues/03-research-thumbnails-and-alttab.md): ScreenCaptureKit's one-shot capture (macOS 26+) gets parked and minimized windows but not hidden-app ones, serially at about 40 ms each. So: a per-window thumbnail cache filled on park or blur, visible tiles refreshed first. Adopt AltTab's per-shortcut filter vocabulary, release styles, 100 ms strip delay, non-activating panel, and MRU written after focus is confirmed. WinMux needs a new global MRU.

- [Grilling: raise the fork's minimum macOS to 26?](issues/15-grilling-deployment-target.md): yes, target macOS 26; no `#available` gating, drop `CGWindowListCreateImage`.

- [Research: in-app trackpad gesture interception on macOS 26](issues/01-research-gesture-interception.md): read raw frames from private MultitouchSupport (`dlopen`, restart on wake and hot-plug), as BetterTouchTool and jitouch do. Reading frames doesn't block the system gesture, so the conflicting system swipes get turned off and a finger-down-only scroll tap drops the leak. Swallowing DockSwipe events stays an off-by-default experiment.

- [Research: reading tabs from browsers and tabbed editors](issues/18-research-reading-app-tabs.md): `w.tabs` is a per-window cache filled off the main thread and refreshed when a Picker opens, never read live. Chrome-family browsers come through AppleScript (an Automation grant per browser, mapped to windows by title plus bounds), native `NSWindow` tabs are already WinMux windows that need grouping, and VS Code-family editors expose only the title and `AXDocument` without an extension. `AXEnhancedUserInterface` and CDP are rejected; the AX tab strip is a titles-only fallback. Recommended shape: a registered tab-provider interface (pull command or `winmux tabs publish` push, one versioned schema), so sidebar apps like Orca and cmux plug in through their JSON CLIs without WinMux code.

- [Prototype: filter language worked examples](issues/06-prototype-filter-language.md): Filters are CEL (cel-js in JavaScriptCore), type-checked when the config loads. `floating` keeps today's meaning; popups split into `accessory-popup` and `app-popup` classes that Pickers drop by default. Sort and Display-profile gating live on the Picker binding. Filters are named in a `[filters]` table or written inline, and call each other as functions.

## Not yet specified

- **Filter language runtime details**: evaluation cost of CEL per Picker open across ~50 windows, how a Filter that fails `env.check` on reload is reported (keep the last good config?), hot reload, and the cel-js version pin and upgrade policy. The language is decided (see the filter-language prototype). (CLI exposure moved to [Grilling: CLI surface for the fork's features](issues/20-grilling-cli-surface.md).)
- **Strip Presentation visuals and keyboard model**: hold and release semantics, reverse cycling, type-to-search inside a Picker, how Summon's modifier is shown. AltTab's three release styles (focus, hold, search) and its 100 ms display delay are the starting point (see the thumbnails research). Also: is a gesture Trigger a discrete open, or a continuous swipe-and-hold that cycles the strip and commits on lift? Waits on the Picker binding shape and the grid prototype.
- **Tab-aware Pickers**: whether tabs from Chromium browsers and editors show up only as window attributes (`w.tabs`, searchable when typing in a Picker) or as their own Picker entries, and how choosing one focuses the window and then switches to the tab. AltTab doesn't do this ("Not possible technically", its issue #5155). The research is done (`w.tabs` is a cache; routes differ per app family). Native macOS tabs graduated to [Grilling: grouping native macOS tabs in Pickers](issues/22-grilling-native-tab-grouping.md); apps plug in through [Grilling: tab provider interface](issues/24-grilling-tab-provider-interface.md); browser tabs as Picker entries or attributes waits on [Prototype: Chrome-family AppleScript tab source](issues/23-prototype-chrome-tab-source.md).
- **Capture privacy UI**: whether frequent background ScreenCaptureKit captures on macOS 26 show a screen-recording indicator or other privacy prompts. Unverified.
- **Gesture fragility over time**: private MultitouchSupport drift, silent death after sleep, and the DockSwipe event format apparently changing in macOS 27 (matters only if the suppressor ships).
- **Region share for Zoom (stretch)**: DeskPad-like, where a workspace or Column is presented as a virtual display that Zoom can share. It's unclear whether that belongs in WinMux or in BetterDisplay glue, and it needs its own research once the core features are clear.
- **Prior art on `prateek/winmux@codex-columns`**: 153 commits of Prateek's earlier fork work (columnar zones, column decks, scenes, `[[rules]]` routing, a zone-expose overview, ultrawide docs, perf comparisons), built on an older upstream base. This map is based on upstream `main` by choice (2026-09-28), so treat that branch as prior art to mine when specifying Columns, Display profiles and the grid, not as the code being changed. It's unclear which of its decisions still hold.
- **AeroSpace migration gaps**: anything in Prateek's current AeroSpace config (callbacks, `on-window-detected` rules) that WinMux's importer drops or that conflicts with Columns. Includes ordering: the new-window binding runs before on-window-detected rules, so Overflow placement may need to wait for them.

## Out of scope

- Scrolling-column layouts in the niri/PaperWM style: ruled out at charting in favour of fixed Columns inside the existing tree.
- Building `displayctl` or BetterDisplay split/PIP modes: that's a dotfiles effort. This map only consumes whatever displays appear.
- Changes to AeroSpace itself, and shaping work for upstream acceptance.
