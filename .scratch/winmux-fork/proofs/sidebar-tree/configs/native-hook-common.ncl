let desk = import "../../desk/rich/winmux.ncl" in
desk & {
  reload-on-save | force = false,
  workspace."2".columns.place | force = fun window ctx columns => { column = 3, overflow = 'split },
}
