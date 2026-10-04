# Tests for the keyboard layout tables and for a superseded reload

Part of {{UMBRELLA}}.

## What to build

Two behaviours are held in place by a comment. This issue puts a test under each. Neither changes what WinMux does.

**The keyboard layout tables.** `winmux config convert` resolves a chord under a Dvorak or Colemak key mapping with tables in `nickel-helper/src/convert.rs`. They are a copy of `dvorakMap` and `colemakMap` in `Sources/AppBundle/config/KeyboardLayoutMaps.swift`. They agree today, and nothing fails when one side changes.

**A superseded reload.** A reload that a later one overtook is dropped and emits no `config-reloaded` event. In `reloadConfig` (`Sources/AppBundle/command/impl/ReloadConfigCommand.swift`) that is an early return placed above the `defer` that emits, with a comment saying so. No test covers it, because `reloadConfig` cannot run in a test: applying a config unregisters the login item and deletes launch agent files in the real home directory.

## Decisions

- Both tables stay where they are. The helper does not ask Swift for a table, and Swift does not ask the helper.
- One checked-in fixture holds the two layouts. A Rust test compares the helper's tables with it and a Swift test compares `dvorakMap` and `colemakMap` with it, so a change on either side fails until the fixture and the other side follow.
- `reloadConfig` and `applyConfig` are still not called from tests.
- The superseded-reload rule moves into a piece that can be tested without applying a config, and `reloadConfig` calls it. Its behaviour does not change: a superseded reload discards its helper, prints "A later reload replaced this one", returns false, and emits nothing; every other reload that is not a dry run emits once.

## Not in this issue

- Generating one table from the other, or moving chord resolution to one side.
- Making `applyConfig` safe to call from a test.
- Any other key mapping preset.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The fixture.** `nickel-helper/tests/fixtures/keyboard-layouts.json`: for each of `dvorak` and `colemak`, the key notation mapped to the name of the key it resolves to. Only the entries a layout changes need to be there if both sides can produce that view.
- **The reload seam.** A small type that owns the counter now held in `lastReloadStarted`: it hands out a ticket when a reload starts and answers whether a ticket was overtaken. The early return and the `defer` both read it. The test starts two reloads against it and checks that the first one's path emits nothing and the second's emits once, using `configReloadEvent` for the event.
- **The handoff.** Its line saying the two tables have no parity test, and the comment at the early return, are updated to say what now holds them.

## Done when

- [ ] Changing one entry in the helper's Dvorak table fails a Rust test; changing the same entry in `KeyboardLayoutMaps.swift` fails a Swift test. The pull request says both were seen to fail.
- [ ] A Swift test shows a superseded reload emits no `config-reloaded` and the reload that overtook it emits one. It fails when the early return is moved below the emitting `defer`, and the pull request says that was seen.
- [ ] A dry run still neither overtakes a reload nor is overtaken, in a test.
- [ ] No test calls `reloadConfig` or `applyConfig`.
- [ ] `make check` passes on the host and in the guest.

There is nothing to see or operate in this issue.

## Sources

- The **Declined** list of pull request [#33](https://github.com/prateek/winmux/pull/33).
- [`docs/events.md`](https://github.com/prateek/winmux/blob/fork/docs/events.md)
