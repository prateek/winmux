# Zone → Column Rename

Finish the Slice 56 vocabulary cut inside the code. The model renamed the
user-facing command and config surface to Display / Scene / Column / Card /
Rule, but the internals and a handful of user-visible strings still say
"zone." The runtime "zone" *is* the model's column, so it should say so.

## Why this is free

Every `zone`-named identifier in the repo is fork-authored: diffing against
both fork points shows none of it exists in AeroSpace or in
zimengxiong/winmux. The fork tracks neither as a merge target — AeroSpace is
a reference to crib from, winmux is one-way and already fully absorbed. So no
merge boundary protects any of these names, and renaming carries zero merge
cost. Naming is now purely a clarity decision.

## Two things to get right first

**1. "Zone" means two unrelated things; only one becomes "column."**

- **The viewport** — a column-sized region of a display that hosts one card
  (`zoneId`, `ZoneConfig`, `ZoneRuntimeOverlay`, `ConfiguredZoneSummary`).
  This is the model's Column. → rename to **column**.
- **A drag-geometry region** — a targetable sub-area of a window during a
  mouse drag (`WindowDropZone`, `WindowIntentZone`,
  `TreeNode+WindowDropBodyZones`, `WindowStackSplitZones`, `WindowSwapZone`).
  Here "zone" is a generic UI term with no relation to columns. → **keep
  unchanged.** Renaming these to "column" would be wrong.

**2. Delete before renaming.** Slice 56 superseded several zone concepts;
their structs are now dead or parse-only. Deleting beats renaming dead code
and shrinks the surface by about a third. That is Phase 0.

## Locked config-struct names

