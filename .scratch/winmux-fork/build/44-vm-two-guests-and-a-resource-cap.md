# The `vm` skill: two guests at most on the build machine, each at a fixed small size

Part of {{UMBRELLA}}.

## What to build

The `vm` skill gives every guest 4 cores and 8 GB, and will start as many guests as it is asked for. The build machine has 10 cores and 16 GB, and the host also runs the driver, the builder and their builds. macOS runs at most two macOS guests at a time. This issue makes the skill keep to that limit and gives each guest a size measured to leave the host room.

## Decisions

- **Two guests at most, counted across everything on the machine.** The limit is macOS's, and it covers the skill's guests and Tartelet's together, in any split: two from the skill and none from Tartelet, one of each, or two from Tartelet. `vm up` and `vm build-image` refuse to start a third and name the two that are running.
- **A guest is 3 cores and 5 GB.** Prateek chose the size on 2026-10-04. It was not measured itself; the sizes on either side of it were, and both pass `make check`.
- **The cap.** All running guests together use at most 70% of the build machine: 7 of 10 cores and 11 of 16 GB. Two guests at the default size are 6 cores and 10 GB, inside the cap.
- **Tartelet is off today**, because GitHub's hosted runners are the gate for this repository and are free for it. Nothing in this issue turns it on. If it is turned on, its guests take the same size and count against the same two.
- **The size can be raised for one guest** with `VM_CPU` and `VM_MEMORY`, and `vm up` refuses a size that would take the running guests past the cap.

## What was measured

On the build machine, a clean `make check` in fresh clones of the golden image:

| Guests | Size each | Result | Time | Swap in the guest |
|---|---|---|---|---|
| 1 | 4 cores, 8 GB | pass | about 3 min | not measured |
| 1 | 2 cores, 4 GB | pass | 4 min 25 s | none |
| 2 at once | 2 cores, 4 GB | both pass | 4 min 6 s and 4 min 34 s | none |

With two guests building, the host's load average peaked at 6 on 10 cores, and its free memory stayed above 60%.

Not measured: 3 cores and 5 GB itself, and filming at any size below 4 cores and 8 GB. A live run and a screen recording run WinMux, several apps and `screencapture` in the guest at once.

## Not in this issue

- Moving CI to the build machine.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Counting.** Every running guest in `tart list` counts, whoever started it. The skill and Tartelet share one `TART_HOME`, so one listing covers both. Each guest's cores and memory come from `tart get`.
- **If filming stutters at 3 cores and 5 GB**, the demo pass raises its guest to 4 cores and 6 GB, which beside a second guest at the default size is exactly the cap. Say what was seen.
- **A guest the host cannot reach.** During the measurement, three boots out of nine came up healthy and unreachable from the host over the network; a reboot fixed each. `boot` already retries when softnet fails to start. It gains a check that the ssh port answers, and reboots the guest when it does not, up to its existing three tries.

## Done when

- [ ] With two guests running, `vm up c` fails with a message naming both. With one running, a second starts.
- [ ] A guest started by `vm up` has 3 cores and 5 GB, and `make check` passes in it; the pull request gives the time.
- [ ] `VM_CPU=8 vm up a` fails with a message naming the cap.
- [ ] A guest that boots without a reachable ssh port is rebooted, not waited on.
- [ ] One demo was filmed at the default size, and the pull request says whether it was smooth.
- [ ] `SKILL.md` states the two-guest limit, the size and the cap.
- [ ] The `issue-relay` skill says a driver may hold one guest, so two relays can run side by side and a third waits.

## Sources

- [`.claude/skills/vm/vm`](https://github.com/prateek/winmux/blob/fork/.claude/skills/vm/vm)
