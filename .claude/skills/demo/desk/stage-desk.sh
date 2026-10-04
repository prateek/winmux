#!/bin/zsh
# Dress the desk: four real apps on two workspaces, most recently focused first: Zed, Ghostty, Safari, Notes.
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
for app in Zed zed Ghostty ghostty Safari TextEdit Notes Calendar Updater osascript WinMuxApp; do pkill -x $app; done
sleep 1
mkdir -p ~/.config/zed ~/.config/winmux ~/demo/state ~/takes
cp ~/desk/zed/settings.json ~/.config/zed/settings.json
cp ~/desk/winmux.ncl ~/.config/winmux/winmux.ncl
rm -f ~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db*
rm -rf ~/Library/Saved\ Application\ State/com.apple.Safari.savedState ~/Library/Saved\ Application\ State/com.apple.TextEdit.savedState
[ -x ~/desk/wallpaper ] || (cd ~/desk && swiftc -O wallpaper.swift -o wallpaper && swiftc -O dialog.swift -o Updater)
~/desk/wallpaper ~/desk/wallpaper.jpg
killall NotificationCenter 2>/dev/null

(open -a Zed ~/.config/winmux/winmux.ncl &); sleep 6
(open -a Ghostty &); sleep 4
(open -a Safari ~/desk/docs/lenses.html &); sleep 5
osascript ~/desk/props.applescript >/dev/null
osascript -e 'tell application "Notes" to show note "Grievances" of folder "Notes" of account "On My Mac"' >/dev/null; sleep 3

cd ~/winmux
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
(nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &); sleep 10
id() { $W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' -v a="$1" '$2==a {print $1; exit}'; }
$W move-node-to-workspace --window-id $(id Safari) 2
$W move-node-to-workspace --window-id $(id Notes) 2
$W workspace 2; $W layout tiles horizontal
$W workspace 1; $W layout tiles horizontal
for app in Notes Safari Ghostty Zed; do $W focus --window-id $(id $app); sleep 0.6; done
killall NotificationCenter 2>/dev/null
$W list-windows --all --format '%{app-name} | %{window-title} | ws %{workspace}'
