let desk = import "../../desk/rich/winmux.ncl" in
desk & { reload-on-save | force = false, workspace-sidebar = {
  width | force = 320, menu-bar-reserve-height | force = 360,
  tree = { splits | force = true, columns | force = true },
} }
