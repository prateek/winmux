# Reference config: the Nickel tab of prototypes/27-config-language.html, plus arrive.
let W = import "winmux.ncl" in
let comms_apps = ["com.tinyspeck.slackmacgap", "com.apple.mail", "com.apple.MobileSMS"] in
{
  filters = {
    comms    = fun w ctx => std.array.elem w.app.bundleId comms_apps,
    same_app = fun w ctx => ctx.focused != null
                            && ctx.focused.app.bundleId == w.app.bundleId,
    floaters = fun w ctx => std.array.elem w.class ['floating, 'accessory_popup],
    here     = fun w ctx => w.project == ctx.workspace.project
                            && !(filters.floaters w ctx),
  },

  lenses = {
    recent      = { presentation = 'strip, sort = ['mru] },
    app_windows = { presentation = 'strip, filter = filters.same_app, sort = ['mru] },
    overview    = { presentation = 'miniatures, sort = ['spatial] },
  },

  # One call over the whole candidate array, for comparison with per-window calls.
  filter_all = fun name ws ctx => std.array.filter (fun w => filters."%{name}" w ctx) ws,

  columns.place = fun w ctx cols =>
    let focus_here = ctx.focused != null
                     && ctx.focused.workspace == ctx.workspace.name in
    if filters.comms w ctx then
      { column = 3, overflow = 'tab_group }
    else if w.app.bundleId == "com.mitchellh.ghostty" then
      { column = 'focused, overflow = 'split }
    else if std.array.any (fun c => c.empty) cols then
      { column = 'nearest_empty }
    else
      { column = if focus_here then 'focused else 'mru, overflow = 'tab_group },

  arrive = fun w ctx =>
    if filters.comms w ctx then { workspace = "comms" }
    else if w.class == 'accessory_popup then { float = true }
    else {},
}
