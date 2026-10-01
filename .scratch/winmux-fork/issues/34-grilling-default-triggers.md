# Grilling: default Triggers and a leader mode

Type: grilling
Status: resolved

## Question

Which keys open the default Lenses, and does WinMux ship a leader mode? `recent` (`cmd-tab`) and `app-windows` (`cmd-backtick`) are decided. `search` and `floating` ship unbound, and `overview` lost its three-finger swipe when gestures were deferred, so a daily-driver config has three Lenses with no Trigger. Decide their chords, whether they sit under one leader chord or are global, and which global chords the fork claims on top of upstream's defaults (`alt-` for focus and tabs, `alt-shift-` for moves, `ctrl-<n>` for workspaces, `alt-cmd-` for projects, `cmd-shift-` for joins; upstream ships only the `main` mode and leaves `palette` unbound).

## Answer

Resolved 2026-09-30 with Prateek. Two Lenses get their own global chord beyond the system-switcher pair, and the rest sit behind a leader.

- **Global chords:** `cmd-tab` → `lens recent` and `cmd-backtick` → `lens app-windows` (decided earlier), plus `alt-slash` → `lens search`. The fork claims no other global chord.
- **Leader mode:** `alt-semicolon` enters a `lens` mode. One key opens a Lens and returns to `main`: `o` → `overview`, `f` → `floating`, `s` → `search`, `r` → `recent` in the `'list` Presentation. `esc` leaves the mode.
- **Room to grow:** other fork commands (Column widths, `compact`) can join the `lens` mode later without claiming more global chords.
- These are the shipped defaults in the default config; every one is an ordinary binding the user can change.
