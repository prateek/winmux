#!/bin/zsh
set -eu
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
ui=$HOME/demo/settings-ui
take=$HOME/takes/settings-loaded/final
mkdir -p "$take"
cp "$HOME/settings-proof/shipped.ncl" "$XDG_CONFIG_HOME/winmux/winmux.ncl"
sleep 6
p=$(pgrep -x WinMuxApp)
"$ui" "$p" press WinMux
sleep 1
"$ui" "$p" press 'Settings…'
sleep 1
snapshot() {
    shasum "$XDG_CONFIG_HOME/winmux/winmux.ncl"
    stat -f %m "$XDG_CONFIG_HOME/winmux/winmux.ncl"
    defaults read com.zimengxiong.winmux.debug 2>/dev/null || print '(no persisted defaults)'
}
snapshot > "$take/before.txt"
for entry in 'overview:Overview' 'lenses:Lenses' 'shortcuts:Shortcuts' 'columns:Columns' 'hooks:Hooks and Filters' 'behavior:Behavior' 'appearance:Appearance' 'config-file:Config File' 'reference:Configuration Reference'; do
    name=${entry%%:*}
    pane=${entry#*:}
    "$ui" "$p" pane "$pane"
    sleep 1
    screencapture -x "$take/$name.png"
    "$ui" "$p" dump > "$take/$name.ax"
    if [[ "$pane" == 'Config File' ]]; then "$ui" "$p" press 'Reload From Disk'; fi
    "$ui" "$p" scroll -30
    sleep 1
    screencapture -x "$take/$name-bottom.png"
done
"$ui" "$p" pane Shortcuts
for entry in 'lens:lens' 'glyph:⌥⇧' 'window:window' 'empty:no-such-binding'; do
    name=${entry%%:*}
    query=${entry#*:}
    "$ui" "$p" search "$query"
    sleep 1
    screencapture -x "$take/search-$name.png"
    "$ui" "$p" dump > "$take/search-$name.ax"
done
"$ui" "$p" search ''
"$ui" "$p" press 'Hide Sidebar'
sleep 1
screencapture -x "$take/sidebar-hidden.png"
"$ui" "$p" press 'Show Sidebar'
sleep 1
snapshot > "$take/after.txt"
diff -u "$take/before.txt" "$take/after.txt"
"$ui" "$p" pane 'Config File'
"$ui" "$p" press 'Open Config'
sleep 2
screencapture -x "$take/open-config.png"
for agent in $(pgrep -x CoreServicesUIAgent); do "$ui" "$agent" press Cancel || true; done
"$HOME/winmux/.build/debug/winmux" config status > "$take/status.json"
"$HOME/winmux/.build/debug/winmux" list-lenses --json > "$take/lenses.json"
print 'PASS: every pane, search and Reload From Disk preserve config hash, mtime and defaults'
