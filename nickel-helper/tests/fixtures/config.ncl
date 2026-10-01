# Stand-in config: Lenses hold only a `filter`, and the records are the helper's stand-ins.
let W = import "winmux/winmux.ncl" in
({
  gaps.inner.horizontal = 4,
  filters = {
    mail = fun w ctx => w.app.bundleId == "com.apple.mail",
    popups = fun w ctx => w.class == 'accessory-popup,
    same-app = fun w ctx => ctx.app.bundleId == w.app.bundleId,
    public-mail = fun w ctx => filters.mail w ctx && !w.private,
  },
  lenses = {
    mail = { filter = filters.mail },
    popups = { filter = filters.popups },
    same-app = { filter = filters.same-app },
    everything = {},
  },
} | W.Config)
# `W.Config` does not know the Policy hooks yet, so the stand-in hook is merged in after it.
& {
  arrive = fun w ctx =>
    if w.class == 'accessory-popup then { float = true } else { workspace = w.title, column = 2 },
}
