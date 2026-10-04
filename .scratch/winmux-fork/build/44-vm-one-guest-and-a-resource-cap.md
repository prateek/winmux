# The `vm` skill runs one guest, at a fixed small size

Part of {{UMBRELLA}}.

## What to build

The `vm` skill gives every guest 4 cores and 8 GB, and will start as many guests as it is asked for. The build machine has 10 cores and 16 GB, so two guests claim all of its memory, and the host also runs the driver, the builder and their builds. This issue makes the skill run one guest at a time, at a size measured to be enough.

## Decisions

- **One guest at a time.** `vm up` refuses to start a guest while another guest the skill started is running, and names the running one. `vm build-image` counts as a guest.
- **A guest is 3 cores and 5 GB.** Prateek chose the size on 2026-10-04. It was not measured itself; the sizes on either side of it were, and both pass `make check`.
- **The cap.** The skill's guest and a Tartelet runner guest together use at most 70% of the build machine: 7 of 10 cores and 11 of 16 GB. One guest of each kind at 3 cores and 5 GB is 6 cores and 10 GB, inside the cap.
- **Tartelet stays at one runner guest**, sized the same way. It is off today, because GitHub's hosted runners are the gate for this repository and are free for it. Nothing in this issue turns it on.
- **The size can be raised for one guest** with `VM_CPU` and `VM_MEMORY`, and `vm up` refuses a size that would break the cap.

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

- Running two relay guests in parallel.
- Moving CI to the build machine.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **How the skill knows its own guests.** By name: the golden image's build guest, and the names `vm up` was given, recorded under the skill's state directory. A guest Tartelet started is not counted against the one-guest rule, only against the cap.
- **If filming stutters at 3 cores and 5 GB**, the demo pass raises its guest to 4 cores and 6 GB, which with a Tartelet guest is exactly the cap. Say what was seen.
- **A guest the host cannot reach.** During the measurement, three boots out of nine came up healthy and unreachable from the host over the network; a reboot fixed each. `boot` already retries when softnet fails to start. It gains a check that the ssh port answers, and reboots the guest when it does not, up to its existing three tries.

## Done when

- [ ] `vm up b` while guest `a` is running fails with a message naming `a`.
- [ ] A guest started by `vm up` has 3 cores and 5 GB, and `make check` passes in it; the pull request gives the time.
- [ ] `VM_CPU=8 vm up a` fails with a message naming the cap.
- [ ] A guest that boots without a reachable ssh port is rebooted, not waited on.
- [ ] One demo was filmed at the default size, and the pull request says whether it was smooth.
- [ ] `SKILL.md` states the one-guest rule, the size and the cap.

## Sources

- [`.claude/skills/vm/vm`](https://github.com/prateek/winmux/blob/fork/.claude/skills/vm/vm)
