# Tab-hint builder proofs

Run in the assigned 1280 × 720 guest through `vm`, with `TART_HOME` exported in each host shell. These are builder checks; final-commit demos belong to the relay's demo pass.

1. Sync, check and build the worktree. Run `tab-nine-last/stage.zsh` with `WINMUX_DEBUG_STRIP_EVENTS=1` to launch the debug app on defaults and twelve explicitly ordered stage windows. Inspect its screenshot for permission prompts before continuing.
2. Push this directory to `~/tab-hints-proof`. Compile `scroll.swift` there. Run `live.zsh twelve`, then `last`, then `three`. The last-tab take scrolls horizontally while Option stays held; it does not change overflow behavior.
3. Run `live.zsh two-groups` to add three windows and explicitly replace the workspace layout with two groups. Use `split-groups` to retry the layout without opening more windows. A simple `createTabGroup` on newly opened windows is insufficient: they initially join the focused group.
4. Validate `control.ncl` with `WINMUX_NICKEL_HELPER` set for the debug CLI, copy the literal file to the active isolated XDG config path, reload and run `live.zsh remapped`. It checks Control digits, Option-Q, a pointer move during the deadline and Option-slash opening Search. Retain the Search matches JSON, trace, screenshot and row order in the capture index.
5. Build the base tree separately after `vm push`, including its Sparkle framework. Run `tab-nine-last/unchanged.zsh` against each staged tree and compare transcripts. Expected titles are Tab08, Tab09, Tab08 and Tab08; the last command fails out of range.

Every take writes a movie, key log, end screenshot and focused-window readback under `~/takes/tab-hints`. A timed interrupt bounds a recorder that does not stop at its requested duration. Verify the resulting movie before accepting it. Preserve screenshots before and after the deadline, inspect all quick/spoiled-chord frames, and reject any take with a permission prompt. Quit the debug app before closing the owned stage windows, remove only the isolated config created for this run, and leave the assigned guest running.
