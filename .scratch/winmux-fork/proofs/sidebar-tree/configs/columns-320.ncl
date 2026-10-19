let desk = import "../../desk/rich/winmux.ncl" in
desk & { reload-on-save | force = false, workspace-sidebar = {
  width | force = 320, tree = { splits | force = false, columns | force = true },
} }
