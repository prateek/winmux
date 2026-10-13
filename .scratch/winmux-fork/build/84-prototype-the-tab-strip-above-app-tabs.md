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

- [ ] A prototype under `.scratch/winmux-fork/prototypes/` showing today's strip and the three alternatives over Chrome, VS Code and a terminal.
- [ ] Stock macOS window tabs captured beside them.
- [ ] A recommendation and a draft issue for the look he picks.

## Sources

- Prateek, 2026-10-07: "for the tabs up top, the button/lines on the right side feel weird"; "it feels disjointed to have tabs in both it and applications like chrome/orca/vscode/etc".
- Prateek, 2026-10-13: the grip is what feels weird; the three alternatives above. He did not ask for tabs in the title bar area.
