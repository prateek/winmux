# Lenses hold only a `filter` until "Lens core" gives them the rest of their fields.
let W = import "winmux/winmux.ncl" in
({
  gaps.inner.horizontal = 4,
  filters = {
    mail = fun w ctx => w.app.bundleId == "com.apple.mail",
    popups = fun w ctx => w.class == 'accessory-popup,
    accessory-apps = fun w ctx => w.app.activationPolicy == 'accessory,
    same-app = fun w ctx => ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId,
    closable-mail = fun w ctx => filters.mail w ctx && w.hasCloseButton,
  },
  lenses = {
    mail = { filter = filters.mail },
    popups = { filter = filters.popups },
    accessory-apps = { filter = filters.accessory-apps },
    same-app = { filter = filters.same-app },
    inline = { filter = fun w ctx => w.workspace == ctx.workspace.name },
    everything = {},
  },
} | W.Config)
# `W.Config` does not know the Policy hooks yet, so the stand-in hook is merged in after it.
& {
  arrive = fun w ctx =>
    if w.class == 'accessory-popup then { float = true } else { workspace = w.title, column = 2 },
}
