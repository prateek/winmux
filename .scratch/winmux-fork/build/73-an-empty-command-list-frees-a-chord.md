# A chord bound to an empty command list is still taken

Part of {{UMBRELLA}}.

## What to build

A config that imports the defaults and wants one chord back writes it with an empty command list. Before this change, the chord stayed registered: WinMux took the key in every app and ran nothing, and the only way to free it was to rebuild the binding record without that chord. `docs/default-config.md` documented record removal; the reported config needed three nested record updates to do it.

Reproduced on the base build: overriding `alt-slash` with `[]` consumed Option-/ in TextEdit and typed only the control letter. Empty chord and sequence command lists are now omitted when parsing a mode, so their keys reach the focused app. They are dropped after the redeclaration checks, so an empty binding still collides with another spelling of its chord. Empty modifier-tap bindings remain present.

## Decisions

- **Reproduce first**, in a guest: bind a default chord to an empty list, press it in a text field, and read whether the key arrives.
- **A chord with no commands is not registered.** The key reaches the focused app.

## Not in this issue

- Which chords the defaults bind. That is **A short list of default shortcuts**, which makes this matter less and does not remove it.

## Depends on

Nothing.

## Defaults chosen for you

- **`winmux config check`** says nothing about an empty list. It is a supported way to free a chord.
- **`docs/default-config.md`** shows the empty list as the way to free a chord, and keeps the record recipe only if something still needs it.

## Done when

- [x] A test that fails before the change: a binding with an empty command list is absent from the registered hotkeys.
- [x] In a guest, a default chord overridden with an empty list types its character in a text field.
- [x] The docs show the one-line override.

## Build checks

- Host and pinned-version guest `make check` pass: 1,444 Swift tests, 89 Rust/helper tests and 142 Python tests, with no skipped Swift tests. Removing the empty-list filter fails registration, sequence-consumption, parser and command-consumer regressions. Restoring the old duplicate check fails the empty-redeclaration regression. Removing array-command support fails the helper override regression; the Nickel contract is unchanged.
- The same guest key script reads only the control letter on the base and `÷x` on the new build, checked through both the clipboard and accessibility text. Saving the empty override over a running import-only config also reads `÷x`. Option-Shift-O opens overview on both builds. `config check` exits 0 silently, and `trigger-binding` reports the freed chord as unbound.
- `docs/default-config.md` shows the empty-list override and the matching Lens-key recipe. `W.without-bindings` remains documented because the upgrade advice still uses record removal. Conversion comments stay unchanged.

## Sources

- The audit of the default shortcuts, 2026-10-07, citing a note in Prateek's config from 2026-10-06.
