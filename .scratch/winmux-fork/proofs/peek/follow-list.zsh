#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
zsh ~/peek-proof/profile.zsh follow-list
zsh ~/peek-proof/restart.zsh
$W lens search
zsh ~/peek-proof/take.zsh follow-list 14 wait:0.7 snap:follow-list-first tap:down wait:0.7 snap:follow-list-next tap:space wait:0.5 snap:follow-list-space tap:escape tap:escape wait:0.5 snap:follow-list-closed
zsh ~/peek-proof/profile.zsh live
