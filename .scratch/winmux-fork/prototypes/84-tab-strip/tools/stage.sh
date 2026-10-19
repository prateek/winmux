#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
mkdir -p "$HOME/demo/config/winmux" "$HOME/demo/state" "$HOME/takes/tab-strip" "$HOME/Library/Application Support/Code/User"
cat > "$HOME/demo/config/winmux/winmux.ncl" <<'EOF'
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & { columns.count = 'off, gaps.inner.horizontal = 8, gaps.inner.vertical = 8 }) | W.Config
EOF
cat > "$HOME/Library/Application Support/Code/User/settings.json" <<'EOF'
{"telemetry.telemetryLevel":"off","workbench.startupEditor":"none","security.workspace.trust.enabled":false,"workbench.editor.enablePreview":false,"update.mode":"none","window.title":"${activeEditorShort}${separator}WinMux"}
EOF
defaults write com.google.Chrome MetricsReportingEnabled -bool false
defaults write com.google.Chrome DefaultBrowserSettingEnabled -bool false
defaults write com.google.Chrome BrowserSignin -int 0
XDG_CONFIG_HOME="$HOME/demo/config" XDG_STATE_HOME="$HOME/demo/state" WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel" nohup "$HOME/winmux/.build/debug/WinMuxApp" > "$HOME/takes/tab-strip/winmux.log" 2>&1 &
open -a 'Google Chrome' --args --no-first-run --no-default-browser-check --disable-metrics --disable-breakpad "file://$HOME/tab-strip-tools/desk.html" "file://$HOME/tab-strip-tools/desk.html#layout" "file://$HOME/tab-strip-tools/desk.html#shortcuts"
code --new-window "$HOME/winmux/Sources/AppBundle/ui/tabs/WindowTabStripView.swift" "$HOME/winmux/Sources/AppBundle/ui/tabs/WindowTabMetrics.swift" "$HOME/winmux/Sources/AppBundle/ui/tabs/WindowTabHintState.swift"
open -a Ghostty
sleep 20
"$HOME/winmux/.build/debug/winmux" list-windows --all --json > "$HOME/takes/tab-strip/staged-windows.json"
"$HOME/tab-strip-tools/ui" > "$HOME/takes/tab-strip/staged-ui.txt"
screencapture -x "$HOME/takes/tab-strip/staged.png"
