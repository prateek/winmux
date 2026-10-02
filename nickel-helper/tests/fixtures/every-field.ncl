# A Filter that reads every field of the Window and the Filter context.
let W = import "winmux/winmux.ncl" in
let reads-window = fun w =>
  w.id > 0
  && w.title != ""
  && w.class == 'tiled
  && w.subrole != ""
  && w.level >= 0
  && w.hasCloseButton
  && w.document != ""
  && w.workspace != ""
  && w.project != ""
  && w.monitor.name != ""
  && w.monitor.uuid != ""
  && w.monitor.builtin
  && w.lastFocusedSeq >= 0
  && w.app.bundleId != ""
  && w.app.name != ""
  && w.app.pid > 0
  && w.app.accessory
  && w.app.activationPolicy == 'regular
in
{
  filters.everything = fun w ctx =>
    reads-window w
    && (ctx.focused == null || reads-window ctx.focused)
    && (ctx.mouse == null || reads-window ctx.mouse)
    && (ctx.previous == null || reads-window ctx.previous)
    && ctx.workspace.name != ""
    && ctx.workspace.project != ""
    && ctx.monitor.name != ""
    && ctx.monitor.uuid != ""
    && ctx.monitor.builtin
    && ctx.profile != "",
  contract-version = 1,
} | W.Config
