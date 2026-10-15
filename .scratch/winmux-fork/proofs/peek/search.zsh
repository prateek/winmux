#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
zsh ~/peek-proof/restart.zsh
zsh ~/peek-proof/take.zsh list-search 23 down:alt tap:slash up:alt wait:0.6 snap:list-before tap:space wait:0.6 snap:list-empty-peek tap:space tap:s tap:a tap:f tap:space wait:0.8 snap:list-saf-space down:cmd tap:y up:cmd wait:0.7 snap:list-text-peek tap:escape wait:0.4 snap:list-peek-escape tap:escape wait:0.4 snap:list-search-escape tap:escape wait:0.4 snap:list-closed
