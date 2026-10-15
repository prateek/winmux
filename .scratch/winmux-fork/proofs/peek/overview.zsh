#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
zsh ~/peek-proof/restart.zsh
zsh ~/peek-proof/take.zsh overview 14 down:alt down:shift tap:o up:shift up:alt wait:0.7 snap:overview-before tap:space wait:0.8 snap:overview-peek tap:space wait:0.8 snap:overview-back tap:escape
