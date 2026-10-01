# Stand-in for the WinMux-shipped contracts file. Only what the spike exercises.
let Class_ = [| 'tiling, 'floating, 'accessory_popup, 'app_popup |] in
let App_ = { bundleId | String, name | String, pid | Number, .. } in
let Window_ = {
  id | Number,
  title | String,
  app | App_,
  class | Class_,
  workspace | String,
  project | String,
  frame | { x | Number, y | Number, w | Number, h | Number },
  ..
} in
let ColumnRef_ = [| 'focused, 'mru, 'nearest_empty |] in
let Placement_ = {
  column | std.contract.any_of [Number, ColumnRef_],
  overflow | [| 'tab_group, 'split, 'stack |] | optional,
  workspace | String | optional,
  run | Array String | optional,
} in
{
  Window = Window_,
  App = App_,
  Placement = Placement_,
  Filter = Window_ -> Dyn -> Bool,
  Place = Window_ -> Dyn -> Array Dyn -> Placement_,
  Config = {
    filters | { _ | Filter },
    lenses | { _ | Dyn },
    columns | { place | Place, .. },
    arrive | Window_ -> Dyn -> Dyn,
    ..
  },
}
