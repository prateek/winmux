#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
swiftc ~/sidebar-tree-proof/measure.swift -o ~/sidebar-tree-proof/measure
swiftc ~/sidebar-tree-proof/scroll.swift -o ~/sidebar-tree-proof/scroll
for theme in light dark; do
    [[ $theme == dark ]] && mode=true || mode=false
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $mode"
    for width in 240 280 320; do
        for levels in flat both; do
            name=width-$theme-$width-$levels
            cp "$HOME/sidebar-tree-proof/configs/$levels-$width.ncl" ~/.config/winmux/winmux.ncl
            $W reload-config
            $W workspace 1
            sleep 4
            cliclick m:310,1010 w:350
            python3 ~/sidebar-tree-proof/live.py snapshot "$name"
            ~/sidebar-tree-proof/measure "$HOME/takes/sidebar-tree/$name.ui.json" "$width" > "$HOME/takes/sidebar-tree/$name.measure.json"
        done
    done
done
cp ~/sidebar-tree-proof/configs/both-240.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
python3 ~/sidebar-tree-proof/live.py hoverlabel clipped-title-tooltip '@tabs:3'
cp ~/sidebar-tree-proof/configs/both-short.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
cliclick m:200,800 w:500
python3 ~/sidebar-tree-proof/live.py snapshot shorter-height-top
~/sidebar-tree-proof/scroll -700
sleep 1
python3 ~/sidebar-tree-proof/live.py snapshot shorter-height-bottom
cp ~/sidebar-tree-proof/configs/both-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
sleep 4
