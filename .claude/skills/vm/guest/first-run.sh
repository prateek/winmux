#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
cd ~/vm
python3 quiet-desktop.py
killall donotdisturbd 2>/dev/null || true
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
defaults write com.apple.notificationcenterui widgets '<dict><key>vers</key><integer>1</integer><key>instances</key><array/></dict>'
defaults write com.apple.tips TipsEnabled -bool false
mkdir -p ~/.config/ghostty
printf 'auto-update = off\nwindow-save-state = never\n' > ~/.config/ghostty/config
open -a Notes
sleep 5
osascript -e 'tell application "Notes" to quit'
sleep 2
notes="$HOME/Library/Containers/com.apple.Notes/Data/Library/Preferences/com.apple.Notes"
defaults write "$notes" hasShownWelcomeScreen -bool true
defaults write "$notes" bypassICloudAlert -bool true
# The welcome is also gated by the last displayed OS version, not just hasShownWelcomeScreen.
startup_version=$(python3 -c 'import platform; v=platform.mac_ver()[0].split("."); v += ["0"] * (3-len(v)); print("<array>" + "".join("<integer>" + n + "</integer>" for n in v) + "</array>")')
defaults write "$notes" lastShownStartupVersion-1 "$startup_version"
killall cfprefsd 2>/dev/null || true
# Register the Dock tile once in the image, so clones do not offer it on first launch.
swiftc -O dismiss-registration.swift -o dismiss-registration
open /Applications/Ghostty.app
./dismiss-registration
sleep 1
pkill -x ghostty || true
pkill -x Ghostty || true
sleep 2
rm -rf ~/Library/Saved\ Application\ State/com.mitchellh.ghostty.savedState
killall NotificationCenter 2>/dev/null || true
