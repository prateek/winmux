# Generated from nickel-helper/src/records.rs. Do not edit: run `make contract`.
#
# The records WinMux hands to Filters and Policy hooks. `winmux config schema` describes
# every field.
let Nullable = fun Contract =>
  std.contract.custom (fun label value =>
    if value == null then 'Ok value else std.contract.check Contract label value
  )
in
{
  contract-version = 1,

  Window = {
    id | Number,
    title | String,
    class | [| 'tiled, 'floating, 'fullscreen, 'minimized, 'hidden-app, 'accessory-popup, 'app-popup |],
    subrole | String,
    level | Number,
    hasCloseButton | Bool,
    document | String,
    workspace | String,
    project | String,
    monitor | Monitor,
    lastFocusedSeq | Number,
    app | App,
  },

  Monitor = {
    name | String,
    uuid | String,
    builtin | Bool,
  },

  App = {
    bundleId | String,
    name | String,
    pid | Number,
    accessory | Bool,
    activationPolicy | [| 'regular, 'accessory, 'prohibited |],
  },

  FilterContext = {
    focused | Nullable Window,
    mouse | Nullable Window,
    previous | Nullable Window,
    workspace | Workspace,
    monitor | Monitor,
    profile | String,
  },

  Workspace = {
    name | String,
    project | String,
  },

  Column = {
    index | Number,
    width | Number,
    empty | Bool,
    windows | Array Window,
  },
}
