#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
original=$(cat ~/captures/reduce-motion-original.txt)
restore() {
  if [[ "$original" == missing ]]; then
    defaults delete com.apple.universalaccess reduceMotion
  else
    defaults write com.apple.universalaccess reduceMotion -bool "$original"
  fi
  swift -e 'import AppKit; print(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)' > ~/captures/reduce-motion-restored.txt
}
trap restore EXIT
actual=$(swift -e 'import AppKit; print(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)')
[[ "$actual" == true ]] || { print -u2 'Reduce Motion is not active'; exit 1; }
zsh ~/peek-proof/no-thumbnail.zsh reduced-motion
