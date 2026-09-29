# Grilling: fixed Columns, Width presets and Overflow policy semantics

Type: grilling
Status: open
Blocked by: 04

## Question

Pin down the Column model: how a Column count is declared per Display profile, how new windows fill Columns (next empty? next to focus?), what Width presets exist and how cycling works (per Column, what the neighbours do), the configurable Overflow policy options and the tab-group default, what happens when windows close (Columns collapse or hold their slot), and how this interacts with manual splits, resize, balance, and tab groups.

Sub-questions surfaced by the layout-engine research:
- With fewer windows than Columns: fill the width, or keep presets and leave blank space (needs a placeholder node or root padding)?
- Which Column takes overflow: focused, MRU, or last?
- Does the Column count constrain `move`, `move-node-to-workspace` and drag-and-drop, or only new windows?
- Presets that don't sum to 1: who shrinks?
- What `balance-sizes` means in Columns mode.
- Preset cycling needs a new command or `resize` mode.
- Naming: WinMux's `stack-with` makes a tab group, so an Overflow option called "stack" will mislead. Pick distinct names (e.g. `tab-group`, `split-vertical`, `squeeze`, `float`).
