#!/bin/bash
# Turn a Cirrus macOS Xcode image into the golden image: tools, grants, a bare desktop.
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1
cd ~/vm

brew install ffmpeg cliclick gifski gifsicle uv rsync
# The set: real tools that look good small and need no sign-in.
# Cask downloads go stale: refresh the definitions the image shipped with.
HOMEBREW_NO_AUTO_UPDATE= brew update --quiet
brew install --cask ghostty zed
# Gatekeeper asks before the first launch of a quarantined app, and the question blocks `open`.
sudo xattr -dr com.apple.quarantine /Applications/Ghostty.app /Applications/Zed.app
command -v cargo >/dev/null || curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
swiftc -O display.swift -o display
swiftc -O preflight.swift -o preflight
bash grant.sh
bash automation.sh

sudo scutil --set HostName winmux-vm; sudo scutil --set LocalHostName winmux-vm; sudo scutil --set ComputerName winmux-vm
pkill -x Terminal || true
rm -rf ~/Library/Saved\ Application\ State/com.apple.Terminal.savedState
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.WindowManager StandardHideWidgets -int 1
defaults write com.apple.WindowManager StandardHideDesktopIcons -int 1
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
defaults write com.apple.screensaver idleTime -int 0
sudo pmset -a displaysleep 0 sleep 0
sudo softwareupdate --schedule off >/dev/null
killall Dock
echo PROVISIONED
