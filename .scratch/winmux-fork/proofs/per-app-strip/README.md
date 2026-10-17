# Per-app card comparison

Stage the demo skill's rich desk once in a fresh 1920×1080 guest, after the host
and guest checks. Keep the desk open between both builds. The current desk has
fourteen windows with nine app names and ten app processes (Ghostty runs twice).
App entries use process identity, so this proof starts at ten and adds one Atlas
window to reach eleven.
Both builds reuse the staged desk's state directory to preserve workspace and
tiling membership across their restart.

Push this directory to `~/per-app-proof`. Put the base tree at `~/winmux-base`
using `vm push`, initialize its `.git` directory, and build it using `vm ssh`.
The head tree uses `vm sync` and `vm build`. Every guest invocation goes through
the VM skill; set `TART_HOME` in its shell first.

Run these commands through `vm ssh`, in this order:

```sh
zsh ~/per-app-proof/live.zsh ~/winmux-base base
zsh ~/per-app-proof/measure.zsh ~/winmux-base base
zsh ~/per-app-proof/live.zsh ~/winmux head
zsh ~/per-app-proof/measure.zsh ~/winmux head
```

Pull `~/per-app-captures` using `vm pull`. Each build gets the same five whole-screen
stills, Lens traces before and after Escape, exact app inventories, workspace
readbacks, native geometry and MRU order. No Search is used. Take crops from the
whole-screen stills, preserving the originals. Inspect every still for permission
prompts; a WinMux or capture-tool permission prompt stops the live run unanswered.

The measuring tool compiles the actual tree's `Tile.swift` and `GridLayout.swift`.
Its two stubs replace unrelated runtime objects; no packing or font-measurement
code is copied. It reconstructs representative windows from the captured MRU
order and queries the guest's visible screen size. Compare its frames with the
screenshots: native geometry is an independent readback, not the Lens's layout
cache. The 88-point cap and bare-number count are numerical experiments only;
neither is enabled in the app. First wrapping uses successive prefixes of the
same app-sorted desk.

Restarting WinMux between the two builds can leave Ghostty floating and Atlas tiled differently, so the base and head stills of window entries are not the same desk. Per-app cards show the change regardless; for like-for-like numbers run both measuring tools on one build's `*-world.json`.

The driver films final-commit PR demos separately. Installed-build behavior,
a second display and real sleep/wake/unlock remain human checks. Leave the guest
up; quit WinMux before closing the staged apps at the end of both runs.
