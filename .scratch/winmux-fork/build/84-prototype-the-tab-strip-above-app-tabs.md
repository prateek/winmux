# Prototype: the tab strip above apps that have tabs of their own

Part of {{UMBRELLA}}.

## What to build

A WinMux tab group draws a strip of tabs above its windows. Chrome, VS Code and Orca draw their own tabs directly beneath it, and Prateek finds the two rows disjointed. He also finds the grip at the right of the strip weird: the short lines that drag the whole group.

Build a throwaway prototype of other looks for the strip, beside stock macOS, and bring him a choice.

## Decisions

- **He decides from pictures.** Prateek: "i have to see prototypes of all compared to baseline osx to understand".
- **Three alternatives, beside today's strip**: a thinner, quieter strip; a strip shown only while the tab digits' modifier is held, with the number hints; and no strip, with a tab group's windows shown only in the sidebar.
- **The grip goes or becomes a clear handle.** Show both.
- **A prototype answers questions; it does not ship.**

## Questions to answer

- Without the grip, how is a whole group dragged?
- With no strip at rest, how does a person see that a window is in a group, and reach its other tabs with the pointer?
- With groups only in the sidebar, what does the collapsed sidebar show for one? This leans on **Prototype: the sidebar as a tree**.
- How does each look beside macOS's own window tabs and beside a browser?

## Depends on

Nothing.

## Done when

- [x] A prototype under `.scratch/winmux-fork/prototypes/` showing today's strip and the three alternatives over Chrome, VS Code and a terminal.
- [x] Stock macOS window tabs captured beside them.
- [x] A recommendation and a draft issue for the look he picks.

## Built and checked

The static, disk-opened page at `prototypes/84-tab-strip/index.html` compares
Today, Thin and quiet, Only while held and Sidebar only over real guest captures
of Chrome, VS Code and Ghostty, with both grip treatments. Notes, metrics and
light/dark page tokens follow the Lens look prototype. No native feature ships.
The README opens with same-scale pick pictures and recommends a 24-point Thin
and quiet strip with the grip gone. The recommendation and
`build/129-thin-quiet-tabs-above-grouped-windows.md` satisfy the draft item above;
that draft is for the recommended look and waits on Prateek's pick, which may
replace it.

Native rest, tab-hover, grip-hover and Option-held captures cover all three apps
in one group at 1920 × 1080. Ghostty's three macOS tabs expose three AX windows,
so the actual group has five entries across the three apps; the page retains
that ordering and count. The 36-point strip and 3-point side/bottom shell agree
with native bounds; source-read subpixel metrics are distinguished from measured
edges. The full group frame is pictured. Both empty chrome after the last tab
and the 28-point gutter moved all five leaves to a new workspace, confirmed by
the preview, final window lists and raw agent trees. The existing sidebar group
header is the alternate whole-group drag target.

Finder and ungrouped Ghostty each show three stock macOS tabs at the group size.
The page's collapsed and expanded sidebar crops come from the real debug build
of **The sidebar as a tree**, which has since been built; the older prototype's
page is not substituted. Orca is skipped because it is not installable in the
guest. The README answers each question, tabulates added space over every app
and distinguishes native title chrome from WinMux's added height.

All 46 geometry/hint self-check rows pass in headless Chromium and guest Safari.
Forty-four browser checks exercise the offered interactions and 24 app/look/grip
combinations; a deliberately wrong Thin height fails the expected geometry rows
and restoration passes. Guest Safari captures all 24 combinations, actual held
reveal/release, app switching, tab/handle hover and sidebar expansion. Its 24
selection readbacks agree with their capture names. The 500 ms hold follows the
actual source reducer: key/click activity spoils a pending reveal, while activity
after display keeps the hints usable until release.

Host and pinned Swift 6.4 guest `make check` pass, with 1,741 Swift tests,
92 helper/Rust tests and 171 script tests; the guest's existing committed-hash
test skips its sync commit. These are local checks, not GitHub CI. Nothing under
`Sources/`, `nickel-helper/`, `script/` or `docs/` changed. The prototype remains
below 5 MB. The builder publishes no release; installed-build and hardware
acceptance belongs to the picked feature.

## Sources

- Prateek, 2026-10-07: "for the tabs up top, the button/lines on the right side feel weird"; "it feels disjointed to have tabs in both it and applications like chrome/orca/vscode/etc".
- Prateek, 2026-10-13: the grip is what feels weird; the three alternatives above. He did not ask for tabs in the title bar area.
