#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
bash "$HOME/winmux/.claude/skills/vm/setup-bundle.sh"
app="$HOME/demo/WinMux Setup.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
mkdir -p "$HOME/demo/url-config/winmux" "$HOME/demo/url-state" "$HOME/takes/url"
cp "$HOME/desk/winmux.ncl" "$HOME/demo/url-config/winmux/winmux.ncl"
export XDG_CONFIG_HOME="$HOME/demo/url-config" XDG_STATE_HOME="$HOME/demo/url-state"
export WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel"
nohup "$app/Contents/MacOS/WinMuxApp" > "$HOME/demo/url.log" 2>&1 < /dev/null &
sleep 20
pgrep -x WinMuxApp | tee "$HOME/takes/url/original-pid.txt"
"$HOME/winmux/.build/debug/winmux" config status
"$HOME/winmux/.build/debug/winmux" list-windows --all
screencapture -x "$HOME/takes/url/wrapper-start.png"
