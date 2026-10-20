# Window marks builder checks

Use only the assigned guest and the VM wrapper, with the driver's `TART_HOME`
exported in every host shell. Sync and build, run `vm check`, push the standing
desk directory, and stage it with `desk/stage-desk.sh`. Inspect the desk screenshot
before running either probe. Never answer permission prompts.

Run `live.zsh` over `vm ssh` after staging. It uses the debug CLI and requires the
four-window desk on two workspaces. It saves command results and exit codes,
screenshots, focus readbacks, complete window lists and agent trees under
`takes/window-marks` in the guest. It checks mark/jump, four confirmed focus-back
switches, listing, empty-register failure, minimized restoration and closed-window
failure. It closes the staged Zed window.

Then run `extra.zsh` over `vm ssh`. It moves marked Ghostty to another workspace,
captures the source before jumping, hides/unhides it, reassigns a second register,
checks parse-error exit codes and restarts the debug app to check process-local
marks and empty history. Results go under `takes/window-marks-extra`. Numeric
workspace arguments are ordinals: after an empty workspace disappears, use the
agent inventory's raw names and display names together when reading these takes.

Both probes wait fixed intervals before reading state; neither polls WinMux while
waiting for refresh. Inspect every image against its window list and agent tree,
including the source screen after a move. Pull the directories with `vm pull`.
Quit debug WinMux before closing the desk apps, and leave the assigned guest up.

The builder checked these scripts against the command implementation in this
branch. Captures and full host/guest check logs live in the relay's artifacts;
final-commit public demos are a separate pass. Installed builds, physical displays
and real sleep/wake/unlock remain the person's checks.