| Old | New | Role |
|---|---|---|
| `ZoneColumnConfig` | `ColumnConfig` | one column: id, name, width, color |
| `ZoneLayoutConfig` | `ColumnLayoutConfig` | a named set of columns (a scene's columns) |
| `ZoneConfig` | `DisplayLayoutConfig` | which layout a display shows: `{monitor, layoutPreset}` |

`ColumnConfig` is taken by the single-column struct, so the display-level
struct needs its own qualified name — hence `DisplayLayoutConfig`, which
reads coherently: a `DisplayLayoutConfig` points at a `ColumnLayoutConfig`.

## Phase 0 — Delete superseded concepts

Config v3 already rejects each key below with a migration hint, and those
error tables stay (they name the old key a migrating user types). What goes
is the struct, runtime, and diagnostics code behind them, once confirmed
unreferenced outside parsing and tests:

| Concept | Delete | Replaced by |
|---|---|---|
| Affinities | `ZoneAffinityConfig`, `ZoneAffinityEvaluation`, the `onWindowDetected` affinity loop | `[[rules]]` |
| Bindings | `NodeZoneBinding*`, `ZoneBindingConfig`, `ZoneBindingActivationResult` | deck membership |
| Availability sets | `ZoneAvailabilitySetConfig`, `ZoneAvailabilityChange`/`Operation` | dropped (no live uses) |
| Zone styles | `ZoneStyleConfig`, `config.zoneStyles` | `column color` |
| Old zone-scenes | `ZoneSceneConfig`, `ZoneSceneWorkspaceConfig`, `ZoneSceneActivationResult` | `[scene.*]` / `SceneConfig` |

Also trim `ZoneConfig`'s inline `columns` / `layout` / `defaultZone` fields:
the v3 `[scene.*]` path only sets `monitor` + `layoutPreset`; the rest is v2
dead weight. Prune the matching sections from `ConfigDoctor` and the support
bundle. Verify each concept is truly dead (config v3 rejects the key; the
struct is referenced only by parse, doctor, and tests) before deleting.

## Phases 1–8 — The rename

Rule: viewport `zone` → `column`; drop the `Zone` prefix from `Expose*` and
`SupportBundle*`.

**Phase 1 — User-facing surface (do first; these are bugs).**
- Format tokens: `%{monitor-zone-id}` → `%{column-id}`, plus the four
  siblings (`-effective-width`, `-enabled`, `-configured-width`,
  `-runtime-width-override-state`). Update `docs/` and the guest script to
  match, since the docs already advertise `%{column-id}`.
- Error strings naming deleted commands: `enable-zone` → `column expand`,
  `balance-zones` → `balance-columns`, drop the `save-zone-layout` reference.
- Output vocabulary: "No zones are configured" → "columns"; "Zone 'X' is
  disabled" → "Column"; "Wrote … zones to" → "columns"; "top zone" → "top
  column"; "zone support bundle" → "support bundle".
- Make `'column-mode'` the canonical `ZoneDividerDragPolicy` raw value and
  drop the `'zone-mode'` alias.

**Phase 2 — Config model.** `ZoneColumnConfig`→`ColumnConfig`,
`ZoneLayoutConfig`→`ColumnLayoutConfig`, `ZoneConfig`→`DisplayLayoutConfig`,
`ZoneLayoutKind`→`ColumnLayoutKind`, `parseZones.swift`→`parseColumns.swift`,
`ZoneInitConfig`→`ColumnInitConfig` (+ its edit/preset types),
`ZoneLayoutConfigEdits`→`ColumnLayoutConfigEdits`.

**Phase 3 — Viewport identity (the bulk, ~380 refs).**
`Monitor.zoneId`→`.columnId`, `ZoneRuntimeOverlay`→`ColumnRuntimeOverlay`,
`setActiveZoneLayout`→`setActiveColumnLayout`,
`ConfiguredZoneSummary`→`ConfiguredColumnSummary`,
`EffectiveZoneColumn`→`EffectiveColumn`,
`ResolvedZoneLayout`→`ResolvedColumnLayout`,
`ZoneState`/`StructuralZoneState`→`ColumnState`/`StructuralColumnState`,
`zoneStyleColorHex`→`columnColorHex`.

**Phase 4 — Commands & selectors.**
`ZoneCommandHelpers`→`ColumnCommandHelpers`,
`ZoneSelector`/`RelativeZoneSelector`/`ResolvedZoneSelector`→`Column…`,
`ZoneWidthAmount`/`ZoneWidthOperation`→`ColumnWidth…`,
`ZoneListRow`→`ColumnListRow`.

**Phase 5 — Mouse divider + snap (viewport meaning only).**
`ZoneDividerDrag*`→`ColumnDividerDrag*`, `ZoneSnap*`→`ColumnSnap*`. Leave the
drag-geometry files untouched.

**Phase 6 — Sidebar.**
`WorkspaceSidebarZoneTarget*`→`WorkspaceSidebarColumnTarget*` (resolution,
section, snapshot builder, view models).

**Phase 7 — Exposé + divider overlay.** `ZoneExpose*`→`Expose*`
(`ZoneExposePreviewCache`→`ExposePreviewCache`, tile, panel, view);
`ZoneDividerOverlay*`→`ColumnDividerOverlay*`. Split `ui/zones/` accordingly
(expose files to `ui/expose/`, divider overlay to the mouse/column chrome
area).

**Phase 8 — Diagnostics.** `ZoneSupportBundle*`→`SupportBundle*`. Keep the
frozen TSV support-bundle headers byte-stable so the support-bundle schema
self-test still passes.

## What stays "zone"

- Dead-key error tables (they name the old config keys for migration).
- The drag-geometry regions (meaning B above).
- v2-parse test fixtures exercising old keys, frozen `check-slice-*`
  checkers, and `columnar-zones-history.md`.

## Execution

One cluster per commit, compile-driven: rename the declaration, chase
references until it builds. Full `swift test` plus
`python3 script/check-command-metadata` between commits. Phase 0 and 1 land
first — independently valuable and low risk. The command-metadata chain moves
only when a command *name* changes; almost all of this is internal types, so
it rarely does. Cut a dogfood release after Phase 1 (the user-visible fixes)
and again at the end.

## Verification

Green suite at every commit. After Phase 1, grep proves no `%{…zone…}` token
and no deleted-command name survives in any user-facing string. At closeout,
the only `zone` left in `Sources/` is the drag-geometry regions, the dead-key
hint tables, and test fixtures — assert that with a grep.
