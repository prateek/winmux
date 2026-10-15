#!/bin/zsh
# Run in the guest before stage-desk.sh; Cmd-N gets the same staged terminal.
set -eu
mkdir -p ~/desk/repo
touch ~/.hushlogin
cp ~/desk/hero/zshrc ~/.zshrc
mkdir -p ~/.config/ghostty
cp ~/desk/hero/ghostty.config ~/.config/ghostty/config
~/desk/make-repo.sh
