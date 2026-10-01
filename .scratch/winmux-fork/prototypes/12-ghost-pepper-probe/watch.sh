#!/bin/zsh
# Samples Ghost Pepper's CG windows and WinMux's view of them twice a second; logs only on change.
S=${0:A:h}
LOG=$S/cap/watch.log
BID=com.github.matthartman.ghostpepper
prev=""
end=$(( $(date +%s) + ${1:-900} ))
while (( $(date +%s) < end )); do
  cg=$("$S/cgwin" $BID 2>&1)
  wins=$(winmux list-windows --all --format '%{window-id} | %{app-bundle-id} | %{window-title} | %{workspace} | %{window-layout}' 2>&1 | grep -i -e ghostpepper -e 'Ghost Pepper')
  apps=$(winmux list-apps 2>&1 | grep -i ghostpepper)
  cur="$cg
-- winmux list-windows --all (ghostpepper rows):
$wins
-- winmux list-apps (ghostpepper rows):
$apps"
  if [[ "$cur" != "$prev" ]]; then
    print -r -- "===== $(date +%T)" >> $LOG
    print -r -- "$cur" >> $LOG
    for id in $(print -r -- "$cg" | awk '/onscreen=true/ {sub("id=","",$2); print $2}'); do
      if [[ ! -e $S/cap/debug-$id.txt ]]; then
        winmux debug-windows --window-id $id > $S/cap/debug-$id.txt 2>&1
        print -r -- "-- wrote debug-$id.txt ($(wc -l < $S/cap/debug-$id.txt) lines)" >> $LOG
      fi
    done
    prev=$cur
  fi
  sleep 0.5
done
