# Quit-frame guest proofs

These fixtures run only in the driver's single-display, 1280×720 guest. Follow the VM skill;
export the driver's `TART_HOME` in every host shell and send every guest command through `vm`.
They launch and quit desktop apps and must never run on the host.

Push this directory to `~/quit-tools`, copy the synced demo `stage.swift` there, and compile
`frames.swift`, `quit.swift` and `stage.swift` to `frames`, `quit` and `stage` in the guest.
`frames` reads CoreGraphics bounds independently of WinMux. The scripts save readings,
screenshots, model listings and the tested process's unified log under `~/quit-proof/<case>`.

- `prepare-case.sh <case> [source-directory] [on|off|base]` launches five distinct windows,
  reads their frames, starts WinMux, moves Blue and Yellow to workspace 2, then opens Late.
- `finish-case.sh <case> [menu|event|signal]` quits and captures the result. The menu coordinates
  are for this guest size; inspect `menu-open.png` before relying on them in another setup.
  The debug status item's image can be blank; its actual hit area still opens the menu.
- `manual-case.sh` changes a startup window's floating frame and a late window's frame,
  reloads config, primes the cached actual frames once, then quits by Apple Event.
- `signal-case.sh` starts from a running, staged standing desk. It quits WinMux, adds five
  controlled windows, starts again, spreads the nine originals over three workspaces, opens
  Late and sends SIGTERM. `Quit frames finished` records restore wall time.
- `unchanged-case.sh <case> <source-directory> <config-name>` runs the same actions on a base
  archive and the new build with restoration off. It disables management before quitting to
  isolate centring from the base's in-flight layout writes. The base archive needs its own
  `.git` directory and build, as the VM skill explains.

After pulling captures, run `check-frames.py before.json after.json [closed-title]` for
restoration cases. It checks five stage originals and any standing-desk originals; a retained,
closed AppKit window may still appear in CoreGraphics but must stay off screen.
`check-centered.py after.json 179` checks setting-off cases. Use `149` for the base: its missing
30-point visible-origin offset is the intentional difference on this guest's main display.

Wait the scripts' fixed startup/new-window delays before querying WinMux. They do not poll
read-only commands during discovery. Close the staged apps and the desk's local docs server
afterward, leave the driver's guest running, and preserve `tart list` with the captures.
