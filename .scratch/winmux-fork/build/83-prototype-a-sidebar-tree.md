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

- [x] A clickable page under `.scratch/winmux-fork/prototypes/` on the staged desk's layout, with two or three variants side by side, each in its collapsed and expanded states.
- [x] Captures of Tree Style Tab and Sidebery beside it.
- [x] A recommendation and a draft issue for the variant he picks.

## Built and checked

Prateek picked on **2026-10-18**: workspace numbers only in the rail; a flat, shallow tree with width-proportional Column marks; independent per-workspace Splits and Columns toggles, Splits also showing the floating group; any row accepts window/tab-group drops, with a window target meaning sibling at the pointed index. `build/121-the-sidebar-as-a-tree.md` is the feature draft for his pick. Nothing waits on a product choice.

`prototypes/83-sidebar-tree/index.html#pick` leads the page. Its own rail, hover, pin, disclosures, shared app/title search and drag targets work on the normalized fourteen-window desk. The config-shaped panel models proposed `sidebar.tree.splits` and `sidebar.tree.columns` defaults, both false. Defaults persist through reload; session overrides apply per workspace until that default changes. A/B/C remain side by side below, with the original interactions and drag rules.

The first pass staged the desk at 1920 × 1080 before Firefox. Raw workspace/window/Column and agent-tree readbacks expose actual layouts and orientation; remembered workspace focus alone is derived from native highlights. The follow-up corrected centered baseline image crops from the full originals. The code and captures correct the premise above: multi-child tab groups already show as groups; splits flatten and Columns are omitted.

The pick's 34 fixture checks supplement the original 21. Disabling the pick's drag branch makes the 20 changed-rule checks fail; restoring it makes them pass, while 14 unchanged checks stay green. Native Safari and headless Chromium cover hover/pin, levels, sibling halves, floating conversion, refusals and search. `Safari` finds 3 windows in workspace 2 / Column 2 / Safari tabs; `Grievances` finds 1 in workspace 3 / Column 1 / TextEdit tabs; `qzxnomatch` finds 0. Default flat and both-level pick widths measure 307 points; 320 is the chosen feature default.

Workspace transfers still follow invariant placement, nearest empty Column before focused occupied. Occupied Columns merge incoming group leaves; empty ones preserve the group. The pick adds the window-target/index adapter and explicit tiling of floating arrivals; the README distinguishes these feature seams from existing commands. No named Default in this issue changed; its Decisions remain intact.

The page compares guest-only Firefox extension captures; provenance, licences and exact search coverage are recorded in the README and capture index. Only displayed reference/baseline/icon images remain in the prototype; page evidence is retained by the driver. Host and pinned Swift 6.4 guest `make check` pass. Installed-build checks, a second display and real sleep/wake/unlock remain unticked in the feature draft and remain Prateek's. The builder publishes no release.

## Sources

- Prateek, 2026-10-07: "for the sidebar - take inspo tree-style-tabs / sideberry"; "would be nice to see tab-groups v bsp as groups v splits too"; "do we need to indicate columns in the sidebar somehow".
- Prateek, 2026-10-13: collapsed, expanding on hover; a clickable page with two or three variants.
