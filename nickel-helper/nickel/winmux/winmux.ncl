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

let LensKeys = std.contract.Sequence [
  { _ | Commands },
  std.contract.from_validator (fun keys =>
    if std.array.all (fun key =>
      !(std.array.elem (std.array.last (std.string.split "-" key)) ["esc", "tab", "up", "down", "left", "right"])
    ) (std.record.fields keys)
    then 'Ok
    else 'Error { message = "Escape, Tab and arrow keys (including modifier variants) are reserved for Lens navigation" }),
] in
let MiniatureFields = {
  fit | Choice [| 'page, 'shrink |] | optional,
  current-workspace | Choice [| 'plain, 'highlight, 'enlarge, 'hide |] | optional,
  arrow-keys | Choice [| 'nearest, 'by-workspace |] | optional,
  backdrop | {
    darkness | std.contract.Sequence [Number, std.contract.from_predicate (fun n => n >= 0 && n <= 0.95)] | optional,
    blur | Bool | optional,
  } | optional,
} in
let Miniatures = MiniatureFields & {
  fit | default = 'page,
  current-workspace | default = 'highlight,
  arrow-keys | default = 'nearest,
  backdrop = { darkness | default = 0.6, blur | default = true },
} in
let MiniatureRules = std.contract.from_validator (fun lens =>
  let presentation = std.record.get_or "presentation" 'list lens in
  if presentation == 'miniatures || presentation == "miniatures" then
    if std.array.any (fun field => std.record.has_field field lens) ["sections", "entries", "sort"] then
      'Error { message = "miniatures rejects sections, entries and sort" }
    else if (std.record.get_or "current-workspace" 'highlight (std.record.get_or "miniatures" {} lens)) == 'hide || (std.record.get_or "current-workspace" "highlight" (std.record.get_or "miniatures" {} lens)) == "hide" then
      if std.array.any (fun hint => hint == 'landing-spot || hint == "landing-spot") (std.record.get_or "summon-hints" ['label, 'landing-spot] lens) then
        'Error { message = "current-workspace hide cannot show landing-spot" }
      else 'Ok
    else 'Ok
  else 'Ok
) in
let LensFields = {
  filter | Dyn -> Dyn -> Bool | optional,
  presentation | std.contract.Sequence [Choice [| 'list, 'strip, 'miniatures, 'grid |], std.contract.from_predicate (fun p => p != 'grid && p != "grid")] | optional,
  entries | Choice [| 'window, 'app |] | optional,
  sections | Choice [| 'none, 'workspace, 'project, 'monitor, 'app |] | optional,
  sort | Array (Choice [| 'mru, 'previous, 'spatial, 'workspace, 'app, 'title, 'created |]) | optional,
  keys | LensKeys | optional,
  popups | Array (Choice [| 'accessory-popup, 'app-popup |]) | optional,
  frozen-thumbnail | Choice [| 'plain, 'age-badge, 'pause-badge, 'dimmed |] | optional,
  accessory-window | Choice [| 'enlarged, 'actual-size |] | optional,
  summon-hints | Array (Choice [| 'label, 'landing-spot, 'target-workspace |]) | optional,
  enabled | Bool | optional,
  miniatures | MiniatureFields | optional,
} in
let LensDefaults = LensFields & {
  presentation | priority -2 = 'list,
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
  miniatures | Miniatures | default = {},
  when | { _ | LensFields } | optional,
} in
let Lens = std.contract.Sequence [
  std.contract.from_validator (fun lens =>
    let profiles = std.record.get_or "when" {} lens in
    if std.array.all (fun name =>
      let profile = std.record.get name profiles in
      let base = if std.record.has_field "when" lens then std.record.remove "when" lens else lens in
      let resolved = std.array.fold_left (fun acc field =>
        let value = if field == "miniatures" then
          std.array.fold_left (fun settings key => std.record.update key (std.record.get key profile.miniatures) settings)
            (std.record.get_or "miniatures" {} acc) (std.record.fields profile.miniatures)
        else std.record.get field profile in
        std.record.update field value acc
      ) base (std.record.fields profile) in
      let checked = resolved | MiniatureRules in
      std.is_record checked
    ) (std.record.fields profiles) then 'Ok else 'Error { message = "invalid profile" }
  ),
  MiniatureRules,
  LensDefaults,
] in

let PositiveFraction = std.contract.Sequence [Number, std.contract.from_predicate (fun n => n > 0)] in
let ColumnTarget = std.contract.any_of [Choice [| 'focused, 'mru, 'nearest-empty, 'last |], std.contract.Sequence [Int, std.contract.from_predicate (fun n => n > 0)]] in
let Overflow = Choice [| 'tab-group, 'split, 'float, 'squeeze |] in
let PlaceResultContract = {
  column | ColumnTarget,
  overflow | Overflow,
  run | Array String | optional,
} in
let ArriveResultContract = {
  workspace | String | optional,
  float | Bool | optional,
  column | ColumnTarget | optional,
  overflow | Overflow | optional,
  run | Array String | optional,
} in
let MoveBoundaryResultContract = {
  action | Choice [| 'join, 'swap, 'stop, 'wrap, 'next-workspace, 'next-monitor |],
  overflow | Overflow | optional,
  run | Array String | optional,
} in
let ColumnFields = {
  count | std.contract.any_of [Choice [| 'off |], std.contract.Sequence [Int, std.contract.from_predicate (fun n => n > 0)]] | optional,
  widths | Array PositiveFraction | optional,
  place | Dyn -> Dyn -> Dyn -> PlaceResultContract | optional,
  move-boundary | Dyn -> Dyn -> Dyn -> Bool -> MoveBoundaryResultContract | optional,
} in
let WorkspaceColumns = ColumnFields & { when | { _ | ColumnFields } | optional } in
let Columns = WorkspaceColumns & {
  width-presets | std.contract.Sequence [Array (std.contract.Sequence [Number, std.contract.from_predicate (fun n => n > 0 && n < 1)]), std.contract.from_predicate (fun xs => std.array.length xs > 0)] | optional,
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
  PlaceResult = PlaceResultContract,
  ArriveResult = ArriveResultContract,
  MoveBoundaryResult = MoveBoundaryResultContract,

  Config = {
    arrive | Dyn -> Dyn -> Dyn -> ArriveResultContract | optional,
    columns | Columns | optional,
    workspace | { _ | { columns | WorkspaceColumns | optional } } | optional,
    # The version of the Filter contract the config was written for. Accepted and ignored: at
    # version 1 no config can lag behind.
    contract-version | Int | optional,
    # Accepted and ignored for files written by earlier TOML conversions.
    config-version | Int | optional,

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
