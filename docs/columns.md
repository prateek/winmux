# Columns

The fixed Columns model is implemented, but Columns cannot yet be enabled in a user config. The remaining work in **Fixed Columns: slots, the count invariant, Width presets** adds the Nickel config, width editing and the focused-empty outline. Ordinary workspaces continue to use plain tree tiling.

A Column has a one-based slot and a fraction of the workspace width. It can hold a window, a tab group or splits in either direction. Empty Columns reserve their space and inner gaps. Closing their last window leaves the other Columns in place.

In the model, arriving tiling windows fill the nearest empty Column, measured from the focused Column, with ties going left. If every Column is occupied, an arrival joins the focused Column as a tab group. When focus is elsewhere, placement uses the most recently used tiling Column. The automatic tab-insertion setting does not override Columns placement.

At a Column edge, `move left` and `move right` move into the adjacent Column, joining a tab group if it is occupied. Moves stop at the workspace's edges; `move up` and `move down` also stop at a Column's top or bottom. Within a Column, existing movement applies. Directional focus skips empty Columns.

The root remains horizontal with tiles layout. A pass after flatten normalization assigns slots to unindexed arrivals, folds excess children and reapplies fractional widths. Layout uses slot positions even when the root's children list has gaps. Closed-window-cache records retain slots.

Width presets, free Column resizing, divider drag, resetting widths with `balance-sizes`, config precedence and reload are not implemented yet. The model stores declared and current width fractions; tests exercise unequal fractions and a monitor-size change. There is no user-facing Column-width operation or empty-Column focus command in this slice.

See [the build issue](https://github.com/prateek/winmux/issues/11) for the complete config contract and acceptance criteria. Config examples will be added with the config implementation and checked against the real helper.
