# Sidebar arrangement proof tools

Run these only in the assigned guest, through the VM skill. Use the rich desk at
1920 × 1080, window tabs on, sidebar pinned and Splits shown. The builder's evidence
is separate from the final-commit demo pass.

Push this directory to `~/sidebar-arrange-proof` and the existing `sidebar-tree`
proof directory to `~/sidebar-tree-proof`. Compile its `ui.swift` to
`~/sidebar-tree-proof/ui`. The existing `configs/both-320.ncl` enables the tree
levels; copy it to the desk's config and reload after staging. The VM skill owns
build, launch and permission handling.

Compile `buttons.swift` to `~/sidebar-arrange-proof/buttons` in the guest. Each
drag checks the combined-session mouse-button state before and after input. Keep
the trailing wait after mouse-up: early takes whose `cliclick` process exited
immediately after `du` sometimes left a held drag. A subsequent delivered release
committed that same drag. Those takes are input failures, not layout evidence.

`live.py` discovers row coordinates through AX and drives one `cliclick` invocation
per drag. `dm` emits drag movement; `m` alone did not show a held preview. Output
goes to `~/takes/sidebar-arrange`: screenshots before/during/after, AX snapshots,
the exact pointer input, `list-windows`, Column readbacks and `agent query` raw
trees. It waits before reading WinMux instead of polling a pending refresh.

Examples, inside a `vm ssh` command:

```sh
python3 ~/sidebar-arrange-proof/live.py snapshot original
python3 ~/sidebar-arrange-proof/live.py drag pair-stacked desk 'winmux.ncl — winmux.ncl' bottom 1 0
python3 ~/sidebar-arrange-proof/live.py menu menu-tabs 'Horizontal tiles' Tabs
python3 ~/sidebar-arrange-proof/live.py menu menu-back-to-split '@tabs:2' 'Split side by side'
python3 ~/sidebar-arrange-proof/live.py click glyph-flip 'Flip to stacked'
python3 ~/sidebar-arrange-proof/live.py release option-release desk 'winmux.ncl — winmux.ncl' left 1 0
```

The final two numeric arguments select duplicate source/target labels. `release`
holds Option over a zone, releases it without moving the pointer, captures the
plain preview and drops with Option up. `@tabs:2` selects a two-tab header.

Before any arrangement, seed the existing restager from the original snapshot:

```sh
mkdir -p ~/takes/sidebar-tree
cp ~/takes/sidebar-arrange/original.windows.txt ~/takes/sidebar-tree/original.windows.txt
cp ~/takes/sidebar-arrange/original.tree.json ~/takes/sidebar-tree/original.agent.json
cp ~/takes/sidebar-arrange/original.columns.json ~/takes/sidebar-tree/original.columns-2.json
~/winmux/.build/debug/winmux list-columns --workspace 3 --json > ~/takes/sidebar-tree/original.columns-3.json
```

`paired.zsh <name> <tree>` restarts a built tree, restores those same fourteen
windows, exercises `layout vertical`, restores again and performs a plain sibling
drop. Run it on the separately built base and feature trees with names `base` and
`feature`. The baseline needs its own helper, Sparkle framework and Git directory,
as the VM skill describes. This script closes no desk apps and publishes nothing.

`verify.py <capture-directory>` checks the builder's named arrangement captures,
Column widths, modifier-release result and exact base/feature equality. The
capture index records which screenshots were visually read; the verifier alone
does not establish appearance. Installed-build use and physical hardware checks
remain in the draft.

Pass a plain-take prefix as a second argument to require every drop in that set
to make siblings. The final `base-verified` and `feature-verified` sets also require
the before/after mouse-button records. The earlier undrained-input takes remain
for diagnosis and are not used as completed-drop evidence.
