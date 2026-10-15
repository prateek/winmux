#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
zsh ~/peek-proof/profile.zsh live
zsh ~/peek-proof/restart.zsh
$W lens recent --presentation grid
zsh ~/peek-proof/take.zsh pointer-zoom 15 wait:0.6 snap:pointer-before tap:space wait:0.6 snap:pointer-zoom move:295,385 wait:0.6 snap:pointer-frozen tap:space wait:0.4 move:298,385 wait:0.6 snap:pointer-after tap:escape
zsh ~/peek-proof/profile.zsh follow
zsh ~/peek-proof/restart.zsh
zsh ~/peek-proof/take.zsh pointer-follow 13 down:alt tap:tab wait:0.6 snap:pointer-follow-before move:430,360 wait:0.6 snap:pointer-follow-moved up:alt wait:0.6 snap:pointer-follow-release
zsh ~/peek-proof/profile.zsh live
