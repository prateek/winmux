# Handoff: WinMux fork wayfinding

Branch `wayfind-fork` on `prateek/winmux`, based on upstream `ZimengXiong/winmux@main` (470eedb). Charted 2026-09-28.

## What this is

A `/mattpocock:wayfinder` effort, charted and with its first research round done. It plans changes to a personal WinMux fork (filtered Pickers covering exposé and cmd+tab, fixed Columns, Display profiles for laptop and ultrawide) and produces specs, not code. Everything durable lives in the map; this note only orients you.

- **Map (start here):** `.scratch/winmux-fork/map.md`. It holds the destination, standing decisions in Notes, Decisions-so-far, fog, and out-of-scope items.
- **Tickets:** `.scratch/winmux-fork/issues/NN-*.md`, on the local-markdown tracker. They use `Type:`, `Status:` and `Blocked by:` lines; the tracker conventions are in `~/.agents/plugins/plugins/mattpocock/skills/setup-matt-pocock-skills/issue-tracker-local.md` under "Wayfinding operations".
- **Research findings:** `.scratch/winmux-fork/research/`. These live here rather than on `research/*` branches, a deliberate deviation from the skill because the tracker is local.
- **Glossary:** `CONTEXT.md` at the repo root. Use its terms: Picker, Filter, Filter context, Presentation (grid/strip), Trigger, Picker binding, Summon, Accessory app, Column, Width preset, Overflow policy, Display profile.

## State

Five research tickets and one decision are resolved; see Decisions-so-far in the map. Twelve tickets are open.

The frontier (unblocked, unclaimed) is:
- `06` Prototype: filter language worked examples. It's first in order and is the next one to work.
- `09` Grilling: fixed Columns, Width presets and Overflow policy semantics.
- `12`, `13`, `14`, `16` are tasks: live checks and probes on Prateek's Mac. `13` needs him at the ultrawide with BetterDisplay running.

Blocked: `07` (on 06), `08` (on 14), `10` (on 09 and 13), `11` (on 12), `17` (on 16).

## Things not captured elsewhere

- Prateek's own `prateek/winmux@codex-columns` branch (153 commits: columnar zones, scenes, rules, zone-expose) overlaps heavily. He chose upstream `main` as the base anyway. It's listed as prior art in the map's fog, so mine it when working 08, 09 and 10; don't build on it.
- A possible dotfiles bug sits outside this map and hasn't been acted on. `g95nc`'s `discard` step appears to wipe BetterDisplay's "associate with display" setting; the evidence is in `research/05-*`. Surface it to Prateek rather than fixing it here.
- The research agents had no web fetch. Apple API facts come from SDK headers, and some BetterDisplay claims come from search excerpts. Each findings file flags its own unverified points.
- Hardware serials were redacted from `research/05-*` because the repo is public.
- Working mode: one ticket per session (research tickets excepted). Claim a ticket (`Status: claimed`) before starting work. Record each resolution as an `## Answer` section, set `Status: resolved`, and add a line to the map's Decisions-so-far.

## Suggested skills

- `mattpocock:wayfinder`: invoke with the map path to work the next ticket.
- `mattpocock:prototype`: for ticket 06 (filter-language examples in expression strings vs JavaScriptCore predicates) and 08.
- `mattpocock:grilling` + `mattpocock:domain-modeling`: for every grilling ticket; keep `CONTEXT.md` current.
- `mattpocock:research`: if a resolution surfaces new research tickets.
- `writing-for-humans`: for replies to Prateek.
