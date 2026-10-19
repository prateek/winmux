# Sidebar tree capture index

The pick follows Prateek's 2026-10-18 choice. The first pass's native desk and comparison takes are retained; the follow-up records the picked tree in Safari at 1920 × 1080 and replaces published extension references with live guest captures.

Only displayed icons, baseline and extension images remain in `img/`. **Page screenshots are driver-owned evidence outside the branch**, under `captures/pick/` in the relay state directory. Names below are relative to that directory. Full desktop originals contain browser file URLs; crop browser chrome before publishing. The committed baseline/extension images omit those paths.

## Native baseline

`img/today-N-collapsed.png` and `img/today-N-expanded.png`, N = 1…4, show the original rich desk's compact and hovered sidebar. The follow-up corrected a centered-crop error from the retained full originals: the crops now start at the left edge, omit the menu bar, and show the actual 50-point native rail / 280-point panel.

The native sidebar already groups multi-child tab groups, but flattens splits and omits Columns. `raw/end-workspace.txt`, `raw/end-focus.txt` and `raw/end-windows.txt` retain the first pass's fourteen-window final readback. New page drops edit only the in-page fixture, never native windows.

## The pick in Safari

Each named still has a matching `.txt` accessibility readback where relevant. Drag takes also have `-target.png` stills during the held drag. `drag.swift` posts actual mouse-down, dragged and mouse-up events.

| Capture | What it proves |
| --- | --- |
| `collapsed.png` | Four workspace numbers only, with the focused number's neutral rounded highlight |
| `hover-flat.png`, `flat-pinned.png` | Hover opens the default shallow tree; pin keeps it expanded; proportional marks and grouped tabs/floaters remain |
| `window-column-hover.png` | Hovering a Safari window outlines workspace 2's actual Column 2 mark |
| `splits-only.png`, `columns-only.png`, `both-levels.png` | Independent workspace 2 toggle states on the untouched desk. Workspace 2 initially has no split, so Splits does not invent one |
| `sibling-before.png` | Notes moves before the upper Ghostty window in its hidden vertical split; the sketch has Notes above the two Ghostty tiles |
| `sibling-after.png` | Notes moves between the two Ghostty windows; the sketch shows the same order |
| `floating-tiled.png` | Calculator leaves its floating group and joins the actual Ghostty split as a tiled sibling |
| `refuse-self.png`, `refuse-descendant.png` | Self and group-on-own-tab drops show the cycle reason without moving the tree |
| `refuse-workspace-drag.png`, `refuse-column-drag.png` | Fixed workspace and Column headings cannot start a layout-node drag; the status explains why |
| `column-sibling-flat.png`, `column-sibling-sketch.png` | Ghostty joins Notes in workspace 2 / Column 1, forming a vertical split while levels are hidden; focusing that workspace exposes the destination sketch |
| `splits-only-after-sibling.png` | Only workspace 2 reveals the new vertical split; Columns remain marks |
| `columns-only-after-sibling.png` | Only workspace 2 reveals Column rows; the split remains flattened |
| `both-after-sibling.png` | Workspace 2 → Column 1 → vertical split → Notes/Ghostty. Other workspaces retain their defaults |
| `config-both.png`, `config-reloaded-hover.png` | Both defaults set every workspace and survive a reload; hover reveals the restored starting state |
| `selftest-top.png`, `selftest-pick.png`, `selftest-50.txt` | All 50 fixture rows pass in Safari |
| `final-flat.png` | Defaults restored to false and the original fixture restored |

The pick's two states measure **307 points** in Safari and Chromium: flat tree height 625, both-level height 817 in Chromium. The retained rail is included. Default width is 320. Headless assertions verify no title clips at the measured threshold and that clipping starts two points below it.

## Search counts and positions

Every search below ran on the restored fixture. Counts are read from the page's output, with the actual titles present in its Safari accessibility readback.

