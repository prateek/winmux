# Nested policy run chains

`winmux.ncl` and `trials.py` are a scratch-config live comparison for the base
commit `160dabd3` and this change. Run only inside the issue's owned VM through
`vm ssh`; debug WinMux must never run on the host desktop.

Keep the config outside its XDG config parent. Launch the selected tree's
WinMux debug app with fresh scratch config/state directories and its own release
Nickel helper. Run `workspace 2` and `workspace 3` before staging. These commands
create automatic numbered slots; creating a literal `3` via Arrive first would
leave it outside the numbered command targets. The config keeps slots 1–3
persistent. Start the owned `stage.swift` fixture with `Source anchor`,
`Three left`, `Three right`, `Ping anchor` and `Pong anchor`. Initialize an
archived base tree with `git init` before building it.

Run inside the guest:

```sh
python3 ~/winmux/.scratch/winmux-fork/proofs/nested-run-chains/trials.py ~/winmux feature 0.5 Ping
python3 ~/winmux/.scratch/winmux-fork/proofs/nested-run-chains/trials.py ~/winmux-base base 0.3 Pong
```

Restart the app and fixture between builds. Each invocation checks three fresh
Chain windows, resetting declared widths before each; a dry-run preview against
a Place with a Run list; the Ping/Pong loop; and the preserved floating-to-tiling
transfer path. It saves complete CLI transcripts, JSON and screenshots under
`~/takes/<label>`. A brief quiet period and `doctor` precede new-window inventory
reads to avoid starving detection with read-only polling. No Search is used.

The builder report holds the observed results and toolchain checks. Final-commit
PR demos belong to the driver's demo pass.
