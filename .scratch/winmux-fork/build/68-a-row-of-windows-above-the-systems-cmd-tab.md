# Prototype: a row of windows above the system's Cmd-Tab

Part of {{UMBRELLA}}.

## What to build

With the system's Cmd-Tab left alone, a person lands on an app and not on a window. DockDoor has an option that fills the gap without taking the key: while the system's switcher is up, it draws a row of the highlighted app's windows above it, and a second key moves into that row.

Build a throwaway prototype of the same idea in WinMux and report whether it is worth an issue.

## Decisions

- **The system's switcher is not replaced, disabled or drawn over.** WinMux adds a panel above it and removes it when the switcher closes.
- **The row shows the highlighted app's windows**, with the workspace each is on. Choosing one focuses it, on a hidden workspace too.
- **With nothing chosen in the row, release does what the system does.**
- **Off by default**, behind one setting.
- **A prototype answers questions; it does not ship.** No code or asset of DockDoor, which is GPL-3, is copied. Its behaviour was observed and its approach read.

## Questions to answer

- Can WinMux read which app the switcher has highlighted? DockDoor reads it from the Dock's accessibility tree, through an element with an undocumented subrole. Does that work on macOS 26 and 27, and how late is the first reading after Cmd-Tab goes down?
- Which key moves into the row? DockDoor uses Cmd-A. Does taking one key while Command is held need the event tap, and does it disturb the system's switcher?
- What happens under secure input, and when the Dock restarts?
- Two faults seen in DockDoor to avoid: a click on a preview closed the system's switcher, switched nothing and left the row on screen; and moving the pointer up to the row crosses the system's icons, which follow the pointer and change the highlighted app.

## Depends on

- **The system's Cmd-Tab stays the system's unless the config asks for it**.

## Done when

- [x] A prototype under `.scratch/winmux-fork/prototypes/` that runs in a guest, with a capture of the row following the highlighted app.
- [x] Each question above answered in its README, with what was run.
- [x] A recommendation: build it, with a draft issue; or drop it, with the reason.

## Prototype result

The standalone Swift experiment is in `.scratch/winmux-fork/prototypes/32-window-row-above-cmd-tab/`, with its README, two small captured stills and guest drivers. It adds no shipped WinMux behavior, setting or test. Host and Swift-6.4 guest `make check` passed; the first pass also compared separately built base/head native-switcher behavior and inventory.

**Build it**, if Prateek accepts the change to a Decision below. The row is not on screen within the strip's 150 ms of the key, but neither is the system's switcher, first readable 172–180 ms after Tab in the guest; the row is judged by how far it trails the switcher. Across twelve follow-up openings on macOS 26.6.2, the first row ordered 0.785–11.291 ms after the first readable system highlight, with a 1.692 ms median. Snapshot work begins at opening Cmd-Tab and overlaps the Dock's delay. Five frame-timestamped openings show the row zero or one frame after the visible system switcher. A quick tap discards its snapshot without presenting or retaining a session.

Rows now filter by the selected process, using a unique title where possible; the two same-name Ghostty icons were verified separately against native release using observed activation order. Their AX buttons expose neither pid nor AXURL, so the prototype pairs same-name icons with processes by the activation order it has watched, and shows no row until it has seen every such process. That pairing is a heuristic; the feature draft calls for validating it.

A single Safari process has windows on workspaces 2 and 3. Leaving release to the system still flashes the workspace-2 window before focusing the chosen workspace-3 window. The alternative closes the system switcher with Command-Escape on Cmd-A, keeps the row independently, swallows Tab/arrows and focuses directly on release. It closed without switching, stayed closed across swallowed Cmd-Tab and first sampled the chosen focus 252.275 ms after release; the external CLI call occupied 173.393 ms. Its film shows the source transitioning directly to the chosen workspace, without the other Safari window. No in-process latency is claimed.

The recommendation chooses that explicit handoff. It changes this issue's Decision that the row is removed when the switcher closes: once entered, the row outlives the switcher and takes Tab for the rest of the Command hold. That change is put to Prateek, and the feature issue waits on his answer. Secure Input hides the row and leaves the system switcher alone, verified with the owned secure-input probe. Escape, paired key-up handling, delayed focus tokens, empty/pending entry, scoped logging, timeouts, observer retry handling, snapshot parsing and coordinate conversion were corrected. Before/after live logs reproduce the Escape, key-up, stale-focus and empty-entry faults; the bare-Command fading-list race and the other defensive fixes were not reproduced as failures.

The feature draft is **A window row above the system switcher**, `114-a-window-row-above-the-system-switcher.md`. It preserves off by default and calls for extending MissionControlState's Dock observer, per-process rows, character-based Cmd-A and the Secure Input policy. macOS 27, the installed build and a real keyboard remain unrun; a second display and real sleep/wake/unlock remain Prateek's. These limits are acceptance items in that feature draft, not additions to this prototype's three Done-when items.

## Sources

- The switching comparison, 2026-10-09: DockDoor 1.40.7 in a guest, and its source read at the same tag.
- Prateek, 2026-10-13, choosing who owns Cmd-Tab: Apple's switcher, WinMux's open view, "plus a window row above Cmd-Tab".
