# Sidebar drops beneath fixed chrome

Run only in an assigned 1280 × 720 guest, through the VM skill. Export the
driver's `TART_HOME` in every host shell. Preserve the guest's disk and display,
grant no permission prompt, and leave the guest running.

Sync the branch to `~/winmux`, run `vm build` and `vm check`, and push this
directory to `~/chrome-proof`. A check can replace the debug build directory;
copy the fetched Sparkle framework beside its executable before launch when
needed, as the VM skill describes. `setup.sh` compiles the existing demo stage,
sidebar accessibility reader and pixel-scroll driver. It starts fifteen owned
windows, assigns three to each of five workspaces and uses isolated demo config
and state. It quits the previous debug manager and stage process first.

Through `vm ssh`, run:

```sh
bash ~/chrome-proof/setup.sh winmux feature
python3 ~/chrome-proof/cases.py fixed 2 pager
python3 ~/chrome-proof/cases.py feature 2
```

Build an archive of `1d050ade` at `~/chrome-base`, initialized as a Git tree,
with its own helper, debug executable and adjacent Sparkle framework. Push that
archive with `vm push`, and build it over `vm ssh`. Then run the same cases:

```sh
WINMUX_CLI=~/chrome-base/.build/debug/winmux bash ~/chrome-proof/setup.sh chrome-base base
WINMUX_CLI=~/chrome-base/.build/debug/winmux python3 ~/chrome-proof/cases.py base 5 pager
WINMUX_CLI=~/chrome-base/.build/debug/winmux python3 ~/chrome-proof/cases.py base 5
```

Each case resets membership, waits without issuing read-only WinMux commands,
scrolls with the existing sidebar-tree driver, and reads accessibility geometry.
The paired title-bar pager case first moves its source out and back so both
builds start that take with the source in the same tile.
The scroll viewport is y=52–573. Workspace 5 spans y=514–631; its centre is
inside the sidebar while about half is hidden. Pager drops land at (160, 580),
seven points below the viewport and inside the title-bar path's vertical slop.
The source section is fully visible. The `edge` cases land on workspace 5's
visible header, `visible` on workspace 3, and `new` on New Workspace after
scrolling to the bottom.

Captures go to `~/takes/chrome-drops`: before/held/after screenshots,
accessibility frames, exact pointer commands, `list-windows`, agent trees and
asserted destination summaries. Each input sequence has a trailing wait after
mouse-up. Readbacks follow a fixed six-second quiet interval. No Search is used.

After pulling the directory, run `python3 verify.py <captures>`. It checks all
fifteen windows against window lists and raw trees, identical base/feature inputs
and destinations for five unchanged cases, and identical pager inputs producing
base workspace 5 versus fixed workspace 2. Inspect the held screenshots for the
section highlight and after screenshots for restored or removed source tiles.
The top-chrome and monitor-chip cases are covered by unit tests; this fixture
requires only one display.

Quit debug WinMux and the owned stage process at the end. The driver owns the
final-commit demos, CI, publication and guest deletion.
