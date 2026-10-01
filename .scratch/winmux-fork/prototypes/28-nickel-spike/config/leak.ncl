let comms_apps = ["com.apple.mail"] in
let comms_let = fun w => std.array.elem w.app.bundleId comms_apps in
{
  filters.comms = fun w ctx => std.array.elem w.app.bundleId comms_apps,
  # reaches a sibling field through the recursive record
  rec_ref = fun w ctx => filters.comms w ctx,
  # same logic through a let binding, no recursive record access
  let_ref = fun w ctx => comms_let w,
  # plain body, no calls
  plain = fun w ctx => w.app.bundleId == "com.apple.mail",
  # returns a record
  rec_out = fun w ctx => { column = 3, overflow = 'tab_group },
  # std.array.any with a lambda over an argument
  any_lambda = fun w ctx => std.array.any (fun c => c.empty) ctx.cols,
  loop_elem = fun n => std.array.fold_left (fun acc i => acc && !(std.array.elem "x" ["a", "b", "c"])) true (std.array.range 0 n),
  loop_plain = fun n => std.array.fold_left (fun acc i => acc && i != -1) true (std.array.range 0 n),
  elem_untyped = fun x xs => std.array.fold_left (fun acc y => acc || y == x) false xs,
  loop_untyped = fun n => std.array.fold_left (fun acc i => acc && !(elem_untyped "x" ["a", "b", "c"])) true (std.array.range 0 n),
}
