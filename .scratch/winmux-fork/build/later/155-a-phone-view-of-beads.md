# A phone view of beads

Shelved 2026-10-20 with the beads move; GitHub's own app is the phone view for now.

Part of {{UMBRELLA}}.

## What to build

Beads is a CLI. Prateek reviewed GitHub issues on his phone; after **Issues move to beads, and the relay reads them** he cannot. `bd serve` is a loopback HTTP API for automation, not a page. Two community web interfaces exist: beads-ui, a kanban with live updates started with `npx beads-ui start`, and Beady, a Go web interface. A third has stopped and does not support the Dolt storage that bd 0.50 and later use, which includes the pinned 1.3.1.

## Decisions

- **The view is served from the build machine over Tailscale**, read-only from the phone's side; a change made on the phone is a question for the next session, not a write.
- **It runs as a launch agent** on the build machine, started by `script/`, with the repository's `.beads/` as its source.
- **If no community interface works against the pinned `bd`**, the fallback is a static page rendered from `bd export` on every land, served the same way, and the bead says so.

## Defaults chosen for you

- **Which interface**: try beads-ui first, then Beady; keep the first that reads the pinned version's Dolt storage, shows dependencies and states, and needs no write access. Record the choice and the versions tried in the bead.

## Depends on

- **Issues move to beads, and the relay reads them**.

## Done when

- [ ] The interface serves this umbrella's beads with their dependencies and states, checked from the build machine with a headless browser at a phone's viewport over the Tailscale address.
- [ ] The launch agent survives a reboot of the build machine, checked by restarting it.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: open it on the phone.

## Sources

- The grilling record, 2026-10-19, "Process": "for mobile ui - can we serve the beads via some community ui tool".
