# Prototype: the tab strip above apps that have tabs of their own

Part of {{UMBRELLA}}.

## What to build

A WinMux tab group draws a strip of tabs above its windows. Chrome, VS Code and Orca draw their own tabs directly beneath it, and Prateek finds the two rows disjointed. He also finds the controls at the right of the strip weird, and has not said which or how.

Build a throwaway prototype of other looks for the strip, beside stock macOS, and bring him a choice.

## Decisions

- **He decides from pictures.** Prateek: "i have to see prototypes of all compared to baseline osx to understand".
- **A prototype answers questions; it does not ship.**

## Questions to answer

- What are the controls at the right today, what does each do, and which could go or move?
- Which looks reduce the two-rows-of-tabs effect: a thinner strip, tabs in the window's title bar area, the strip shown only while a modifier is held, the group shown only in the sidebar?
- How does each look beside macOS's own window tabs and beside a browser?

## Depends on

Nothing.

## Done when

- [ ] A prototype under `.scratch/winmux-fork/prototypes/` showing today's strip and three or more alternatives over Chrome, VS Code and a terminal.
- [ ] Stock macOS window tabs captured beside them.
- [ ] A list of the right-side controls with what each does.
- [ ] A recommendation and a draft issue for the look he picks.

## Sources

- Prateek, 2026-10-07: "for the tabs up top, the button/lines on the right side feel weird"; "it feels disjointed to have tabs in both it and applications like chrome/orca/vscode/etc".