| Query | Count | Match positions in the pick | Evidence |
| --- | ---: | --- | --- |
| Empty | 14 | Workspaces 1/2/3/4 contain 4/5/3/2 windows, including Updater and Calculator | `final-flat.png/.txt` |
| `Safari` | 3 | Workspace 2 → actual Column 2 → Safari tabs; match rows 1–3 are Lenses and Search, Fixed Columns, Subscription events. With levels off these are outline rows 3–5, below workspace and Tabs · 3, depth 2 | `search-Safari.png/.txt` |
| `Grievances` | 1 | Workspace 3 → actual Column 1 → TextEdit tabs → Grievances.rtf; first matching window, outline row 3, depth 2 | `search-Grievances.png/.txt` |
| `qzxnomatch` | 0 | No workspace or window rows | `search-qzxnomatch.png/.txt` |

Headless checks separately confirm exact matching window IDs, disclosure restoration after clearing, independent toggles, each config default and reload, all reference-image states and no JavaScript errors. [pick-results.json](pick-results.json) contains 29 browser assertions and all 50 fixture rows. [browser-results.json](browser-results.json) contains the 43 original A/B/C assertions, rerun with the final pick.

[rule-reversion.json](rule-reversion.json) pairs old and restored results. The builder physically disabled the pick's drag-decision branch, restoring first-pass decisions: all **20 changed-rule rows failed**, while 9 unchanged pick rows passed. Restoring the branch made all 29 pick rows pass. This is a combined old-rule reversion, not a claim of 20 separate selective mutations.

## Live browser trees

The page displays all six live images through its capture selectors. The sources and versions are in [references.json](../references.json).

- `img/tst-live-expanded.png`: four workspace roots, Column/tab-group parent tabs, nested Safari/TextEdit branches and workspace 4 folded. `tst-live-collapsed.png` folds all four roots.
- `img/tst-live-search.png`: **TST Tab Search 0.0.7**, a separately installed helper, filters `Grievances` to **1 / 1**, under workspace 3 → TextEdit tabs. Its ancestors remain visible while unrelated rows shrink. Tree Style Tab itself delegates search to helpers; this is explicitly labelled on the page.
- `img/sidebery-live-expanded.png`: the same four roots, a real **Safari-tabs** group page, a nested branch and workspace 4 folded. The navigation bar has the main panel plus a **Writing** panel with Sidebery's initial new tab. `sidebery-live-collapsed.png` folds all four roots.
- `img/sidebery-live-search.png`: Sidebery's built-in filter, configured always shown, finds **1 Grievances** tab in the main panel. It shows the matching row without the tree's ancestor rows; the Writing panel remains separate.

Both extensions were installed from Mozilla Add-ons in a fresh guest-only Firefox profile; their Firefox permission confirmations were accepted. They were enabled one at a time to avoid their tab-order conflict. Real local tabs were created with opener relationships through guest-only Marionette; folds, group/panel dialogs and search used the extension UI. Private inventory readbacks confirm Tree Style Tab 4.4.9, Sidebery 5.6.1 and Sidebery's actual group-page URL.

The macOS **“Firefox” Notifications** permission banner was dismissed with its close control; no macOS permission was granted. Published fallback screenshots and their metadata entries are removed. All remaining images are flat UI or app icons, so remain PNG; no photographic capture needs JPEG conversion.

## First-pass comparison evidence

The driver retains A/B/C page takes, insertion/group/sketch details, light/dark views and the original three search queries. Their former `img/page-*`, `img/B-*`, width/selftest/comparison and permission-dialog images were moved to driver-owned evidence. The variants still use the original rules, including refusing a window as a parent and refusing floating-to-Column drags.

## Verification boundary

Host and pinned Swift 6.4 guest `make check` pass on unchanged production sources: 1,657 Swift tests each, 171 Python script tests (one expected guest sync-metadata skip), and the helper suites. The follow-up also syncs/builds the guest and starts/stops that debug build; its doctor/layout readbacks are private driver evidence, not a second staging claim.

No GitHub CI, installed-build behavior, second display or real sleep/wake/unlock is claimed. The driver owns push/PR/CI and final-commit demos; Prateek's native/hardware checks remain unticked in the feature draft.
