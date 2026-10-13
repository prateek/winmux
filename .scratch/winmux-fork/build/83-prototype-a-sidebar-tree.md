# Prototype: the sidebar as a tree

Part of {{UMBRELLA}}.

## What to build

The sidebar lists workspaces with their windows under them. It does not show Columns, and it shows a tab group and a split the same way. Prateek pointed at Tree Style Tab and Sidebery as what it should learn from.

Build a throwaway prototype of the sidebar as a tree, and bring him a choice.

## Decisions

- **The tree is the layout**: workspace, Column, tab group or split, window.
- **Rows collapse, drag to a new parent, and can be searched.** Prateek: "all of the above".
- **A tab group and a split look different**, so the tree shows which one a set of windows is.
- **He runs the sidebar collapsed, expanding on hover.** So the collapsed rail has to say something useful by itself, and the tree is what hover reveals.
- **The prototype is a clickable page** with two or three variants side by side, as the Lens look prototype was. Collapse, drag and search work in it.
- **A prototype answers questions; it does not ship.**

## Questions to answer

- How are Columns shown: as a level of the tree, or as marks on the workspace row?
- What does a drag do to the layout, and which drags are refused?
- What does the collapsed rail show: workspace numbers, a mark per Column, the focused window's icon?
- How wide does the tree need to be when it expands?

## Depends on

Nothing.

## Done when

- [ ] A clickable page under `.scratch/winmux-fork/prototypes/` on the staged desk's layout, with two or three variants side by side, each in its collapsed and expanded states.
- [ ] Captures of Tree Style Tab and Sidebery beside it.
- [ ] A recommendation and a draft issue for the variant he picks.

## Sources

- Prateek, 2026-10-07: "for the sidebar - take inspo tree-style-tabs / sideberry"; "would be nice to see tab-groups v bsp as groups v splits too"; "do we need to indicate columns in the sidebar somehow".
- Prateek, 2026-10-13: collapsed, expanding on hover; a clickable page with two or three variants.
