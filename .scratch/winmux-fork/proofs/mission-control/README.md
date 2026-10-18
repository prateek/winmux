# Mission Control proof tools

Run these tools only in an assigned guest, through the `vm` skill. Set the required `TART_HOME` on the host first. Use the fourteen-window rich desk at 1920×1080. Start no debug build on the host.

`live.zsh <label> <guest-source-root>` restarts that source tree's debug build against the staged rich desk and records Mission Control with collapsed/expanded sidebar, mode HUD and Lens. It warms every workspace, uses the native-arrow helper and reads back the final fourteen-window inventory. Run the same file against an archived base and the branch. Both roots need a `.git` directory and a debug executable with Sparkle beside it. The archived base's `.source-commit` must contain the full host commit hash before `make generate` and building.

`interact.zsh <label> <guest-source-root>` clicks a Safari tab, drags a divider and returns it, and clicks a workspace 3 window in the sidebar. It records native output and a movie. Its coordinates and window IDs describe this captured desk; a freshly staged desk needs its IDs read back and substituted before use. The initial rich desk's Safari IDs were 190 and 192. The spike's capture targets were TextEdit 204 and Safari 185. Keep the same IDs on both trees for a comparison.

`empty.zsh` checks the empty-Column outline and restores the rich config. `late.zsh` opens the HUD and Lens after Mission Control is already running. Those late-created overlays still draw above the system view despite `.transient`; retain their failing captures. Use `arrow-chord up` to exit Mission Control as well as enter it. Escape can be consumed by sidebar state, leaving the system view open and invalidating the next toggle's capture. The accepted shared comparisons are the `base-verified` and `branch-verified` takes.

Compile the tools in the guest:

```sh
swiftc -parse-as-library ~/mission-control/parking.swift -o ~/mission-control/parking
swiftc ~/winmux/.scratch/winmux-fork/proofs/sidebar-shortcuts/arrow-chord.swift -o ~/mission-control/arrow-chord
```

`spike.zsh setup` saves workspace 3 and 2 arrangements, quits WinMux and takes the parking baseline. Subsequent `baseline`, `offscreen`, `small`, `minimize` and `show` arguments replay the same saved frames with WinMux stopped. `show` is the full-size on-screen control. The script refuses to experiment while WinMux is running. Each case saves a Mission Control still and Dock AX tree, native frame readback, two desktop-independent ScreenCaptureKit pictures, and a movie of two workspace round trips. Remove a previous case's movie explicitly before repeating it: `screencapture` refuses to overwrite.

The probe also supports `save <json>`, `apply <saved-json> <option> <actual-json>`, `capture <id> <png>` and `ax`. Compile it after editing. It initializes AppKit before using the capture APIs. Position/size successes are not proof of placement: inspect the actual JSON for clamping and app minimum sizes. AX size writes can be refused by the Updater prop.

Use `measure.py <actual-frames.json> <dock-ax.txt>` on the host for per-window linear thumbnail ratios and counts. Mission Control's unnamed panel buttons are counted separately from matched application windows. The rich desk has fourteen managed windows but thirteen Mission Control application thumbnails because its floating Updater prop is omitted by macOS. The base adds four WinMux panel thumbnails. App Exposé uses its own saved native sizes from the corresponding live run.

The serial probe's switching movies demonstrate visible effects and ordering costs, not production switching latency. Review movie frames as well as screenshots. Permission prompts for WinMux or capture tools stop the run; leave them unanswered. The Python Local Network screen is dismissed by closing `UserNotificationCenter`, as the VM skill describes.

After the experiment restore full sizes, clear native minimization, quit the debug build, close the staged apps and the Finder desk window, and leave the assigned guest running at 1920×1080. Public demos come from the demo pass's final commit.
