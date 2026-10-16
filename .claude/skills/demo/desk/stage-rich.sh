#!/bin/zsh
# A fuller desk: four workspaces, with and without Columns, tab groups, splits and floaters.
set -e
export PATH=/opt/homebrew/bin:$PATH
W=${WINMUX_CLI:-$HOME/winmux/.build/debug/winmux}
ready() { python3 ~/desk/rich-ready.py "$@"; }
[[ ~/desk/rich-app -nt ~/desk/rich-app.swift ]] || swiftc -O ~/desk/rich-app.swift -o ~/desk/rich-app
ready display "$(~/desk/rich-app display)"
# Stop the observer before its apps, then wait until open --args can start new instances.
ready stop WinMuxApp
ready stop Zed zed Ghostty ghostty Safari TextEdit Notes Calendar Music Preview Calculator Updater osascript
mkdir -p ~/.config/zed ~/.config/winmux ~/demo/state ~/takes ~/desk/docs ~/desk/repo
(cd ~/desk && swiftc -O wallpaper.swift -o wallpaper && swiftc -O dialog.swift -o Updater)
# film and the probes run ~/desk/keys without building it.
swiftc -O ~/winmux/.claude/skills/demo/keys.swift -o ~/desk/keys
zsh ~/desk/make-repo.sh
cp ~/desk/zed/settings.json ~/.config/zed/settings.json
cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
~/winmux/nickel-helper/target/release/winmux-nickel check ~/.config/winmux/winmux.ncl || exit 1
python3 - <<'BOOT'
from pathlib import Path
import re
p = Path.home() / '.config/winmux/winmux.ncl'
p.write_text(re.sub(r'  workspace\."[23]"\.columns = \{.*?\n  \},\n', '', p.read_text(), flags=re.S).replace('(defaults & {', '(defaults & {\n  reload-on-save = false,'))
BOOT
rm -f ~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db*(N)
rm -rf ~/Library/Saved\ Application\ State/com.apple.Safari.savedState ~/Library/Saved\ Application\ State/com.apple.TextEdit.savedState ~/Library/Saved\ Application\ State/com.apple.Preview.savedState
# External URL requests must create windows, even when Safari is already running.
defaults write ~/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari TabCreationPolicy -int 0
~/desk/wallpaper ~/desk/wallpaper.jpg
style='<style>body{font:17px/1.6 -apple-system,sans-serif;max-width:46em;margin:40px auto;padding:0 28px;color:#1d1d1f}code{background:#f0f0f3;border-radius:4px;padding:1px 5px;font-size:.9em}pre{background:#f0f0f3;padding:14px;border-radius:8px;overflow:auto}pre code{padding:0}h1{font-size:34px}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:5px 10px}</style>'
for page in lenses columns events; do
  title=$(head -1 ~/winmux/docs/$page.md | sed 's/^# //')
  { echo "<!doctype html><meta charset=utf-8><title>$title</title>$style"; uv run --quiet --with markdown python -m markdown -x tables -x fenced_code ~/winmux/docs/$page.md; } > ~/desk/docs/$page.html
done
# The pages are served so Safari shows localhost, not a home path. One server at a time:
# stop the last run's by what it is, and keep its log out of the folder Finder shows.
ready stop-server
nohup python3 -m http.server 8765 --bind 127.0.0.1 --directory ~/desk/docs >~/demo/docs-server.log 2>&1 &
ready http
for doc in "Soft language" "Things I will get to"; do textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/rich/"$doc".txt -output ~/desk/"$doc".rtf; done
[ -f ~/desk/Grievances.rtf ] || textutil -convert rtf -font Helvetica -fontsize 17 ~/desk/Grievances.txt -output ~/desk/Grievances.rtf

rm -rf ~/demo/state; mkdir -p ~/demo/state
cd ~/winmux
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
(nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &)
ready ready
need() { ready window "$@"; }
put() { ready put "$@"; }

open -a Zed ~/.config/winmux/winmux.ncl
ready front Zed "winmux.ncl"
open -a Ghostty --args -e ~/desk/term.sh
ready front Ghostty desk
open -na Ghostty --args -e ~/desk/term.sh
ready front Ghostty desk 2
open -a Safari http://localhost:8765/lenses.html
ready front Safari "Lenses and Search"
open -a Safari http://localhost:8765/columns.html
ready front Safari "Fixed Columns"
open -a Safari http://localhost:8765/events.html
ready front Safari "Subscription events"
open -a Notes
notes_title=$(ready notes)
open -a TextEdit ~/desk/Grievances.rtf ~/desk/"Soft language".rtf ~/desk/"Things I will get to".rtf
for title in Grievances "Soft language" "Things I will get to"; do ready front TextEdit "$title"; done
open ~/desk
ready front Finder desk
open -a Preview ~/desk/wallpaper.jpg
ready front Preview wallpaper.jpg
open -a Calculator
ready front Calculator Calculator
killall NotificationCenter 2>/dev/null || true

# Seed the numeric workspace order before loading the per-workspace Column rules.
# Configured workspace records otherwise create 2 and 3 in dictionary iteration order.
put "$(need Notes "")" "2"
put "$(need Finder "desk")" "3"
put "$(need Preview "")" "4"
cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
$W reload-config >/dev/null
ready columns 2 3
ready columns 3 2
ghostty=("$(need Ghostty desk)" "$(need Ghostty desk 2)")
col() { ready column "$@"; }

# Workspace 2, three Columns: the notes, three pages in a tab group, and a list.
col "$(need Notes "")" "2" 1
col "$(need Safari "Lenses")" "2" 2; col "$(need Safari "Fixed Columns")" "2" 2; col "$(need Safari "Subscription")" "2" 2
col "$(need TextEdit "Things")" "2" 3
# Workspace 3, two Columns: two drafts in a tab group, and the folder of stuff.
col "$(need TextEdit "Grievances")" "3" 1; col "$(need TextEdit "Soft language")" "3" 1
col "$(need Finder "desk")" "3" 2
# Workspace 4, no Columns: a picture, and a calculator floating over it.
put "$(need Preview "")" "4"; put "$(need Calculator "")" "4"
ready workspace "4"; ready horizontal "$(need Preview "")"
# Workspace 1, no Columns: the editor beside two terminals stacked, and a dialog that is not yours.
put "$(need Zed "")" "1"; put "${ghostty[1]}" "1"; put "${ghostty[2]}" "1"
ready workspace "1"; ready horizontal "$(need Zed "")"
# A join that fails or pairs the wrong windows is caught by the inventory's layout check.
$W focus --window-id ${ghostty[2]} >/dev/null; $W join-with left >/dev/null 2>&1 || true
(nohup ~/desk/Updater >/dev/null 2>&1 &)
ready front Updater "A dialog that is not yours"
put "$(need Updater "")" "1"; $W workspace "1" >/dev/null
$W focus --window-id "$(need Zed "")" >/dev/null
ready inventory "$notes_title"
$W list-windows --all --format '%{window-id} | %{app-name} | %{window-title} | %{window-layout} | ws %{workspace}'
for n in 2 3; do echo "columns on $n:"; ready workspace "$n"; $W list-columns; done; $W workspace "1" >/dev/null
