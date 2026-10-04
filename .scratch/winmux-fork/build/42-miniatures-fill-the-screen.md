# `'miniatures` fills the screen, and a tab group shows its windows

Part of {{UMBRELLA}}.

## What to build

`overview` draws its workspaces in one row across the top. On a 1920 by 1080 monitor with four workspaces that is the top sixth of the screen, and the rest is empty. A tab group draws as one window, so three browser windows in a group look like one. This issue uses the screen and shows the group.

## Decisions

- **Workspaces are arranged in rows and columns** so that each is as large as the monitor allows. Four workspaces are two by two.
- **Workspace order reads left to right, then top to bottom.**
- **A tab group fans out.** Its windows are drawn offset from each other so each one's edge is visible and can be selected. The front one is the active tab.
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

- [ ] On the staged desk, `overview` draws four workspaces two by two and uses most of the screen.
- [ ] A tab group of three windows shows three selectable miniatures.
- [ ] Arrow keys, Search dimming, Summon and the tray work as before.
- [ ] Layout tests cover one, two, four and seven workspaces on a 16:9 monitor and on an ultrawide one.
- [ ] The pull request shows `overview` before and after on the staged desk.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), Presentation set to Miniatures.
