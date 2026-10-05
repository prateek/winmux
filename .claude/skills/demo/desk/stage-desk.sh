#!/bin/zsh
# Dress the desk: four real apps on two workspaces, most recently focused first: Zed, Ghostty, Safari, Notes.
setopt nonomatch
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
# Safari shows the real docs page, rendered here so there is no site chrome around it.
if [ ! -f ~/desk/docs/lenses.html ]; then
  mkdir -p ~/desk/docs
  { echo '<!doctype html><meta charset=utf-8><title>Lenses and Search</title><style>body{font:17px/1.6 -apple-system,sans-serif;max-width:46em;margin:40px auto;padding:0 28px;color:#1d1d1f}code{background:#f0f0f3;border-radius:4px;padding:1px 5px;font-size:.9em}pre{background:#f0f0f3;padding:14px;border-radius:8px;overflow:auto}pre code{padding:0}h1{font-size:34px}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:5px 10px}</style>'
    uv run --quiet --with markdown python -m markdown -x tables -x fenced_code ~/winmux/docs/lenses.md; } > ~/desk/docs/lenses.html
fi
# Safari shows whatever answers, so the page has to be there before it asks.
pkill -f 'http.server 8765' 2>/dev/null; sleep 0.5
nohup python3 -m http.server 8765 --bind 127.0.0.1 --directory ~/desk/docs >~/demo/docs-server.log 2>&1 &
for _ in {1..40}; do curl -sf http://localhost:8765/lenses.html | grep -q 'Lenses and Search' && break; sleep 0.25; done
curl -sf http://localhost:8765/lenses.html | grep -q 'Lenses and Search' || { echo "stage-desk: the docs page is not being served; see ~/demo/docs-server.log" >&2; exit 1; }
(open -a Safari http://localhost:8765/lenses.html &); sleep 5
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

windows=$($W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}')
for app in Zed Ghostty Safari Notes; do
  count=$(print -r -- "$windows" | awk -F'|' -v app="$app" '$2==app {n++} END {print n+0}')
  [[ "$count" == 1 ]] || { echo "stage-desk: expected one $app window, got $count" >&2; exit 1; }
done
strangers=$(print -r -- "$windows" | awk -F'|' '$2!="Zed" && $2!="Ghostty" && $2!="Safari" && $2!="Notes"')
[[ -z "$strangers" ]] || { echo "stage-desk: stranger: $strangers" >&2; exit 1; }
print -r -- "$windows" | grep -qx '[0-9]*|Safari|Lenses and Search' || { echo "stage-desk: Safari is not showing the docs page" >&2; exit 1; }
[[ ~/desk/check-desk -nt ~/desk/check-desk.swift ]] || (cd ~/desk && swiftc -O check-desk.swift -o check-desk) || exit 1
ids=("${(@f)$(print -r -- "$windows" | cut -d'|' -f1)}")
for workspace in 1 2; do
  $W workspace "$workspace" >/dev/null
  sleep 1
  ~/desk/check-desk $ids || exit 1
done
$W workspace 1 >/dev/null
