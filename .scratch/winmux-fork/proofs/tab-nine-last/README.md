# Tab digit proof tools

Run these in the assigned 1280 × 720 guest through `vm ssh`, after `vm sync`, `vm check` and `vm build`. They use the shipped defaults without a config file. `stage.zsh` compiles the demo skill's plain-window and physical-key tools, launches twelve owned windows, and puts them in explicit Tab01–Tab12 order through the agent API. Discovery order is otherwise unspecified. It waits a fixed interval before its first readback to avoid cancelling a discovery refresh.

1. Run `zsh stage.zsh`, then inspect `~/takes/tab-nine-last/staged.png` for any permission prompt before continuing.
2. Run `zsh unchanged.zsh` against the base and feature builds. Set `WINMUX_TREE` and `PROOF_OUT` for the base tree, built separately after `vm push`. Compare the transcripts: eighth position, next, previous and out-of-range failure must match.
3. Run `zsh keys.zsh`. It asserts twelve-tab Option-9/Option-8, closes tabs four through twelve, then asserts three-tab Option-9 and out-of-range Option-8. It saves a screenshot and focused-window readback after each press, plus key-event logs. Its transcript includes `last`, `0` and `first` and their exit codes.
4. Run `zsh notes.zsh prepare`, inspect `notes-before.png`, then `zsh notes.zsh press`. The latter clicks the note body, presses Option-0, asserts `º` in the Notes AppleScript body readback and compares WinMux focus before/after.

Stop for a permission prompt for WinMux or its driving tool; grant nothing. The scripts do not answer prompts. No Search is used. Final-commit demos are a separate pass.

At the end, quit WinMux before closing the owned stage windows and Notes. Delete only the created **Tab digit check** note, leave the guest running and copy the captures out with `vm pull`.
