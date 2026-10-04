# The Lens look prototype

Open `index.html` in a browser. The top half shows one fourteen-window desk captured in native Cmd-Tab, Mission Control, AltTab and the three WinMux Lenses as they were at `f438e690`. The bottom half is a working stage: one set of Tile switches drives the grid, the strip, the list and miniatures.

Click the desk first. Arrow keys move the selection, Space zooms the selected window to its real size and place, holding Option shows the hints, and G changes the grouping.

The page opens on the settings Prateek chose. The Lens issues in `../../build/` take their sizes, spacing and motion from it, read at 1920 by 1080.

The captures in `img/` were taken in a Tart guest. `cap-alttab.jpg` is a screenshot of AltTab, which is GPL-3; it is here for comparison and nothing of AltTab's is used in WinMux.

## The desk in the captures

`desk/` holds what dressed the fourteen-window desk the captures and the Lens issues refer to: four workspaces, two with Columns, two tab groups and two floating windows. It is not part of the `demo` skill yet.

To stage it in a guest that already has the `demo` skill's desk (`.claude/skills/demo/desk/`) and a built WinMux at `~/winmux`: copy `desk/` to `~/rich` in the guest, set the display to 1920 by 1080, and run `~/rich/stage-rich.sh`. It prints the windows and the Columns it made.
