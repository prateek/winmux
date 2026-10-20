# Research: routing rules, per-app preferences and saved layouts in other window managers

Part of {{UMBRELLA}}.

## What to build

Nothing yet. Prateek wants saved layouts he can toggle between, and a command bar to restore them, and asked first how the tools people admire do it: Moom, tmux, AeroSpace, yabai, Rectangle, i3 and sway, Hyprland. Restoring a layout means matching windows to roles, and nobody has designed that for WinMux. The grilling made this a research child whose outcome decides whether layout commands get built.

## Decisions

- **The outcome is a written finding** under `.scratch/winmux-fork/research/`, in the house form: what each tool calls the thing, how it names a window's role, what it restores when the window is gone, and what a user writes to define one.
- **It ends with a recommendation** for WinMux: either a shape for `layout save <name>` and `layout restore <name>` that fits Columns and Policy hooks, or the reason to leave layouts to a Policy hook plus Display profiles, which will restore each display's layout once **Display profiles: match a profile to the attached display** lands.
- **If the recommendation is to build**, a draft issue comes with it, and the command bar stays Tuna's as the boundary says.

## Depends on

Nothing.

## Done when

- [ ] The finding exists with the comparison table and the recommendation.
- [ ] A draft issue, or a sentence in the finding saying why not.
- [ ] A line under **Open with Prateek: questions and checks that wait on him** asking him to choose, if the recommendation is to build.

## Sources

- The grilling record, 2026-10-19, "Features": layouts are research first.
- #268, "Study how other tools handle routing rules, per-app preferences, and saved layouts".
