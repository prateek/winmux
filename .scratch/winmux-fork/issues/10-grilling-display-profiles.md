# Grilling: Display profile contents and switch behaviour

Type: grilling
Status: out of scope
Blocked by: 05, 09, 13

Deferred 2026-09-30: Prateek put Display profiles off to a later effort so the foundation can be built first. See the map's Out of scope section.

## Question

What does a Display profile contain (Column count, Overflow policy, sidebar mode, gaps, anything else), how is it matched to a display, and what happens at the switch: re-flow of every workspace into the new Column count, placement of floating windows, focus preservation, and behaviour when the switch lands mid-drag or mid-Lens. How much, if anything, does `g95nc` need to call, versus WinMux reacting on its own?

Sub-questions surfaced by the monitor-identity research:
- Which profile wins when two monitors are attached (lid open with the ultrawide, or mid-`g95nc set`): explicit priority, hysteresis, or keep the current one?
- `g95nc set`/`reset` sleep 1–2 s between steps, longer than WinMux's 750 ms settle delay, so profile matching will see intermediate states. Should `g95nc` call a `winmux` command at the end so the switch happens at a known moment, or should WinMux debounce harder?

Update from [Grilling: fixed Columns, Width presets and Overflow policy semantics](09-grilling-fixed-columns-model.md): a Display profile is now a named condition that settings key on through `when.<profile>` (Columns, Lenses), not a bundle that holds them. "What does a profile contain" becomes "which settings can vary per profile, and how is the profile matched". Columns' re-flow on a switch has to respect positional Columns: widths reset to the new profile's `widths`, and when the count drops, the extra Columns' contents fold by `place`.
