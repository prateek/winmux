# A Lens-operating mode entered with no Lens

Part of {{UMBRELLA}}.

## What to build

A mode whose keys act on a Lens, `search` with `unbound = 'type` or `browse` with `'consume`, can become current with no Lens open, and then swallows every unbound key until Escape. The shipped way to reach it: Option-slash enters `search-hold`, whose `on-enter` opens the Search Lens; Option is released at once; the opening fails, for instance because collecting windows throws; the parked release runs `search-hold`'s `on-release`, `mode search`, which enters `search` with nothing to type into. `winmux mode search` from the CLI with no Lens reaches the same state.

Under **Modes are the only modality**'s Decision that a mode and its Lens are one thing exactly when the mode opened the Lens, `search` here opened nothing and adopted nothing, so no rule ends it.

## Decisions

- **Entering a mode that needs a Lens while none is open or opening enters `main` instead**, and logs which mode was refused. A mode needs a Lens when its `unbound` is `'consume`, `'type` or `'latch`, or its `on-enter` opens one. A `transient` mode is exempt: a one-key leader mode that consumes is not a Lens mode.
- **The CLI says so.** `winmux mode <name>` that is refused this way exits 1 with the reason.

## Depends on

**Modes are the only modality**.

## Done when

- [ ] A test: a held `search-hold` whose opening fails and whose release runs `mode search` ends in `main`.
- [ ] A test: `winmux mode search` with no Lens exits 1 and leaves the mode unchanged, and a `transient` consuming mode still enters.
- [ ] `docs/lenses.md` says which modes need a Lens.

## Sources

- Review round 6 of #303, the finding on `ModeEngine.finishReady`'s cancelled-owner cleanup, declined there as outside the ownership Decision.
