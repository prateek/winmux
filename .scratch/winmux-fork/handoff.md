# Handoff: WinMux fork wayfinding

Branch `wayfind-fork` on `prateek/winmux`, based on upstream `ZimengXiong/winmux@main` (470eedb). Charted 2026-09-28.

## What this is

A `/mattpocock:wayfinder` effort. It plans changes to a personal WinMux fork (filtered Lenses covering exposé, cmd+tab and cmd-K search; fixed Columns; a `winmux` CLI for all of it; Display profiles, tabs and trackpad gestures were deferred on 2026-09-30) and produces specs, not code. Everything durable lives in the map; this note only orients you and holds what the map doesn't.

- **Map (start here):** `.scratch/winmux-fork/map.md`. It holds the destination, standing decisions in Notes, Decisions-so-far, fog, and out-of-scope items.
- **Tickets:** `.scratch/winmux-fork/issues/NN-*.md`, on the local-markdown tracker. They use `Type:`, `Status:` and `Blocked by:` lines; the tracker conventions are in `~/.agents/plugins/plugins/mattpocock/skills/setup-matt-pocock-skills/issue-tracker-local.md` under "Wayfinding operations".
- **Research findings:** `.scratch/winmux-fork/research/`. **Prototypes:** `.scratch/winmux-fork/prototypes/`. Both live here rather than on throwaway branches, a deliberate deviation from the skills because the tracker is local.
- **Glossary:** `CONTEXT.md` at the repo root. Use its terms (Lens, Filter, Filter context, Presentation, Trigger, Summon, Window class, Accessory app, Column, Width preset, Overflow policy, Policy hook, Display profile).
- **ADRs:** `docs/adr/` at the repo root, for decisions that are hard to reverse. The first is the Nickel helper process.

## Finding the next ticket

Don't trust a list here; derive the frontier from the tickets. Open tickets are `Status: open` (deferred tickets read `Status: out of scope`); a ticket is on the frontier when every ticket in its `Blocked by:` line is `resolved`. Take the lowest-numbered one unless Prateek names another.

Some tasks need Prateek's Mac in a particular state. On 2026-09-29 and 2026-09-30 the sessions ran on a Mac mini (`Mac16,10`) with one virtual display and no trackpad, not his laptop; check `sysctl -n hw.model` and the display list before claiming a live task.

Since 2026-09-30 the Mac mini runs upstream WinMux 0.5.6 (cask `ZimengXiong/homebrew/winmux`) on the bundled default config, not the `prateek/tap` dogfood build. The old config is at `~/.config/winmux.dogfood-backup-20260930`. The upstream cask ships no CLI, so `/opt/homebrew/bin/winmux` is a copy built from v0.5.6 with `swift build -c release --product winmux`; it warns about a client/server version mismatch and works anyway. Ghost Pepper 2.4.4 is installed from the upstream cask.

## Repo setup

- Local clone: `~/code/github.com/ZimengXiong/winmux`, on branch `wayfind-fork`, which tracks `fork/wayfind-fork`.
- Remotes: `origin` is upstream `ZimengXiong/winmux` (HTTPS). `fork` is `prateek/winmux` over SSH.
- Push over SSH. The `gh` HTTPS token lacks `workflow` scope, and GitHub rejects any push that brings upstream `.github/workflows/*` changes into the fork.
- `prateek/winmux` defaults to `main`, and that `main` is kept equal to upstream `main`. Sync it with `git push fork origin/main:main` after `git fetch origin`.
- Commit or push only when Prateek asks. Each resolved ticket has so far been one commit ("Resolve <ticket>…"). His machine conventions are in `~/.claude/CLAUDE.md` and `~/.agents/docs/`.

## Open with Prateek

- He asked why the map sits in `.scratch/`. It's the local-markdown tracker convention. He was offered a migration to GitHub issues on `prateek/winmux`, which would give native blocking but make the tickets public, and hasn't answered. Don't migrate unless he says so.

## Things not captured elsewhere

- Prateek's own `prateek/winmux@codex-columns` branch (153 commits: columnar zones, scenes, rules, zone-expose) overlaps heavily. He chose upstream `main` as the base anyway. It's listed as prior art in the map's fog, so mine it when working the grid, Display profiles and Columns tickets; don't build on it.
- A possible dotfiles bug sits outside this map and hasn't been acted on. `g95nc`'s `discard` step appears to wipe BetterDisplay's "associate with display" setting; the evidence is in `research/05-*`. Surface it to Prateek rather than fixing it here.
- The first research agents had no web fetch. Apple API facts come from SDK headers, and some BetterDisplay claims come from search excerpts. Each findings file flags its own unverified points.
- Hardware serials were redacted from `research/05-*` because the repo is public.
- Nickel's 1.18 macOS release binaries link libiconv from `/nix/store` and won't run outside Nix. To try one, repoint it with `install_name_tool -change <nix libiconv path> /usr/lib/libiconv.2.dylib` and re-sign with `codesign -f -s -`.
- Working mode: one ticket per session (research tickets excepted). Claim a ticket (`Status: claimed`) before starting work. Record each resolution as an `## Answer` section, set `Status: resolved`, and add a line to the map's Decisions-so-far. When a resolution changes an earlier ticket's decision, put a dated "Amended" or "Superseded" note at the top of that ticket's Answer.

## Suggested skills

- `mattpocock:wayfinder`: invoke with the map path to work the next ticket.
- `mattpocock:grilling` + `mattpocock:domain-modeling`: for every HITL ticket; keep `CONTEXT.md` current.
- `mattpocock:prototype`: for prototype tickets (the grid Presentation, the Chrome tab source).
- `mattpocock:research`: if a resolution surfaces new research tickets.
- `writing-for-humans`: for replies to Prateek.
