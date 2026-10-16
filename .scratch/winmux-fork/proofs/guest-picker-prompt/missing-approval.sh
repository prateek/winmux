#!/bin/bash
set -eu
out=$HOME/takes/missing-approval
mkdir -p "$out"
approvals="$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"
saved="$approvals.issue87-held"
[ ! -e "$saved" ]
restore() { [ ! -e "$saved" ] || mv "$saved" "$approvals"; }
trap restore EXIT
mv "$approvals" "$saved"
if ~/vm/preflight > "$out/missing.txt" 2>&1; then result=0; else result=$?; fi
echo "exit=$result" >> "$out/missing.txt"
[ "$result" -eq 1 ]
grep -q '^FAIL approvals:' "$out/missing.txt"
mv "$saved" "$approvals"
trap - EXIT
~/vm/preflight > "$out/restored.txt" 2>&1
echo 'exit=0' >> "$out/restored.txt"
screencapture -x "$out/final.png"
cat "$out/missing.txt" "$out/restored.txt"
