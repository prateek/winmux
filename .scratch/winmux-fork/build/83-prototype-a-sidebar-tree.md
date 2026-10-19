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

`prototypes/83-sidebar-tree/index.html` is a single static page with inline CSS, JavaScript and the exact normalized `desk.json` fixture embedded for opening from disk. It follows the Lens look's light/dark tokens and reading-column/stage form. Three variants share the staged fourteen-window desk: A shows Column rows and a numbered Column-mark rail; B shows width-proportional Column marks, window tags and a focused-app rail; C uses Column dividers and stacked window icons. Each has disclosures, pinning, hover expansion, drag targets, shared search and a layout miniature.

The rich desk was staged once at 1920 × 1080 before Firefox. Raw workspace, window, Column-width and agent-tree readbacks are retained beside the page. The agent query exposes container layout/orientation and tab identity; only remembered per-workspace focus was derived from the native highlighted captures, with its provenance recorded. Icons and today's collapsed/hovering sidebar were captured in the guest on all four workspaces. The code and captures correct the premise above: native tab groups with more than one child already show as groups; splits are flattened and Columns are omitted.

Safari live checks and headless Chromium checks exercise collapse, hover, accepted/refused drags, each Column target, split insertion and ancestor-preserving search. `Safari` finds three windows in workspace 2's Column 2 tab group, `Grievances` one in workspace 3's Column 1 group, and `qzxnomatch` none. The page's `?selftest` checks every drag-table rule against the fixture. Widths are measured at every depth with the actual rendered fonts and controls, including the focused semibold row; Chromium needs 297 points for the longest row. The README gives the native default of 240, the rich config's 280 and the recommendation of 320.

The drag table records two code-backed qualifications to the builder rulings: workspace transfers append through the sidebar binding and the Column invariant prefers a nearest empty Column before the focused occupied Column; a group survives in an empty Column but its leaves merge into tabs in an occupied one. No named Default in this issue changed; it has no Defaults section. Its Decisions remain as written.

Firefox installed in a fresh guest-only profile. Tree Style Tab and Sidebery each requested tab-access permissions at installation; both prompts were cancelled without a grant, using the permitted fallback to six credited screenshots published by the projects on Mozilla Add-ons. The page and README label them as published references. Live desk-shaped extension trees, their collapsed/expanded states and extension search were not checked. No extension code or asset is used in WinMux.

Recommend **B, Columns as marks**, with a 320-point expanded width. `build/121-the-sidebar-as-a-tree.md` is the feature draft for the recommended variant, so the third Done-when item is ticked. Prateek's pick may replace that recommendation and draft; the feature explicitly waits on his choice. Host and pinned Swift 6.4 guest `make check` pass. Installed-build checks, a second display and real sleep/wake/unlock remain unticked in the feature draft and remain Prateek's. The builder publishes no release.

## Sources

- Prateek, 2026-10-07: "for the sidebar - take inspo tree-style-tabs / sideberry"; "would be nice to see tab-groups v bsp as groups v splits too"; "do we need to indicate columns in the sidebar somehow".
- Prateek, 2026-10-13: collapsed, expanding on hover; a clickable page with two or three variants.
