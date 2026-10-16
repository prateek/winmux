# Close-result desk fixture

Build `close-fixture.swift` with `swiftc` in the guest, then run `CloseFixture` over `vm ssh`.
It opens three regular-policy windows: a `[.titled]` window exposing a disabled AX close
button, a titled window whose `accessibilityCloseButton()` returns nil, and an ordinary
closable window. Pass its process id as the only argument to inspect the AX button paths.
The explicit disabled button makes that case reproducible on systems where a plain
`[.titled]` window exposes no AX close button at all.

`--ordinary` opens just the closable window, for the quit-if-last-window comparison.
While the fixture runs, writing `ordinary` to `/tmp/winmux-close-fixture-command`
opens another closable window without restarting the fixture or the desk.

The guest proof scripts save screenshots, traces and workspace readbacks under
`~/takes/close35/`. Run `unchanged.zsh <checkout> <prefix>` against each build.
`cli-failures.zsh` checks both absent and disabled buttons. `held-close.zsh strip|list <title> <prefix>` uses a real Cmd-Tab Hold; for list it converts the
held strip through the CLI before Cmd-W. It records both traces while Command
is still held. All scripts run through `vm ssh`. `show-transcript.swift` displays
a saved CLI transcript for screenshots.

For the TextEdit sheet case, enable its per-app `NSCloseAlwaysConfirmsChanges`
preference in the disposable guest before launching it. Focus its window explicitly
with the debug CLI before pasting test text; launch alone need not focus it.
`observe-sheet.py <checkout> <prefix> <window-id>` records CLI acceptance and timed
model snapshots. The held-strip script works with `WINMUX_CHECKOUT=<checkout>`
for the base comparison. Capture the sheet, then Cancel to inspect re-registration;
discard the owned test document and restore the preference after the run.
