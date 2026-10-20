# focus-back and mark from a window in native fullscreen

Part of {{UMBRELLA}}.

## What to build

WinMux's `focus` never points at a window in macOS native fullscreen: while you are in one, `focus` is the most recent other window on that window's workspace, or none. **focus-back, mark and jump** reads that `focus`, so from a native-fullscreen window `focus-back` picks the window you are in and does nothing, and `mark a` marks that other window or exits 1. The Filter context's `previous` is that fullscreen window itself, by design and pinned by `ContractRecordsTest`, and `focus-back` agrees with it, as its issue's Decision asks.

Three review rounds on #300 tried to fix it inside that pull request; each fix opened a window the next round found. This issue gives it one design and the tests for every window those rounds found.

## Decisions

- **One read-time source for the window the person is in.** It is the stored focus's window (`_focus`, which keeps a native-fullscreen window that the live `focus` drops) when that window sits in `MacosFullscreenWindowsContainer` at the moment it is read, and otherwise `focus`'s window. No second variable is kept in step with `setFocus`; #300's second design did that and missed a move into fullscreen, `setFocus`'s early return and moves that leave macOS focus where it was.
- **`focus-back`** goes to the most recently confirmed window other than that one. **`mark`** with no target in its env marks that one.
- **The Filter context's `focused` and `previous` do not change.** `focus-back` and the Filter's `previous` then differ while you are in a native-fullscreen window, and the docs say so once.

## Depends on

- **focus-back, mark and jump**.

## Done when

- [ ] Tests: from a native-fullscreen window, `focus-back` returns to the window before it and `mark a` marks the fullscreen window; `jump a; mark b` from a fullscreen window marks the window jumped to; `jump f; mark b` into a fullscreen window marks it; `macos-native-fullscreen on; mark a` marks that window; a minimized window macOS still reports focused is not the window you are in; a project switch's focus hold leaves no stale fullscreen window.
- [ ] In a guest, a window in native fullscreen: `mark a` there, then `focus-back` and `jump a` round trip between it and a tiled window.
- [ ] `docs/cli.md` drops the native-fullscreen limit it states for `focus-back` and `mark`.

## Sources

- #300's review rounds two and three, and the round-three finding that proposed the read-time source.
