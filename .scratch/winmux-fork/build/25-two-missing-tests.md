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
- **The reload seam (changed).** `ConfigReloadSequence.run` owns the counter, the overtaken early return and the watcher/event `defer`. `reloadConfig` supplies loading, overtaken cleanup, the remaining work, watcher sync and event emission as closures. The rest fills `ConfigReloadResult` with path, diagnostic and watcher outcome, including before throwing. A counter-only seam cannot meet the Done-when mutation check: moving the return below the emitting `defer` must fail a test of the seam itself.
- **The handoff.** Its line saying the two tables have no parity test, and the comment at the early return, are updated to say what now holds them.

## Done when

- [x] Changing one entry in the helper's Dvorak table fails a Rust test; changing the same entry in `KeyboardLayoutMaps.swift` fails a Swift test. The pull request says both were seen to fail.
- [x] A Swift test shows a superseded reload emits no `config-reloaded` and the reload that overtook it emits one. It fails when the early return is moved below the emitting `defer`, and the pull request says that was seen.
- [x] A dry run still neither overtakes a reload nor is overtaken, in a test.
- [x] No test calls `reloadConfig` or `applyConfig`.
- [x] `make check` passes on the host and in the guest.

## Build evidence

The Dvorak and Colemak `p` entries were each changed from physical `r` to `t`, independently in Rust and Swift. All four parity runs failed at their expected equality assertions; the tables were restored. Moving the overtaken return below the emitting/watcher `defer` failed both superseded tests on unexpected events and watcher syncs; it was restored. The new tests pass with the original tables and ordering.

`ConfigReloadSequenceTest` uses continuations with the house serial executor, without sleeps or FSEvents streams. It covers both superseded completion orders, both dry-run interleavings, ordinary success/load failure and emission plus watcher sync before rethrow. The test tree has no calls to the live reload/apply functions.

Decided: use `ConfigReloadSequence` with a per-attempt result object, so the emitting `defer` observes path, error and watcher outcome even when the rest throws. This changes **The reload seam** default to meet its ordering mutation check; the fixture and handoff defaults are unchanged.

There is nothing to see or operate in this issue.

## Sources

- The **Declined** list of pull request [#33](https://github.com/prateek/winmux/pull/33).
- [`docs/events.md`](https://github.com/prateek/winmux/blob/fork/docs/events.md)
