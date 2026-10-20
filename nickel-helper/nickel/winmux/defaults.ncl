# The settings and bindings WinMux starts with. A config merges its own settings over these:
#
#   let W = import "winmux/winmux.ncl" in
#   ((import "winmux/defaults.ncl") & { gaps.inner.horizontal = 0 }) | W.Config
#
# Settings use default priority, so a config overrides them by setting the same field.
# Overview uses priority -1 above the contract's fallback. A config that does not import this file
# gets none of these settings.
let W = import "modes.ncl" in
{
  columns = { count | default = 'off, width-presets | default = [1/3, 1/2, 2/3] },
  auto-add-new-windows-to-tab-group | default = true,
  automatically-tile-new-windows | default = true,
  restore-windows-on-quit | default = true,
  automatically-unhide-macos-hidden-apps | default = false,
  default-root-container-layout | default = "tiles",
  default-root-container-orientation | default = "auto",
  enable-normalization-flatten-containers | default = true,
  enable-normalization-opposite-orientation-for-nested-containers | default = true,
  enable-shake-to-toggle-tiling | default = true,
  gaps = {
    inner = {
      horizontal | default = 8,
      vertical | default = 8,
    },
    outer = {
      bottom | default = 12,
      left | default = 12,
      right | default = 12,
      top | default = 12,
    },
  },
  key-mapping = {
    preset | default = "qwerty",
  },
  mode = W.modes & {
    cmd-tab = W.switcher { lens = "recent", key = "tab" },
    cmd-tab-back = W.switcher { lens = "recent", key = "tab", start = 'prev },
    cmd-backtick = W.switcher { lens = "app-windows", key = "backtick" },
    search-hold = W.hold { lens = "search", latch = "search" },
    overview-hold = W.hold { lens = "overview", latch = "browse" },
    window-once = W.transient { bindings = W.keys.navigate & W.keys.workspaces & W.keys.columns },
  },
  keymap = W.keymap & {
    main = W.when "mode == main" (W.keys.main-today & {
      alt-slash | default = "mode search-hold", alt-shift-o | default = "mode overview-hold",
      alt-semicolon | default = "mode window", alt-shift-semicolon | default = "mode window-once",
    }) & { priority = 0 },
    window = W.when "mode == window" (W.keys.navigate & W.keys.workspaces & W.keys.columns & W.keys.lenses & {
      alt-semicolon | default = "mode main", esc | default = "mode main",
    }) & { priority = 0 },
  },
  on-focused-monitor-changed | default = ["move-mouse monitor-lazy-center"],
  on-mode-changed | default = [],
  persistent-workspaces | default = [],
  reload-on-save | default = true,
  shortcuts-preset | default = "none",
  filters.floating | default = fun w ctx => w.class == 'floating,
  filters.same-app | default = fun w ctx => ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId,
  lenses.recent.presentation | priority -1 = 'strip,
  lenses.recent.tile | priority -1 = 'picture,
  lenses.recent.grid.tile-size | priority -1 = 'same-height,
  lenses.windows.presentation | priority -1 = 'grid,
  lenses.app-windows.presentation | priority -1 = 'grid,
  lenses.app-windows.sections | priority -1 = 'none,
  lenses.app-windows.filter | default = filters.same-app,
  lenses.overview.presentation | priority -1 = 'miniatures,
  lenses.search = {},
  lenses.floating.presentation | priority -1 = 'grid,
  lenses.floating.filter | default = filters.floating,
  start-at-login | default = false,
  url-scheme | default = true,
  tab-group-padding | default = 30,
  window-tabs = {
    enabled | default = true,
    height | default = 36,
  },
  workspace-sidebar = {
    tree = { splits | default = false, columns | default = false },
    always-expanded | default = false,
    auto-hide | default = false,
    chrome-style | default = "liquid-glass",
    collapsed-width | default = 50,
    enabled | default = true,
    menu-bar-reserve-height | default = 28,
    project-colors = {
      "default" | default = "#C4B5FD",
    },
    project-deletion-action | default = "close-windows",
    project-labels = {
      "default" | default = "Default",
    },
    show-clock | default = false,
    show-date | default = false,
    show-seconds | default = true,
    show-status-pills | default = true,
    show-weekday | default = true,
    solid-chrome-color | default = "midnight",
    solid-chrome-custom-color | default = "#191B20",
    width | default = 320,
  },
}
