# A strip with one entry per app draws badly

Part of {{UMBRELLA}}.

## What to build

A Lens with `entries = 'app` was captured as a strip in `0.5.6-dogfood.13` and has three faults.

- A card's title collapses to "…" behind its chips.
- A chip reads "1 windows".
- Ten apps fit one row at 164 by 117 points each. An eleventh wraps the strip to two rows and every Tile grows to 278 by 194.

## Decisions

- **The title is readable and the count is grammatical.**
- Per-app cards reserve their bar's whole measured width in both strip and grid: icon, gaps, the selected semibold title (capped at 240 points), and enabled chips. The bar floor relaxes with the title floor when needed to fit. Window-entry cards and picture/text Tiles retain their existing geometry.

## Not in this issue

- An icon-per-app Tile. It is under "Later, with no issue yet" in the umbrella.

## Depends on

Nothing.

## Defaults chosen for you

- **The jump at eleven** is the strip's row rule, fewest readable rows at the largest height, doing what it was built to do. Say in the pull request whether per-app entries should cap their height so a strip of apps holds one size.

## Done when

- [ ] A per-app card on the staged desk shows its app name whole and its chips beside it.
- [x] One window reads "1 window".
- [ ] The pull request shows ten and eleven apps before and after.

## Build and validation

Host and pinned-version guest `make check` pass: 1,404 Swift tests, 88 helper tests
and 138 script tests. Count, strip width and selected-title rendering regressions
fail with the fixes undone; feature-off tests cover both session layout paths.
Both layout caches include bar width. The strip's row-height rule is unchanged;
no app-specific height cap or bare-number count chip is built.

The staged desk's live comparison stopped on the capture client's private-window-picker
permission prompt, left unanswered. Base captures are invalid acceptance evidence;
head was not run live. The current rich desk has nine app names but ten app processes
(two Ghostty processes); the corrected proof driver counts processes and adds Atlas
for eleven. It also reuses the staged desk's state directory. These driver corrections
have a syntax check, but no successful rerun after the permission blocker.
The proof and measuring tool are in `.scratch/winmux-fork/proofs/per-app-strip/`.
The PR's ten/eleven comparison remains unchecked; the demo pass publishes its media.

- [ ] Installed-build behavior checked.
- [ ] A second display and real sleep/wake/unlock checked.

## Sources

- The switching comparison, 2026-10-07: `entries = 'app` with cards, pictures and text at three, fourteen and twenty-five windows.
