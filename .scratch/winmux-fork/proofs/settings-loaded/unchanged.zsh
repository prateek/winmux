#!/bin/zsh
set -eu
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
tree=${1:?source tree}
binary=${2:?app executable}
domain=${3:?defaults domain}
take=${4:?capture directory}
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel
ui=$HOME/demo/settings-ui
mkdir -p "$take"
pkill -x WinMuxApp || true
sleep 3
nohup "$binary" > "$take/app.log" 2>&1 &
sleep 20
p=$(pgrep -x WinMuxApp)
"$ui" "$p" press WinMux
sleep 1
"$ui" "$p" press 'Settings…'
sleep 2
if ! "$ui" "$p" pane 'Config File'; then "$ui" "$p" pane Configuration; fi
sleep 1
snapshot() {
    shasum "$XDG_CONFIG_HOME/winmux/winmux.ncl"
    stat -f %m "$XDG_CONFIG_HOME/winmux/winmux.ncl"
    defaults read "$domain" 2>/dev/null || print '(no persisted defaults)'
}
snapshot > "$take/before.txt"
"$ui" "$p" press 'Reload From Disk'
sleep 1
snapshot > "$take/after-disk.txt"
diff -u "$take/before.txt" "$take/after-disk.txt"
"$ui" "$p" dump > "$take/config-file.ax"
screencapture -x "$take/config-file.png"
if ! "$ui" "$p" press 'Open Config'; then "$ui" "$p" press 'Open config'; fi
sleep 3
snapshot > "$take/after-open.txt"
diff -u "$take/before.txt" "$take/after-open.txt"
screencapture -x "$take/open-config.png"
for agent in $(pgrep -x CoreServicesUIAgent); do
    "$ui" "$agent" press Cancel || true
done
"$tree/.build/debug/winmux" config status > "$take/status.json"
"$tree/.build/debug/winmux" list-lenses --json > "$take/lenses.json"
"$tree/.build/debug/winmux" config --get mode.main.binding --json > "$take/main-bindings.json"
"$tree/.build/debug/winmux" config --get mode.window.binding --json > "$take/window-bindings.json"
print 'PASS: Reload From Disk and Open Config preserve an existing file and preferences'
