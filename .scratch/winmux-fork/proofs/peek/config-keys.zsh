#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
W=$HOME/winmux/.build/debug/winmux
zsh ~/peek-proof/profile.zsh freed-space
zsh ~/peek-proof/restart.zsh
$W lens search
zsh ~/peek-proof/take.zsh freed-space 12 wait:0.5 snap:freed-before tap:space wait:0.4 snap:freed-typed down:cmd tap:y up:cmd wait:0.6 snap:freed-y tap:escape tap:escape tap:escape
zsh ~/peek-proof/profile.zsh custom-peek
zsh ~/peek-proof/restart.zsh
$W config check ~/peek-proof/custom-peek.ncl > ~/captures/custom-check.txt 2>&1
$W config check ~/peek-proof/mixed-peek.ncl > ~/captures/mixed-check.txt 2>&1 && { echo 'Mixed peek unexpectedly accepted'; exit 1; }
$W lens search
zsh ~/peek-proof/take.zsh custom-peek 13 wait:0.5 snap:custom-before down:cmd tap:y up:cmd wait:0.5 snap:custom-y down:cmd tap:p up:cmd wait:0.6 snap:custom-p down:cmd tap:p up:cmd wait:0.6 snap:custom-off tap:escape tap:escape
zsh ~/peek-proof/profile.zsh live
