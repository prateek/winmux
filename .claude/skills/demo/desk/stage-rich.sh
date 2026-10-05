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
python3 - <<'BOOT'
from pathlib import Path
import re
p = Path.home() / '.config/winmux/winmux.ncl'
p.write_text(re.sub(r'  workspace\."[23]"\.columns = \{.*?\n  \},\n', '', p.read_text(), flags=re.S))
BOOT
rm -f ~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db*(N)
rm -rf ~/Library/Saved\ Application\ State/com.apple.Safari.savedState ~/Library/Saved\ Application\ State/com.apple.TextEdit.savedState ~/Library/Saved\ Application\ State/com.apple.Preview.savedState
~/desk/wallpaper ~/desk/wallpaper.jpg
style='<style>body{font:17px/1.6 -apple-system,sans-serif;max-width:46em;margin:40px auto;padding:0 28px;color:#1d1d1f}code{background:#f0f0f3;border-radius:4px;padding:1px 5px;font-size:.9em}pre{background:#f0f0f3;padding:14px;border-radius:8px;overflow:auto}pre code{padding:0}h1{font-size:34px}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:5px 10px}</style>'
for page in lenses columns events; do
  title=$(head -1 ~/winmux/docs/$page.md | sed 's/^# //')
  { echo "<!doctype html><meta charset=utf-8><title>$title</title>$style"; uv run --quiet --with markdown python -m markdown -x tables -x fenced_code ~/winmux/docs/$page.md; } > ~/desk/docs/$page.html
done
# The pages are served so Safari shows localhost, not a home path. One server at a time:
# stop the last run's by what it is, and keep its log out of the folder Finder shows.
pkill -f 'http.server 8765' 2>/dev/null; sleep 0.5
nohup python3 -m http.server 8765 --bind 127.0.0.1 --directory ~/desk/docs >~/demo/docs-server.log 2>&1 &
for doc in "Soft language" "Things I will get to"; do textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/rich/"$doc".txt -output ~/desk/"$doc".rtf; done
[ -f ~/desk/Grievances.rtf ] || textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/Grievances.txt -output ~/desk/Grievances.rtf

rm -rf ~/demo/state; mkdir -p ~/demo/state
cd ~/winmux
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
(nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &); sleep 8
id() { $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' | awk -F'|' -v a="$1" -v t="$2" '$2==a && index($3,t) {print $1; exit}'; }
# A window that did not open leaves the desk wrong in ways that are easy to miss on film: stop.
need() { local found; found=$(id "$1" "$2"); [[ -n "$found" ]] || echo "stage-rich: no $1 window${2:+ titled \"$2\"}" >&2; echo "$found"; }
# need runs in a subshell, so the caller is what stops: an empty id ends the script here.
put() { [[ -n "$1" ]] || exit 1; $W move-node-to-workspace --window-id "$1" "$2" >/dev/null 2>&1; }

# Open everything, then put each window where it belongs.
(open -a Zed ~/.config/winmux/winmux.ncl &); sleep 6
(open -a Ghostty --args -e ~/desk/term.sh &); sleep 3
(open -na Ghostty --args -e ~/desk/term.sh &); sleep 3
(open -a Safari http://localhost:8765/lenses.html &); sleep 5
~/desk/keys 0 /tmp/new-window.json down:cmd tap:n up:cmd wait:0.5
open -a Safari http://localhost:8765/columns.html; sleep 2
~/desk/keys 0 /tmp/new-window.json down:cmd tap:n up:cmd wait:0.5
open -a Safari http://localhost:8765/events.html; sleep 2
open -a Notes; sleep 3
(open -a TextEdit ~/desk/Grievances.rtf ~/desk/"Soft language".rtf ~/desk/"Things I will get to".rtf &); sleep 4
open ~/desk; sleep 2
(open -a Preview ~/desk/wallpaper.jpg &); sleep 3
(open -a Calculator &); sleep 2
killall NotificationCenter 2>/dev/null

# Seed the numeric workspace order before loading the per-workspace Column rules.
# Configured workspace records otherwise create 2 and 3 in dictionary iteration order.
put "$(need Notes "")" "2"
put "$(need Finder "desk")" "3"
put "$(need Preview "")" "4"
cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
$W reload-config >/dev/null
sleep 1
for stray in $($W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' | awk -F'|' '$2=="Safari" && ($3=="Untitled" || $3=="Start Page") {print $1}'); do $W close --window-id $stray; done
ghostty=($($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1}'))
col() { [[ -n "$1" ]] || exit 1; $W move-node-to-workspace --window-id "$1" "$2" >/dev/null 2>&1; $W workspace "$2" >/dev/null 2>&1; $W layout tiling --window-id "$1" >/dev/null 2>&1; $W move-node-to-column "$3" --window-id "$1"; }

# Workspace 2, three Columns: the notes, three pages in a tab group, and a list.
col "$(need Notes "")" "2" 1
col "$(need Safari "Lenses")" "2" 2; col "$(need Safari "Fixed Columns")" "2" 2; col "$(need Safari "Subscription")" "2" 2
col "$(need TextEdit "Things")" "2" 3
# Workspace 3, two Columns: two drafts in a tab group, and the folder of stuff.
col "$(need TextEdit "Grievances")" "3" 1; col "$(need TextEdit "Soft language")" "3" 1
col "$(need Finder "desk")" "3" 2
# Workspace 4, no Columns: a picture, and a calculator floating over it.
put "$(need Preview "")" "4"; put "$(need Calculator "")" "4"
$W workspace "4" >/dev/null; $W layout tiles horizontal >/dev/null 2>&1
# Workspace 1, no Columns: the editor beside two terminals stacked, and a dialog that is not yours.
put "$(need Zed "")" "1"; put "${ghostty[1]}" "1"; put "${ghostty[2]}" "1"
$W workspace "1" >/dev/null; $W layout tiles horizontal >/dev/null 2>&1
$W focus --window-id ${ghostty[2]} >/dev/null; $W join-with left >/dev/null 2>&1
(nohup ~/desk/Updater >/dev/null 2>&1 &); sleep 2
put "$(need Updater "")" "1"; $W workspace "1" >/dev/null
$W focus --window-id "$(need Zed "")" >/dev/null
$W list-windows --all --format '%{window-id} | %{app-name} | %{window-title} | %{window-layout} | ws %{workspace}'
for n in 2 3; do echo "columns on $n:"; $W workspace "$n" >/dev/null; sleep 0.5; $W list-columns; done; $W workspace "1" >/dev/null
