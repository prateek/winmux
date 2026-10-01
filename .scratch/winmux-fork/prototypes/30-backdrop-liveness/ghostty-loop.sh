#!/bin/zsh
# Repaints the whole terminal with a new background colour and a timestamp every 50 ms.
zmodload zsh/datetime
n=0
while :; do
  n=$((n + 1))
  printf '\e[48;5;%dm\e[2J\e[H\n\n   %s   tick %d\n' $((16 + n * 7 % 216)) "$EPOCHREALTIME" $n
  sleep 0.05
done
