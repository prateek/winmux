#!/bin/zsh
# Run in the guest before stage-desk.sh; Cmd-N gets the same staged terminal.
set -eu
mkdir -p ~/desk/repo
touch ~/.hushlogin
mkdir -p ~/.config/ghostty
{ cat ~/desk/hero/ghostty.config; print -r -- "command = $HOME/desk/term.sh"; } > ~/.config/ghostty/config
~/desk/make-repo.sh
