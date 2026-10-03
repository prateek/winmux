# Contracts for WinMux's config. A config imports this file and applies `Config` to itself:
#
#   let W = import "winmux/winmux.ncl" in
#   ((import "winmux/defaults.ncl") & { … }) | W.Config
#
# `Config` checks the config's shape: every key it knows, and nothing else. WinMux checks the
# values that have a syntax of their own (commands, key names, monitor patterns) when it applies
# the config.
let Contract = import "contract.ncl" in
let Int = std.number.Integer in
let Choice = fun tags => std.contract.Sequence [std.enum.TagOrString, tags] in

# One command, or several run in order.
let Commands = std.contract.any_of [String, Array String] in

# A number, or a per-monitor list that ends in the fallback number:
# `[{ monitor."built-in" = 8 }, 12]`.
let PerMonitor = std.contract.any_of [Int, Array Dyn] in

# One monitor pattern, or a list of them: `1`, `"main"`, `"secondary"`, a name pattern.
let Monitors = std.contract.any_of [Int, String, Array Dyn] in

let Mode = {
  binding | { _ | Commands } | optional,
  binding-tap | { _ | Commands } | optional,
} in

let WorkspaceSidebar = {
  enabled | Bool | optional,
  enable-focus | Bool | optional,
  auto-hide | Bool | optional,
  always-expanded | Bool | optional,
  collapsed-width | Int | optional,
  width | Int | optional,
  monitor | Monitors | optional,
  show-status-pills | Bool | optional,
  show-clock | Bool | optional,
  show-seconds | Bool | optional,
  show-date | Bool | optional,
  show-weekday | Bool | optional,
  chrome-style | Choice [| 'liquid-glass, 'solid |] | optional,
  solid-chrome-color | String | optional,
  solid-chrome-custom-color | String | optional,
  menu-bar-reserve-height | Int | optional,
  project-deletion-action | Choice [| 'close-windows, 'move-windows-to-fallback |] | optional,
  # The names and colours the sidebar starts with. Renaming or recolouring in the sidebar is
  # kept by WinMux outside this file and takes precedence.
  workspace-labels | { _ | String } | optional,
  project-labels | { _ | String } | optional,
  project-colors | { _ | String } | optional,
} in

let LensFields = {
  filter | Dyn -> Dyn -> Bool | optional,
  presentation | std.contract.Sequence [Choice [| 'list, 'strip, 'miniatures, 'grid |], std.contract.from_predicate (fun p => p != 'grid && p != "grid")] | optional,
  entries | Choice [| 'window, 'app |] | optional,
  sections | Choice [| 'none, 'workspace, 'project, 'monitor, 'app |] | optional,
  sort | Array (Choice [| 'mru, 'previous, 'spatial, 'workspace, 'app, 'title, 'created |]) | optional,
  keys | { _ | Commands } | optional,
  popups | Array (Choice [| 'accessory-popup, 'app-popup |]) | optional,
  frozen-thumbnail | Choice [| 'plain, 'age-badge, 'pause-badge, 'dimmed |] | optional,
  accessory-window | Choice [| 'enlarged, 'actual-size |] | optional,
  summon-hints | Array (Choice [| 'label, 'landing-spot, 'target-workspace |]) | optional,
  enabled | Bool | optional,
} in
let Lens = LensFields & {
  presentation | default = 'list,
  entries | default = 'window,
  sections | default = 'workspace,
  sort | default = ['mru],
  keys = {
    enter | default = "focus",
    shift-enter | default = "summon",
    alt-enter | default = "summon",
    cmd-w | default = "close",
    cmd-1 | default = "move-node-to-workspace 1",
    cmd-2 | default = "move-node-to-workspace 2",
    cmd-3 | default = "move-node-to-workspace 3",
    cmd-4 | default = "move-node-to-workspace 4",
    cmd-5 | default = "move-node-to-workspace 5",
    cmd-6 | default = "move-node-to-workspace 6",
    cmd-7 | default = "move-node-to-workspace 7",
    cmd-8 | default = "move-node-to-workspace 8",
    cmd-9 | default = "move-node-to-workspace 9",
  },
  popups | default = [],
  frozen-thumbnail | default = 'dimmed,
  accessory-window | default = 'enlarged,
  summon-hints | default = ['label, 'landing-spot],
  enabled | default = true,
  when | { _ | LensFields } | optional,
} in

# The contracts for the records WinMux hands to Filters and Policy hooks (`Window`,
# `FilterContext` and the rest) and `contract-version` come from contract.ncl.
Contract
& {
  # A yes/no function over a window, given the Filter context. Its arguments are `Dyn`, not
  # `Window` and `FilterContext`: WinMux checks every record before it reaches a Filter, and
  # checking it again on each call makes a Filter several times slower. A Filter called with the
  # wrong arguments still fails, at the field it reads.
  Filter = Dyn -> Dyn -> Bool,

  Config = {
    config-version | Int | optional,
    # The version of the Filter contract the config was written for. Accepted and ignored: at
    # version 1 no config can lag behind.
    contract-version | Int | optional,

    start-at-login | Bool | optional,
    reload-on-save | Bool | optional,
    automatically-unhide-macos-hidden-apps | Bool | optional,
    automatically-tile-new-windows | Bool | optional,
    enable-shake-to-toggle-tiling | Bool | optional,
    auto-add-new-windows-to-tab-group | Bool | optional,
    enable-normalization-flatten-containers | Bool | optional,
    enable-normalization-opposite-orientation-for-nested-containers | Bool | optional,
    default-root-container-layout | Choice [| 'tiles, 'tab-group |] | optional,
    default-root-container-orientation | Choice [| 'horizontal, 'vertical, 'auto |] | optional,
    shortcuts-preset | Choice [| 'none |] | optional,
    tab-group-padding | Int | optional,
    persistent-workspaces | Array String | optional,

    after-startup-command | Commands | optional,
    on-focus-changed | Commands | optional,
    on-mode-changed | Commands | optional,
    on-focused-monitor-changed | Commands | optional,
    exec-on-workspace-change | Array String | optional,
    exec
      | {
        inherit-env-vars | Bool | optional,
        env-vars | { _ | String } | optional,
      }
      | optional,

    key-mapping
      | {
        preset | Choice [| 'qwerty, 'dvorak, 'colemak |] | optional,
        key-notation-to-key-code | { _ | String } | optional,
      }
      | optional,
    mode | { _ | Mode } | optional,

    gaps
      | {
        inner | { vertical | PerMonitor | optional, horizontal | PerMonitor | optional } | optional,
        outer
          | {
            left | PerMonitor | optional,
            bottom | PerMonitor | optional,
            top | PerMonitor | optional,
            right | PerMonitor | optional,
          }
          | optional,
      }
      | optional,
    window-tabs | { enabled | Bool | optional, height | Int | optional } | optional,
    workspace-sidebar | WorkspaceSidebar | optional,
    workspace-to-monitor-force-assignment | { _ | Monitors } | optional,

    # Named Filters, and the Lenses that use them.
    filters | { _ | Filter } | optional,
    lenses | { _ | Lens } | optional,
  },
}
