let openFn = fun lens mode => ["lens %{lens}", "mode %{std.string.from mode}"] in
let replace = fun register text => std.string.replace "<r>" register text in
let expand = fun bindings => std.array.fold_left (fun result key =>
  let value = std.record.get key bindings in
  if std.string.contains "<r>" key then
    std.array.fold_left (fun result register =>
      let commands = if std.typeof value == 'Array then std.array.map (replace register) value else replace register value in
      result & { "%{replace register key}" | default = commands }
    ) result (std.string.characters "abcdefghijklmnopqrstuvwxyz")
  else result & { "%{key}" | default = value }
) {} (std.record.fields bindings) in
let whenFn = fun condition keys => { context | default = condition, bindings | default = expand keys, priority | default = 1 } in
let finish = ["lens focus", "mode main"] in
let summon = ["lens summon", "mode main"] in
let close = ["lens close", "mode main"] in
let workspaceKeys = std.array.fold_left (fun result n =>
  result & { "cmd-%{std.string.from n}" | default = "lens run move-node-to-workspace %{std.string.from n}" }
) {} [1,2,3,4,5,6,7,8,9] in
let actions = workspaceKeys & {
  enter | default = finish, shift-enter | default = summon, alt-enter | default = summon,
  cmd-w | default = "lens close-window", cmd-y | default = "lens peek", cmd-g | default = "lens sections next",
} in
let arrows = { left | default = "lens step left", right | default = "lens step right", up | default = "lens step up", down | default = "lens step down" } in
let switcherFn = fun options =>
  let options = { start | default = 'next } & options in
  let other = if options.key == "tab" then "backtick" else "tab" in
  {
    lifetime | default = 'held, unbound | default = 'latch, latch-to | default = "browse", draw-delay | default = 100,
    on-enter | default = ["lens %{options.lens}"] @ (if options.start == 'prev then ["lens step prev"] else []),
    on-release | default = finish,
    binding | default = actions & arrows & {
      "%{options.key}" | default = "lens step next", "shift-%{options.key}" | default = "lens step prev",
      "%{other}" | default = [], "shift-%{other}" | default = [],
      w | default = "lens close-window", y | default = "lens peek", space | default = "lens peek", g | default = "lens sections next",
      slash | default = ["lens presentation list", "mode search"], esc | default = close,
    },
  } in
let holdFn = fun options => {
  lifetime | default = 'held, unbound | default = 'latch, latch-to | default = options.latch,
  on-enter | default = ["lens %{options.lens}"], on-release | default = ["mode %{options.latch}"],
  binding | default = actions & arrows & {
    tab | default = "lens step next", shift-tab | default = "lens step prev", space | default = "lens peek",
    slash | default = ["lens presentation list", "mode search"], esc | default = close,
  },
} in
let mainToday = {
  alt-1 | default = "focus --tab-index 1", alt-2 | default = "focus --tab-index 2", alt-3 | default = "focus --tab-index 3",
  alt-4 | default = "focus --tab-index 4", alt-5 | default = "focus --tab-index 5", alt-6 | default = "focus --tab-index 6",
  alt-7 | default = "focus --tab-index 7", alt-8 | default = "focus --tab-index 8", alt-9 | default = "focus --tab-index last",
  alt-h | default = "focus left", alt-j | default = "focus down", alt-k | default = "focus up", alt-l | default = "focus right",
  alt-shift-h | default = "move left", alt-shift-j | default = "move down", alt-shift-k | default = "move up", alt-shift-l | default = "move right",
  alt-shift-m | default = "fullscreen", alt-shift-t | default = "layout floating tiling",
} & std.array.fold_left (fun result n => result & {
  "alt-shift-%{std.string.from n}" | default = "move-node-to-workspace %{std.string.from n}",
  "ctrl-%{std.string.from n}" | default = "workspace %{std.string.from n}",
}) {} [1,2,3,4,5,6,7,8,9] in
let navigateKeys = {
  c | default = "find-focus", h | default = "focus left", j | default = "focus down", k | default = "focus up", l | default = "focus right",
  shift-h | default = "move left", shift-j | default = "move down", shift-k | default = "move up", shift-l | default = "move right",
  ctrl-h | default = "join-with left", ctrl-j | default = "join-with down", ctrl-k | default = "join-with up", ctrl-l | default = "join-with right",
  n | default = "focus tab-next", p | default = "focus tab-prev", t | default = "layout floating tiling", m | default = "fullscreen",
  rightSquareBracket | default = "project next", leftSquareBracket | default = "project prev",
} in
let workspaceBindings = std.array.fold_left (fun result n => result & {
  "%{std.string.from n}" | default = "workspace %{std.string.from n}",
  "shift-%{std.string.from n}" | default = "move-node-to-workspace %{std.string.from n}",
}) {} [1,2,3,4,5,6,7,8,9] in
{
  switcher = switcherFn, hold = holdFn, open = openFn, when = whenFn,
  transient = fun options => std.record.remove "bindings" ({ on-enter | default = [] } & options & {
    lifetime | default = 'transient, unbound | default = 'consume,
    binding | default = options.bindings,
  }),
  keys = {
    main-today = mainToday, navigate = navigateKeys, workspaces = workspaceBindings, columns = {},
    lenses = { w | default = openFn "windows" 'browse, o | default = openFn "overview" 'browse,
      f | default = openFn "floating" 'browse, s | default = openFn "search" 'search,
      r | default = ["lens recent --presentation list --tile text", "mode search"],
      a | default = ["lens app-windows --presentation list --tile text", "mode search"] },
  },
  modes = { main = { lifetime | default = 'latched, unbound | default = 'pass },
    window = { lifetime | default = 'latched, unbound | default = 'pass },
    browse = { lifetime | default = 'latched, unbound | default = 'consume },
    search = { lifetime | default = 'latched, unbound | default = 'type } },
  keymap = {
    browse = whenFn "mode == browse" (actions & arrows & {
      h | default = "lens step left", j | default = "lens step down", k | default = "lens step up", l | default = "lens step right",
      tab | default = "lens mark", y | default = "lens peek", space | default = "lens peek", g | default = "lens sections next",
      slash | default = ["lens presentation list", "mode search"], esc | default = close,
      alt-slash | default = close, alt-shift-o | default = close,
    }) & { priority = 0 },
    search = whenFn "mode == search" (actions & arrows & { tab | default = "lens mark", esc | default = "mode browse", alt-slash | default = close, alt-shift-o | default = close }) & { priority = 0 },
    list-search = whenFn "presentation == list && mode == search" { left | default = "lens caret left", right | default = "lens caret right" } & { priority = 0 },
    list-browse = whenFn "presentation == list && mode == browse" { h | default = [], l | default = [] } & { priority = 0 },
    strip = whenFn "presentation == strip && (mode == browse || mode == cmd-tab || mode == cmd-backtick)" {
      up | default = "lens step prev", k | default = "lens step prev", down | default = "lens step next", j | default = "lens step next",
    } & { priority = 0 },
  },
}
