# Hook capture proof

Use only in the assigned guest through the VM wrapper. Export its required
`TART_HOME` before every shell invocation. These scripts do not manage guests.

Push this directory to `hook-proof`, sync/build the feature tree in `winmux`, and
build an archive of the base in `hook-base`. The base needs a Git repository and
Sparkle beside its executable, as the VM guide describes. Both builds use the
feature tree's unchanged helper binary.

Save the guest's Ghostty config, then stage `ghostty.config` in its place. It
uses a fixed title and disables shell integration to reduce title/document
changes between arrival and the immediate readback. A new window can still have
an empty AX title during discovery, and `lastFocusedSeq` advances after arrival;
`validate.py` prints every Window field and allows only those two transitions.
The ordinary-shell preliminary probe also updated its document after arrival.

Compile `.claude/skills/demo/keys.swift` in the guest as `demo/hook-keys`. Run
`bash hook-proof/live.sh` with its combined output saved as a transcript. It
checks the three Done-when items, file/stream equality, reload retention,
deadline extension, dry run, an edge Move and the boundary between helper and
later placement failures. It uses fixed waits before reading WinMux so a query
does not cancel window discovery. It writes evidence under `takes/hook-capture`
and ends with the debug build and owned windows closed.

Run `unchanged.sh` against each tree with labels `base` and `feature`, and save
each command transcript. `compare.py` compares inventory, native frames,
agent tree, Columns, dry-run output and the boundary result. It substitutes only
the owned window/pane id and removes process ids and snapshot metadata. Read the
saved screenshots as well as these model readbacks.

`file-error.sh` checks that Filters and config-check smoke calls do not add
records, a failed file write stops capture without a stream fallback, a failed
`on --json` still prints JSON status, and a later `on` recovers after the file
location is repaired. It also closes its owned window and debug build.

Restore the saved Ghostty config when finished. No Search, release, guest
resize, reboot or permission grant is part of this proof. An initial command-line
`-e` probe raised Ghostty's execution confirmation; it was cancelled. Use the
configured command above to avoid that screen.
