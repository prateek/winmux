# A chord bound to an empty command list is still taken

Part of {{UMBRELLA}}.

## What to build

A config that imports the defaults and wants one chord back writes it with an empty command list. Prateek's own config notes say the chord stays registered: WinMux still takes the key in every app and runs nothing, and the only way to free it is to rebuild the binding record without that chord. `docs/default-config.md` documents that recipe with `std.record.remove`; his config needed three nested record updates to do it.

This was reported, not reproduced. If it holds, overriding a default is harder than it should be, and a key goes dead with no sign of why.

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

- [ ] A test that fails before the change: a binding with an empty command list is absent from the registered hotkeys.
- [ ] In a guest, a default chord overridden with an empty list types its character in a text field.
- [ ] The docs show the one-line override.

## Sources

- The audit of the default shortcuts, 2026-10-07, citing a note in Prateek's config from 2026-10-06.
