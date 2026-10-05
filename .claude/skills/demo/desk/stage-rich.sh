#!/bin/zsh
# A fuller desk: four workspaces, with and without Columns, tab groups, splits and floaters.
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
for app in Zed zed Ghostty ghostty Safari TextEdit Notes Calendar Preview Calculator Updater osascript WinMuxApp; do pkill -x $app; done
sleep 1
mkdir -p ~/.config/zed ~/.config/winmux ~/demo/state ~/takes ~/desk/docs ~/desk/repo
(cd ~/desk && swiftc -O wallpaper.swift -o wallpaper && swiftc -O dialog.swift -o Updater)
swiftc -O ~/winmux/.claude/skills/demo/keys.swift -o ~/desk/keys
zsh ~/desk/make-repo.sh
cp ~/desk/zed/settings.json ~/.config/zed/settings.json
cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
~/winmux/nickel-helper/target/release/winmux-nickel check ~/.config/winmux/winmux.ncl || exit 1
rm -f ~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db*
rm -rf ~/Library/Saved\ Application\ State/com.apple.Safari.savedState ~/Library/Saved\ Application\ State/com.apple.TextEdit.savedState ~/Library/Saved\ Application\ State/com.apple.Preview.savedState
~/desk/wallpaper ~/desk/wallpaper.jpg
style='<style>body{font:17px/1.6 -apple-system,sans-serif;max-width:46em;margin:40px auto;padding:0 28px;color:#1d1d1f}code{background:#f0f0f3;border-radius:4px;padding:1px 5px;font-size:.9em}pre{background:#f0f0f3;padding:14px;border-radius:8px;overflow:auto}pre code{padding:0}h1{font-size:34px}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:5px 10px}</style>'
for page in lenses columns events; do
  title=$(head -1 ~/winmux/docs/$page.md | sed 's/^# //')
  { echo "<!doctype html><meta charset=utf-8><title>$title</title>$style"; uv run --quiet --with markdown python -m markdown -x tables -x fenced_code ~/winmux/docs/$page.md; } > ~/desk/docs/$page.html
done
for doc in "Soft language" "Things I will get to"; do textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/rich/"$doc".txt -output ~/desk/"$doc".rtf; done
[ -f ~/desk/Grievances.rtf ] || textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/Grievances.txt -output ~/desk/Grievances.rtf

rm -rf ~/demo/state; mkdir -p ~/demo/state
cd ~/winmux
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
(nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &); sleep 8
id() { $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' | awk -F'|' -v a="$1" -v t="$2" '$2==a && index($3,t) {print $1; exit}'; }
put() {
  [[ -n "$1" ]] || { echo "stage-rich: a required window is missing" >&2; return 1; }
  $W move-node-to-workspace --window-id "$1" "$2" >/dev/null 2>&1
}

# Open everything, then put each window where it belongs.
(open -a Zed ~/.config/winmux/winmux.ncl &); sleep 6
(open -a Ghostty --args -e ~/desk/term.sh &); sleep 3
(open -na Ghostty --args -e ~/desk/term.sh &); sleep 3
(open -a Safari ~/desk/docs/lenses.html &); sleep 5
~/desk/keys 0 /tmp/new-window.json down:cmd tap:n up:cmd wait:0.5
open -a Safari ~/desk/docs/columns.html; sleep 2
~/desk/keys 0 /tmp/new-window.json down:cmd tap:n up:cmd wait:0.5
open -a Safari ~/desk/docs/events.html; sleep 2
open -a Notes; sleep 3
(open -a TextEdit ~/desk/Grievances.rtf ~/desk/"Soft language".rtf ~/desk/"Things I will get to".rtf &); sleep 4
open ~/desk; sleep 2
(open -a Preview ~/desk/wallpaper.jpg &); sleep 3
(open -a Calculator &); sleep 2
killall NotificationCenter 2>/dev/null

for stray in $($W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' | awk -F'|' '$2=="Safari" && ($3=="Untitled" || $3=="Start Page") {print $1}'); do $W close --window-id $stray; done
ghostty=($($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1}'))
col() { $W move-node-to-workspace --window-id "$1" "$2" >/dev/null 2>&1; $W workspace "$2" >/dev/null 2>&1; $W layout tiling --window-id "$1" >/dev/null 2>&1; $W move-node-to-column "$3" --window-id "$1"; }

# Workspace 2, three Columns: the notes, three pages in a tab group, and a list.
col $(id Notes "") "2" 1
col $(id Safari "Lenses") "2" 2; col $(id Safari "Fixed Columns") "2" 2; col $(id Safari "Subscription") "2" 2
col $(id TextEdit "Things") "2" 3
# Workspace 3, two Columns: two drafts in a tab group, and the folder of stuff.
col $(id TextEdit "Grievances") "3" 1; col $(id TextEdit "Soft language") "3" 1
col $(id Finder "") "3" 2
# Workspace 4, no Columns: a picture, and a calculator floating over it.
put $(id Preview "") "4"; put $(id Calculator "") "4"
$W workspace "4" >/dev/null; $W layout tiles horizontal >/dev/null 2>&1
# Workspace 1, no Columns: the editor beside two terminals stacked, and a dialog that is not yours.
put $(id Zed "") "1"; put ${ghostty[1]} "1"; put ${ghostty[2]} "1"
$W workspace "1" >/dev/null; $W layout tiles horizontal >/dev/null 2>&1
$W focus --window-id ${ghostty[2]} >/dev/null; $W join-with left >/dev/null 2>&1
(nohup ~/desk/Updater >/dev/null 2>&1 &); sleep 2
put $(id Updater "") "1"; $W workspace "1" >/dev/null
$W focus --window-id $(id Zed "") >/dev/null
$W list-windows --all --format '%{window-id} | %{app-name} | %{window-title} | %{window-layout} | ws %{workspace}'
for n in 2 3; do echo "columns on $n:"; $W workspace "$n" >/dev/null; sleep 0.5; $W list-columns; done; $W workspace "1" >/dev/null
