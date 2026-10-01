# Grilling: the Filter contract's final field list

Type: grilling
Status: resolved
Blocked by: 11

## Question

What is the exact, complete field list of `Window`, `App`, the Filter context and `Column` that WinMux passes to Nickel? It is written twice: as Nickel contracts in the shipped config library and as the helper's typed Rust structs ([Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md)), and the two must agree.

Fields have been added ticket by ticket: Window classes and attributes in [Prototype: filter language worked examples](06-prototype-filter-language.md), the Filter context and `lastFocusedSeq` in [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md), activation policy, subrole and level in the Accessory research, and `w.tabs`, `w.tabsSource`, `w.tabsAge`, `w.document` and `w.private` in [Grilling: tab provider interface](24-grilling-tab-provider-interface.md). The floating and Accessory defaults ticket will add more, which is why this waits on it. Display profiles are deferred (2026-09-30): keep the Filter context's Display profile field, with one implicit profile as its only value. Native tab grouping is deferred (2026-09-30), so the tab fields stay as the tab provider grilling left them.

Consolidate them into one list with each field's name, type, enum values, and value when unknown (Nickel errors on a missing field). Decide which fields are enums rather than strings, how the contract is versioned, and whether `winmux` can print it (the CLI ticket asks for a listing of the Filter attribute schema).

## Answer

Resolved 2026-09-30 with Prateek. This is contract version 1. Every field is always present; the "when unknown" column gives the value used when WinMux has nothing to report.

**Window (`w`)**

| Field | Type | When unknown |
|---|---|---|
| `id` | Number | never unknown |
| `title` | String | `""` |
| `class` | enum: `'tiled`, `'floating`, `'fullscreen`, `'minimized`, `'hidden-app`, `'accessory-popup`, `'app-popup` | never unknown |
| `subrole` | String (the AX subrole) | `""` |
| `level` | Number (the CG window layer) | `0` |
| `hasCloseButton` | Bool | `false` |
| `document` | String (from `AXDocument`) | `""` |
| `workspace` | String | never unknown |
| `project` | String | `""` |
| `monitor` | Monitor | never unknown |
| `lastFocusedSeq` | Number | `0` (never focused) |
| `app` | App | never unknown |

**App (`w.app`)**

| Field | Type | When unknown |
|---|---|---|
| `bundleId` | String | `""` |
| `name` | String | `""` |
| `pid` | Number | never unknown |
| `accessory` | Bool (the bundle's `LSUIElement`) | `false` |
| `activationPolicy` | enum: `'regular`, `'accessory`, `'prohibited` | never unknown |

**Monitor**: `name` (String), `uuid` (String, `""` when unknown), `builtin` (Bool).

**Filter context (`ctx`)**

| Field | Type | Notes |
|---|---|---|
| `focused` | Window or `null` | the focused window |
| `mouse` | Window or `null` | the window under the mouse |
| `previous` | Window or `null` | the previously focused window |
| `workspace` | `{ name, project }` | the current workspace |
| `monitor` | Monitor | the focused monitor |
| `profile` | String | always `"default"` until Display profiles are built |

**Column** (passed to `place` and `move-boundary`, not to Filters): `index` (Number), `width` (Number, a fraction), `empty` (Bool), `windows` (Array of Window).

Decisions behind the list:

- **Tab fields are left out of version 1.** `w.tabs`, `w.tabsSource`, `w.tabsAge` and `w.private` wait for the deferred tabs effort. A field that's always empty invites Filters that silently match nothing, and adding one later breaks nothing. `w.document` stays because WinMux reads it itself.
- **`w.registered` is dropped.** With no proactive registration, every window a Filter sees is registered.
- **Absent context windows are `null`.** The load-time smoke run calls every Filter and hook twice, once with `focused`, `mouse` and `previous` all set and once with all three `null`, so an unguarded `ctx.focused.app` fails at load.
- **Enums** are `class` and `activationPolicy`, as Nickel enum tags. `subrole` stays a String because the set of AX subroles is open.
- **Versioning.** One integer, `contract-version`. It's bumped only when a field is removed or renamed; additions don't bump it. The app, the shipped contracts and the helper's structs ship together, so only a user's config can lag.
- **Printing.** `winmux config schema [--json]` prints every field with its type, enum values and a one-line description, generated from the same source as the Nickel contracts and the helper's Rust structs so the two can't drift.
