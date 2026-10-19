let desk = import "../../desk/rich/winmux.ncl" in
desk & { reload-on-save | force = false, workspace-sidebar = {
  width | force = 240, tree = { splits | force = false, columns | force = false },
} }
