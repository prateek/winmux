#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/sidebar-tree/details
mkdir -p "$out"
navigate() {
  osascript -e 'tell application "System Events" to tell process "Safari" to set frontmost to true' \
    -e 'tell application "System Events" to keystroke "l" using command down'
  cliclick "t:file://$HOME/sidebar-tree/index.html$1" kp:return w:500
  sleep 2
}
capture() { screencapture -x "$out/$1.png"; "$HOME/sidebar-tree/read-page" > "$out/$1.txt"; }
navigate '?selftest#tests'
capture selftest
navigate '?theme=light#widths'
capture widths-light
navigate '?theme=dark#cards'
capture comparison-dark
navigate '?theme=light#cards'
capture comparison-light
navigate '?theme=dark&view=work&variant=B'
capture B-dark
# Notes into the gap between the two Ghostty windows, using actual dragged events.
"$HOME/sidebar-tree/drag" 420 497 465 378
cliclick m:1750,180 w:600
capture B-insertion
navigate '?theme=light&view=work&variant=B'
"$HOME/sidebar-tree/drag" 420 365 254 490
cliclick m:1750,180 w:600
cliclick c:420,786 w:300
capture B-destination-miniature
cliclick c:725,114 c:735,183 m:238,300 w:500
"$HOME/sidebar-tree/drag" 420 365 254 490
cliclick m:1750,180 w:800
capture B-drag-end-collapse
cliclick c:725,114 c:735,183 m:1750,180 w:300
"$HOME/sidebar-tree/drag" 420 342 420 522
cliclick m:1750,180 w:600
capture B-nested-group
cliclick c:420,546 w:500
capture B-nested-miniature
