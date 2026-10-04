# The `vm` skill: two guests at most on the build machine, each at a fixed small size

Part of {{UMBRELLA}}.

## What to build

Before this change, the `vm` skill gave every guest 4 cores and 8 GB and started as many guests as it was asked for. The build machine has 10 cores and 16 GB, and the host also runs the driver, the builder and their builds. macOS runs at most two macOS guests at a time. This issue makes the skill keep to that limit and gives each guest a size measured to leave the host room.

## Decisions

- **Two guests at most, counted across everything on the machine.** The limit is macOS's, and it covers the skill's guests and Tartelet's together, in any split: two from the skill and none from Tartelet, one of each, or two from Tartelet. `vm up` and `vm build-image` refuse to start a third and name the two that are running.
- **A guest is 3 cores and 5 GB.** Prateek chose the size on 2026-10-04. A clean `make check` at this size passes; its measurement is below.
- **The cap.** All running guests together use at most 70% of the host, computed from `sysctl -n hw.ncpu` and `sysctl -n hw.memsize`, rounded down (memory to whole GB): 7 of 10 cores and 11 of 16 GB on the build machine. Two guests at the default size are 6 cores and 10 GB, inside the cap.
- **`vm stop`** shuts a guest down and keeps its disk, so a guest can be brought up again at another size without losing its build.
- **Starts are serialized.** A process-owned kernel lock under `TART_HOME` covers admission through boot and is released on exit or kill. A start that finds it held says it is waiting. Both limits are checked before cloning, so a refused start leaves no guest. The lock coordinates skill starts; a direct external Tart start does not acquire it, but its running guest counts at the next check.
- **Tartelet is off today**, because GitHub's hosted runners are the gate for this repository and are free for it. Nothing in this issue turns it on. If it is turned on, its guests take the same size and count against the same two.
- **The size can be raised for one guest** with `VM_CPU` (cores) and `VM_MEMORY` (MB), for both `up` and `build-image`, and `vm up` refuses a size that would take the running guests past the cap.

## What was measured

On the build machine, a clean `make check` in fresh clones of the golden image:

| Guests | Size each | Result | Time | Swap in the guest |
|---|---|---|---|---|
| 1 | 3 cores, 5 GB | pass | 3 min 25.68 s | none before or after |
| 1 | 4 cores, 8 GB | pass | about 3 min | not measured |
| 1 | 2 cores, 4 GB | pass | 4 min 25 s | none |
| 2 at once | 2 cores, 4 GB | both pass | 4 min 6 s and 4 min 34 s | none |

In the earlier two-guest measurement at 2 cores and 4 GB each, the host's load average peaked at 6 on 10 cores, and its free memory stayed above 60%. In this change's live admission run, two idle default-size guests recorded host load averages of 3.87, 4.06 and 3.88 and `memory_pressure` reported 48% system-wide memory free. This was one snapshot after the clean build, not a two-build peak measurement.

Filming at 3 cores and 5 GB: one seven-second take of the strip on the four-app desk, with WinMux, Zed, Ghostty, Safari, Notes and `screencapture` running. It was smooth. While the strip moved, frames arrived 17 to 50 ms apart; the longer gaps in the recording are holds where nothing on screen changed, which `screencapture` does not record. The guest was 72% to 99% idle once the recorder had started, and used 1 MB of swap. The same take at 4 cores and 6 GB looked the same, so the default size is enough for filming a desk of this size. Not measured: filming the fourteen-window desk.

## Not in this issue

- Moving CI to the build machine.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Counting.** Every running guest in `tart list` counts, whoever started it. The skill and Tartelet share one `TART_HOME`, so one listing covers both. Each guest's cores and memory come from `tart get`.
- **If filming stutters at 3 cores and 5 GB**, the demo pass raises its guest to 4 cores and 6 GB, which beside a second guest at the default size is exactly the cap. Say what was seen.
- **A guest the host cannot reach.** During the earlier measurement, three boots out of nine came up healthy and unreachable from the host over the network; a reboot fixed each. After `tart exec` answers, `boot` gives ssh about a minute, reads the IP again on every probe and stops an unreachable guest before its next try, up to three tries. Shim tests cover recovery on the second boot and failure after the third, and one real boot during this change came up unreachable and was rebooted this way.

## Done when

- [x] With two guests running, `vm up c` fails with a message naming both. With one running, a second starts.
- [x] A guest started by `vm up` has 3 cores and 5 GB, and `make check` passes in it; the pull request gives the time.
- [x] `VM_CPU=8 vm up a` fails with a message naming the cap.
- [x] A guest that boots without a reachable ssh port is rebooted, not waited on.
- [x] One demo was filmed at the default size, and the pull request says whether it was smooth.
- [x] `SKILL.md` states the two-guest limit, the size and the cap.
- [x] The `issue-relay` skill says a driver may hold one guest, so two relays can run side by side and a third waits.

## Sources

- [`.claude/skills/vm/vm`](https://github.com/prateek/winmux/blob/fork/.claude/skills/vm/vm)
