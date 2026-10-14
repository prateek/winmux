# `'miniatures` fills the screen, and a tab group shows its windows

Part of {{UMBRELLA}}.

## What to build

`overview` draws its workspaces in one row across the top. On a 1920 by 1080 monitor with four workspaces that is the top sixth of the screen, and the rest is empty. A tab group draws as one window, so three browser windows in a group look like one. This issue uses the screen and shows the group.

Prateek chose `overview` as WinMux's view that stays open, the counterpart of Mission Control, with the system's Cmd-Tab left as the fast switcher. So this issue is what makes that view usable.

## Decisions

- **Workspaces are arranged in rows and columns** so that each is as large as the monitor allows. Four workspaces are two by two.
- **Workspace order reads left to right, then top to bottom.**
- **A tab group fans out.** Its windows are drawn offset from each other so each one's edge is visible and can be selected. The front one is the active tab.
- **`overview` opens with one chord.** **A short list of default shortcuts** names it. Today it is `alt-shift-o`; the windowing mode also reaches it with `o`.
- **Everything else about `'miniatures` stays**: real positions, the tray, the current-workspace treatments, `fit`, its arrow-key modes, the backdrop.

## Not in this issue

- A different arrangement for an ultrawide monitor. The rule above already gives one row when one row is largest.
- Drawing Columns or their boundaries in a miniature.

## Depends on

- **The Tile: one drawing of an entry, shared by every Presentation**.

## Defaults chosen for you

- **`fit = 'page`** pages when the workspaces at their smallest readable size exceed the screen, as today. The readable size is unchanged.
- **The fan's offset** is the prototype's, scaled.
- **`MiniatureLayout`** stays a pure function and gains the arrangement; its tests gain two-by-two and one-row cases.

## Done when

- [x] On the staged desk, `overview` draws four workspaces two by two and uses most of the screen.
- [x] A tab group of three windows shows three selectable miniatures.
- [x] Arrow keys, Search dimming, Summon and the tray work as before.
- [x] Layout tests cover one, two, four and seven workspaces on a 16:9 monitor and on an ultrawide one.
- [ ] The pull request shows `overview` before and after on the staged desk.

## Sources

- Prateek, 2026-10-13, choosing who owns Cmd-Tab and the open view.
- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), Presentation set to Miniatures.

## Build record

Both fit values use the same largest-workspace arrangement, centred below Search, with the
560-point drawing cap removed. Page mode keeps its readable floor and full-page geometry.
The three-tab fan puts the active tab in front and clamps its total offset.
The fan is drawn from the active tab's own frame, below the group's tab bar, and fans only the
tabs the Lens draws. Only a window tab group whose tabs are all windows fans; accordion groups keep
their own frames, and a group with a container tab draws as before. No window or tree
weight changes while opening.

Host and pinned-version guest `make check` pass. Preservation tests of paging, `'shrink` with
fifty workspaces, the tray and Search dimming passed before the arrangement changed, and each
regression was seen failing before its fix. The arrangement table includes both monitor sizes; the
original paging test is unchanged. Guest checks cover the fourteen-window desk, rear-tab clicks and
Return, both arrow modes, Search, Summon, trays and current-workspace treatments, against the base
build where the issue says behaviour stays.

No named default changed. The cache stays capped at 582.4 points, so a full-width window's picture
at 1920 × 1080 stretches about 1.24× with four workspaces, 1.6× with two and 2.7× with one,
until **A picture as sharp as the Tile that draws it** lands. `by-workspace` up/down retains its reading-order
meaning even when the next workspace is to the right. The existing Option-Shift-O binding is
unchanged; only this draft's stale chord sentence is corrected.

## Checks remaining for Prateek

- [ ] Installed build: Option-Shift-O on his own desk with four workspaces draws them two by two, filling most of the screen.
- [ ] A three-tab Safari group on the installed build fans with the active tab in front; a click on a rear tab's edge selects it, and Return focuses it.
- [ ] A real ultrawide monitor: the arrangement matches the layout tests (four workspaces two by two at 3440 by 1440).
- [ ] A second display.
- [ ] Real sleep, wake and unlock.
