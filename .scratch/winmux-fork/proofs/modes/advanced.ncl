let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  keymap.opt-in = W.when "mode == main" {
    cmd-tab = "mode cmd-tab", cmd-shift-tab = "mode cmd-tab-back", cmd-backtick = "mode cmd-backtick",
    ctrl-u = "focus right", cmd-ctrl-h = "focus right",
  },
  keymap.terminal-pass = W.when "mode == main && app == 'com.mitchellh.ghostty'" { ctrl-u = 'pass },
  mode.sequence = {
    unbound = 'consume, on-enter = "lens windows",
    binding = { "g t" = "lens step next", l = "lens step right" },
  },
  mode.counting = {
    unbound = 'consume, count = true, on-enter = "lens windows",
    binding.l = "focus dfs-next",
  },
  mode.sequence-global = {
    unbound = 'consume, binding = { "g t" = "mode main" },
  },
  mode.keypad-global = { unbound = 'consume, binding.enter = "mode main" },
}) | W.Config
