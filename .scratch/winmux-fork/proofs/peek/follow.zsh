#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
zsh ~/peek-proof/profile.zsh follow
zsh ~/peek-proof/restart.zsh
zsh ~/peek-proof/take.zsh follow 15 snap:follow-before down:alt tap:tab wait:0.6 snap:follow-first tap:tab wait:0.6 snap:follow-step tap:space wait:0.6 snap:follow-space up:alt wait:0.8 snap:follow-release
zsh ~/peek-proof/profile.zsh live
