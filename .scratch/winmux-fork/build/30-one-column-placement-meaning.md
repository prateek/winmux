# One meaning for Column placement, shared by the Lens landing hint

Part of {{UMBRELLA}}.

## What to build

Two places decide what happens when a window is sent to a Column, and they decide it separately. [Column binding](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/tree/Columns.swift#L214) applies a Policy hook's decision to the tree. [Lens landing prediction](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/lens/MiniatureSession.swift#L167) works out where a Summon would land, to draw the landing hint. Both interpret the Overflow policy. The squeeze calculation is duplicated exactly, and the consequences of split and float are interpreted in each place on its own.

This issue creates one Column placement module that resolves a validated Policy hook decision against the current Column state. It owns the consequences of occupancy and Overflow policy for both the actual placement and the landing hint. The Lens draws the result; the workspace applies it through the real tree-mutation path.

It comes before the Lens issues in the umbrella because the landing hint is one of its two consumers, and the Lens issues that follow rewrite how that hint is drawn.

This is a demonstrated ownership and testability problem, not a claim that a visible defect exists. The existing Column race tests already protect substantial behaviour. Start from the current `fork` and recheck the observations above.

## Decisions

- Both consumers use the same interpretation. Squeeze arithmetic has one owner.
- The helper's Overflow policy is validated at its existing decoding seam, and a precise domain type is used internally. Wire strings, diagnostics, CLI output and fallback behaviour are preserved.
- Placement resolves against current occupancy and widths, after asynchronous evaluation and the stale-result checks, and excludes the incoming window correctly.
- A preview is advisory. Commit resolves again from current state and never applies a cached preview plan blindly.
- Single-window and group placement are both preserved. `bindToColumn` accepts a `TreeNode`; its group flattening and tab-group behaviour survive the refactor.
- Empty targets, existing squeeze Columns, proportional widths, split orientation, floating behaviour and normalization are preserved. Policy hook evaluation stays out of generic invariant repair.
- The landing hint describes the placement region before arbitrary `run` commands. That region is distinct from the final AX window frame, which may include tab-strip chrome or other layout adjustments. An existing mismatch between the two is resolved explicitly, and geometry is not silently changed to make a test pass.
- The Lens keeps its own selection cancellation, its coordinate scaling and its existing helper-record cache. Sharing the interpretation adds no AX reads and no helper calls per unchanged selection.
- Existing Swift types and narrow internal seams are the default. Full TCA adoption, a root store for the app, and moving the AX window tree or per-frame layout into reducers are out.
- [ADR-0001](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md) stands: Nickel stays in a supervised helper process.
- The deletion test applies: the change removes duplicated knowledge. Adding a forwarding module, or extracting the arithmetic while the rules stay duplicated, does not count.
- The useful implementation stays: proportional Width preset math, Column invariant repair and the stale-result guards.

## Not in this issue

- **Lens state, events and effect lifetimes, with controlled time** covers who owns the landing evaluation's lifetime and cancellation.
- **Config reload attempts and Policy hook completion, each with one owner** covers the evaluate, recheck, mutate, normalize, run sequence that placement and movement callers each assemble.
- Any change to what a Policy hook may return, to the Overflow policies, or to the CLI.
- Any change to how the landing hint looks.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The shape.** A resolved placement value carrying the resulting widths and an internal effect such as attach, split or float. Squeeze resolves to attachment to the extra Column, creating its width only when needed. Method names and exact types are the builder's.
- **A library.** Swift Clocks or Dependencies may be used where one removes concrete work. Explain the tradeoff in the pull request; adding a framework is not an acceptance criterion.
- **Actor isolation** around AppKit and live window objects stays as it is.

## Done when

- [x] The duplicated Overflow policy interpretation is gone from Lens code, and squeeze arithmetic has one owner.
- [x] A table of empty and occupied targets against every Overflow policy compares the landing region with independently observed actual placement and layout, using the real in-memory tree implementation.
- [x] The cases include nonuniform widths, an existing squeeze Column, a tab-group target, and moving a group. Expected values include concrete examples; comparing two calls to the same planner is not enough.
- [x] A preview leaves tree state, widths, focus and `run` execution unchanged, and emits no Column events.
- [x] A changed selection, destination or Column state cannot publish or commit an obsolete result. Floating and same-workspace Summon behave as before.
- [x] `make check` passes, and the pull request records any externally observable refinement separately from the structural change.

## Built

`tree/ColumnPlacement.swift` is the pure owner of occupancy, Overflow effects and squeeze widths. `OverflowPolicy` has the four existing wire values. `bindToColumn` resolves current state and applies its answer; `updateMiniatureLanding` converts the same answer into a frame with `ColumnState.frame`, gaps and the existing scaling. Preview values are never committed. Hook evaluation and command lifetimes keep their existing owners; no dependency was added.

`ColumnPlacementTest` has nineteen concrete table rows through real binding, normalization and layout, including groups, nonuniform widths, tab-group targets, an existing squeeze Column and incoming windows already in the destination. Preview snapshots cover tree revisions/order/weights, widths, focus, the event tracker and a detectable `run` list. Continuation-controlled tests cover changed destination and Column state; the existing selection-cancellation test remains. `ColumnPlacementWireTest` pins exact text and JSON for all four policies with empty and occupied targets, also run against the baseline source.

Two externally observable refinements are explicit: a replaced Column state cannot publish a late hint, and a sole incoming window nested in a destination container follows commit occupancy when flattening is off. Original Lens code fails the corresponding regressions. Split placement geometry is unchanged; window, container and group rows independently confirm its bottom-half region, or the whole Column after an empty existing tile is normalized away.

Host and CI-toolchain guest `make check` pass. Fourteen owned-window live hint/Summon cases cover miniatures and strip, including an already occupied squeeze Column in both. Dismissal preserves Column output and emits no Column events; unchanged pointer selection adds zero policy calls. Floating/same-workspace Summon and fall-through Place were also checked live. An unrequested macOS Tips notification stopped the live baseline-output comparison under the image-defect rule; exact output was compared against the same command path in memory instead. This is a limit of live verification, not an unchecked Done-when item. The builder published no release.

Decided: Keep a normalized vertical range in the resolved value so the Lens only converts a region to coordinates.
Decided: Add “Resolved placement” to the glossary for the advisory result shared by placement and its hint.
Decided: Use explicit reloads with reload-on-save disabled in the scratch live config to keep the comparison state stable.
Decided: After the image-defect stop, compare baseline output through the same in-memory command seam.

Defaults changed: none. The shape and actor isolation follow the issue; the relay's no-dependency ruling selects no optional library.

## Sources

- [Issue #53](https://github.com/prateek/winmux/issues/53), workstream 1, from an architecture review begun at `ee92badf` and rechecked at `f438e690`.
- [Columns.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/tree/Columns.swift#L214) and [MiniatureSession.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/lens/MiniatureSession.swift#L167)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
