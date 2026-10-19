# Sidebar tree capture index

The native captures use the staged fourteen-window desk at 1920 × 1080. Today's sidebar was captured before Firefox opened. Prototype captures are Safari opening `index.html` from disk. Committed screenshots omit browser address bars and crop the baseline to the sidebar, keeping guest paths and account labels out of the public evidence. The relay retains the full originals, capture logs and Safari accessibility readbacks.

## Native baseline

`img/today-N-collapsed.png` and `img/today-N-expanded.png`, N = 1…4, are the compact and hovering native sidebar. Workspaces 2 and 3 show tab groups and Columns in the desk, while the sidebar shows tab groups but omits Columns. Workspace 1's split is flattened. All captures ended back on workspace 1, focused on Zed; `raw/end-workspace.txt`, `raw/end-focus.txt` and `raw/end-windows.txt` record that state before WinMux quit.

## Working prototype in Safari

For each V = A, B, C:

| Capture | Checked result |
| --- | --- |
| `img/page-V-expanded.png` | All fourteen windows, native-sized rows and the focused workspace's layout sketch |
| `img/page-V-collapsed.png` | Rail only after unpinning and moving off |
| `img/page-V-hover.png` | Rail expands after hover; pin can hold it open |
| `img/page-V-branch-collapsed.png` | Vertical Ghostty split collapsed, its two children hidden |
| `img/page-V-accepted.png` | First Ghostty window moves from workspace 1 to workspace 4 via its rail cell; one Ghostty remains in the source miniature |
| `img/page-V-refused.png` | Dropping that window on Zed's window row is refused; window inventory and layout remain unchanged |
| `img/page-V-search-safari.png` | Three Safari matches with their workspace/tab-group ancestry |

The relay also retains target-hover screenshots. `drag.swift` posts real mouse-down, dragged and mouse-up events. The native readbacks contain “Applied: move-node-to-workspace” or the window-parent refusal. The first capture tool used `cliclick` moves that did not initiate Safari drags; those takes were replaced after the tool was corrected.

## Every search used in the live page run

| Query | Count | Where the matches fall | Evidence |
| --- | ---: | --- | --- |
| Empty | 14 | Workspaces 1/2/3/4 contain 4/5/3/2 windows, including the two floaters | Expanded and final Safari captures/readbacks |
| `Safari` | 3 | Workspace 2 → Column 2 → tab group: Lenses and Search, Fixed Columns, Subscription events | `img/page-A-search-safari.png`, B and C equivalents; native `A/B/C-search-safari.txt` |
| `Grievances` | 1 | Workspace 3 → Column 1 → TextEdit tab group → Grievances.rtf | `img/page-C-search-Grievances.png` and native accessibility readback |
| `qzxnomatch` | 0 | No rows in any variant | `img/page-C-search-qzxnomatch.png` and native accessibility readback |

The headless browser run uses the same three nonempty queries. It checks all four rendered views, preserves disclosure state through search, and reads back the actual changed tree after every accepted drag. It also applies the full fixture rule table and checks clipping against rendered text widths. [browser-results.json](browser-results.json) records 43 successful assertions, the 21 fixture checks and per-depth measurements.

Additional Safari evidence is in `img/selftest.png`, `img/widths-light.png`, `img/comparison-light.png`, `img/comparison-dark.png`, `img/B-dark.png`, `img/B-insertion.png`, `img/B-destination-miniature.png` and `img/B-drag-end-collapse.png`. The insertion puts Notes between the two Ghostty siblings, empties workspace 2's Column 1 and updates its remembered-focus rail cue. The last capture shows the unpinned sidebar returning to its rail after a completed drag and pointer exit. `img/B-nested-group.png` and `img/B-nested-miniature.png` show the whole Ghostty split moving as one tab into Safari's group, then drawing its two children when selected.

## Extension references

All six `tst-published-*.png` / `sidebery-published-*.png` files are the projects' published Mozilla Add-ons screenshots, credited in the page and `references.json`. They are not live extension captures and do not depict the staged desk. Firefox's Tree Style Tab and Sidebery install prompts requested tab access; both were cancelled without a permission grant. Live extension branch/search checks are unavailable under that rule. No extension search count is claimed.
