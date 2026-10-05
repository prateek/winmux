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
defaults write com.apple.Notes hasShownWelcomeScreen -bool true
defaults write com.apple.Notes bypassICloudAlert -bool true
open -a Notes
sleep 5
osascript -e 'tell application "Notes" to quit'
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
