#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
prefix=$1
W=${WINMUX_PROOF_ROOT:?}/.build/debug/winmux
K=$HOME/peek-proof/keys-check
A=$HOME/peek-proof/assert-state.py
mkdir -p ~/captures/$prefix
key() { $K 0 ~/captures/$prefix/$1.events.json "${@:2}"; }
check() { python3 "$A" ~/captures/$prefix/$1.trace.json "${@:2}"; }
garden=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Garden plan" {print $1}')
reading=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Reading notes" {print $1}')
$W focus --window-id "$garden"
$W focus --window-id "$reading"
key strip down:cmd tap:tab wait:0.3 snap:$prefix/held-strip tap:tab wait:0.1 up:cmd wait:0.3 snap:$prefix/strip-release
check held-strip active=true hold=true 'presentation="strip"'
check strip-release active=false
selected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[-1]["session"]["selectedId"])' ~/captures/$prefix/strip-release.trace.json)
[[ $($W list-windows --focused --format '%{window-id}') == $selected ]]
key grid down:ctrl down:alt tap:g wait:0.3 up:alt up:ctrl snap:$prefix/grid-release down:ctrl down:alt tap:g up:alt up:ctrl snap:$prefix/grid-toggle
check grid-release active=true hold=false 'state="normal"' 'presentation="grid"'
check grid-toggle active=false
key slash down:cmd tap:tab wait:0.3 tap:slash up:cmd snap:$prefix/slash
check slash active=true hold=false 'presentation="list"' 'state="search"'
key close tap:escape tap:escape
key letter down:cmd tap:tab wait:0.3 tap:j up:cmd snap:$prefix/letter
check letter active=true hold=false 'presentation="strip"' 'state="normal"'
key close tap:escape
$W lens search --search read
key search wait:0.4 snap:$prefix/search-read tap:return wait:0.3 snap:$prefix/search-enter
check search-read active=true 'search="read"'
check search-enter active=false
[[ $($W list-windows --focused --format '%{window-id}') == $reading ]]
print 'PASS unchanged held strip step/release, grid release/toggle, slash, letter and Search/Enter'
