#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
zsh ~/peek-proof/restart.zsh
zsh ~/peek-proof/take.zsh cmd-tab-hold 18 snap:hold-before down:cmd tap:tab wait:0.7 snap:hold-open tap:y wait:0.6 snap:hold-peek tap:tab wait:0.7 snap:hold-step tap:y wait:0.5 snap:hold-cmd-y-off tap:y wait:0.5 snap:hold-cmd-y-on up:cmd wait:0.8 snap:hold-release
