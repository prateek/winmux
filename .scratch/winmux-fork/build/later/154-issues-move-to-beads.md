# Issues move to beads, and the relay reads them

Shelved 2026-10-20: Prateek chose to file on GitHub for now. Kept for when the sub-issue cap bites again; the umbrella's Later section points here.

Part of {{UMBRELLA}}. This is the child that changes what "Part of" means: after it, a draft's placeholder is the parent bead's id.

## What to build

GitHub issues cap a parent at 100 sub-issues, and #55 is at the cap, so new children are linked by hand. #55's build order is a list kept by hand. The relay's next child is whichever open child has its dependencies closed, computed by reading issue bodies. Prateek runs beads in another repository and wants it here: a dependency graph, `bd ready` for the queue, no cap, and the tracker in the repository.

Move the tracker to beads, import every open issue, and revise the relay skill to read and write beads.

## Decisions

- **Every open issue imports**, with its body, labels, parent and dependencies, as beads under `.beads/` in the repository. #1, #55 and this umbrella become epics; their children's build order becomes `blocks` dependencies, so `bd ready` returns the same next child the hand-kept list would.
- **An issue with no parent gets one at import.** #109, re-running Place when a window leaves about:blank, is the one open issue that is a child of neither #55 nor #84; it imports under #55. The import script lists every unparented issue it finds and stops if there is one it cannot place.
- **GitHub issues stay for outsiders.** A person who is not Prateek files on GitHub; the relay triages such an issue into a bead and links the two. Nothing else is filed on GitHub.
- **Open with Prateek and his checks are beads** with a `blocked-on-prateek` label and a `prateek-check` label, and the relay's Items for Prateek section writes to them.
- **The relay skill is revised in one pull request before this umbrella's relay starts**: Issue bodies, Items for Prateek, the next-child rule, the `Closes #n` line, the umbrella child list and the drafts under `.scratch/winmux-fork/build/` all become beads operations. A draft is the bead's body; `bd create` from the draft replaces rendering and `gh issue edit`. The squash body ends with the bead id.
- **The beads pin follows the repository's toolchain decision.** **One pinned toolchain for CI, the guest and the release** chose a Nix flake over mise for every pin, so `bd` goes into the flake when that issue lands; until then the import script checks the `bd` version it was written against and refuses another, and `AGENTS.md` names the version.
- **Dependencies import as they are written, not as the list order.** A child's `blocks` edges come from its Depends on section; #55's narrative build order becomes a `priority` field, so `bd ready` keeps the independent children independent instead of serializing the list.

## Depends on

Nothing.

## Defaults chosen for you

- **The import script** lives in `script/`, is idempotent, and records each issue's number on its bead so a later import skips it.
- **`bd` writes commit through the relay's own pushes**, not through separate commits, so a land carries its bead changes as it carries its draft today.

## Done when

- [ ] `bd ready` in a fresh clone lists #55's open children in an order the hand-kept list agrees with, and this umbrella's children with the mode rewrite first.
- [ ] The relay skill's SKILL.md and reference.md name no GitHub issue operation except filing an outsider's report.
- [ ] One relay land under the revised skill, on a #55 defect, from `bd ready` to close, with the pull request body ending in the bead id.
- [ ] `AGENTS.md` says where issues live.

## Sources

- The grilling record, 2026-10-19, "Process": "yes lets import all open issues into beads. we can leave the issues only for public facing interactions with users".
