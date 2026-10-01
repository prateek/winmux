# Grilling: questions left by the review of the build issues

Type: grilling
Status: resolved

## Question

A review of the thirteen build issues (see [the review](../build/review.md)) sorted their 122 open details. 112 were already decided, settled by the existing code, or had one sensible default. Four needed Prateek: how Nickel names the fork adds are spelled, how a Lens opts into popup windows now that Filters are functions, how a user config layers over the shipped defaults, and what happens to the Settings panes that edit the config file.

## Answer

Resolved 2026-10-01 with Prateek.

- **Hyphens.** Every Nickel field and enum tag the fork adds is spelled with hyphens (`width-presets`, `'accessory-popup`, `app-windows`, `frozen-thumbnail`, `'landing-spot`), matching the keys inherited from upstream and the CLI. Nickel 0.19.0 accepts hyphens in identifiers (`^_*[a-zA-Z][_a-zA-Z0-9-]*$` in `nickel-lang-core`'s `pretty.rs`). The cost: `a-b` is one name, so subtraction needs spaces. This overrides the underscores in the config prototype, the spike config and the `miniatures` record of the grid prototype ticket.
- **Popup windows are opted into by a Lens field.** A Lens has a `popups` field listing the popup Window classes it includes (`'accessory-popup`, `'app-popup`), empty by default. Windows of a class not listed never reach the Lens's Filter. This replaces "unless the Filter names them" from [Prototype: filter language worked examples](06-prototype-filter-language.md), which relied on scanning a Filter string and can't work on a Nickel function.
- **Defaults are imported, not implied.** WinMux ships a `defaults.ncl`. A user's config imports it and merges over it explicitly, so every default is visible and any of them can be dropped. `config convert` writes that import line. Implicit merging was rejected because a default binding couldn't be removed.
- **Settings panes are read-only in the first version.** The panes that write keys and bindings back into the config file show the loaded values and an "Open config" button. They can't edit a Nickel file.

Two contract details the review surfaced were settled as defaults by the agent, not by Prateek, and can be changed:

- **`w.workspace` can be unknown.** Popup-class windows sit outside every workspace and report `""`. A minimized window reports the workspace it was on when it was minimized, which WinMux has to start remembering; that also gives `'miniatures` what it needs to draw minimized windows under their workspace. This amends [Grilling: the Filter contract's final field list](33-grilling-filter-contract-field-list.md), which said "never unknown".
- **`w.document` is new work.** Nothing in WinMux reads `AXDocument` today, so the Filter contract issue builds that read.

Added 2026-10-01, after the issues were revised: the sidebar also writes to the config file (renaming a workspace or a project, setting a project's colour), which the Settings-pane answer didn't cover.

- **Sidebar edits go to a state file WinMux owns.** They keep working. The config declares the starting names and colours, and the state file overrides them. Nothing in WinMux writes to the config file. Making the sidebar actions read-only was rejected because it removes features that work today. The file's location is an implementer default (`$XDG_STATE_HOME/winmux/sidebar.json`).
