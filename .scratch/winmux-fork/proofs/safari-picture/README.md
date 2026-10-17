# Safari picture proof

`windows.swift` prints every CoreGraphics window owned by Safari, including off-screen
windows, followed by its AX window roles, subroles, titles and frames. It does not ask
Safari for Automation access.

`live.zsh <tree> <label>` runs inside the 1920×1080 guest after `stage-rich.sh`. Push this
directory to `safari-proof` with `vm push`, then run it with `vm ssh`. It writes to
`~/safari-captures/<label>`: the entry inventory, all Safari CG/AX records before and after
each view, the Lens debug log, the world query, screenshots and active-session traces.
It primes each workspace and each Safari tab before opening grids by workspace, by app,
and without sections, followed by the held Cmd-Tab strip. It waits eight seconds before
each screenshot. The rich desk explicitly binds Cmd-Tab to `recent`.

Set `OPEN_NEW_WINDOW=1` for a second run. The script opens the local Lenses page with a
distinct query string, waits twelve seconds without calling WinMux, records the new id,
and closes only that new window after the four captures. Opening the exact existing URL
can focus its existing page instead of making a window.

Use the same script for the base, comparison and changed trees. Each tree needs its own
matching Nickel helper and an initialized Git directory before the debug app starts.
Do not overlap live runs or replace their scripts while they run. Dogfood.13 has no
named `windows` Lens, and its CLI-opened strip commits before drawing; the explicit
all-window Filter and held strip make the script work on all three trees.

The original dogfood.13 logs capture starts but neither requested nor returned pixel
sizes. Base and changed builds log `thumbnail start` and `thumbnail captured`; the
changed build also logs `screenshot entry=… captured=…` at SCWindow selection. For a
Frozen Tile, correlate its screenshot with the most recent successful departure capture
before that opening, rather than expecting a live capture on the hidden workspace.

`extras.zsh <tree>` narrows Safari's Column from 0.44 to 0.35, records its actual frame
and fresh grid picture, opens the one-match Search `Subscription`, and checks Peek. It
restores the Column width. `flip.zsh <tree>` temporarily enables double-sided windows
through the guest's global preference, restarts the debug app, records the two TextEdit
faces and their focus readbacks, quits the app and restores that preference. Their output
directories are `head-extras` and `head-flip` beside the main runs.

The required layer-0 rule also rejects the staged Updater's real layer-3 dialog. It shows
an icon on the changed build; the other apps' layer-0 windows retain their pictures. This
is a visible policy consequence, not evidence that Updater was a Safari helper.

The standing desk is skipped after the rich desk while **The standing desk does not
stage after the rich desk in the same guest** remains unresolved. No installed-build,
second-display or real sleep/wake/unlock check is represented by these scripts.
