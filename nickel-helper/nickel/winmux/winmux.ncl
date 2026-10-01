{
  Config = {
    filters | { _ | Dyn } | optional,
    lenses | { _ | { filter | Dyn | optional, .. } } | optional,
    arrive | Dyn | optional,
    ..
  },
}
