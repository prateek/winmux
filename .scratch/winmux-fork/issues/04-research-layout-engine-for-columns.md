# Research: WinMux layout engine seams for fixed Columns

Type: research
Status: resolved

## Question

How does WinMux's tree layout work today (`TilingContainer.swift`, `layoutRecursive.swift`, `ResizeCommand`, `BalanceSizesCommand`, `SplitCommand`, new-window insertion in `NewWindowBinding.swift`, tab groups)? Where would a fixed Column count plus Width presets and an Overflow policy (tab group, stack, squeeze, float) hook in: a new layout kind, a constraint on the root container, or a policy on window insertion? What existing behaviour would fight it (normalization, flatten, balance)? Deliverable: a seam map with the candidate hook points and their trade-offs.

## Answer

A Column fits the existing tree as a child of an `h`/`tiles` root: a bare window, a `v` stack, or a tab group. No new layout math and no new `Layout` case, because that would touch about 34 files for a mere marker.
Recommended seams: (C) branch in `bindingDataForNewTilingWindow` to apply the Overflow policy when the root already has N children, plus (B) a Column-invariant pass after `normalizeContainers` that forces an `h` root, folds extras, and re-applies Width presets stored as fractions (the agent `sizeRatio` code is prior art).
What fights it: flatten replaces the root when it holds a single stacked Column. `layoutTiles` spreads width in equal absolute amounts, so fractions drift on display change and on close. `balance-sizes` and `resize` break presets. About 25 other `bind(to:)` sites skip the new-window path.
Open for ticket 09: empty-Column behaviour (the tree can't hold empty slots), which Column absorbs overflow, whether moves are bound by the Column count, and the "stack" naming clash with WinMux's tab-creating `stack-with`.
[findings](../research/04-layout-engine-for-columns.md)
