#!/bin/zsh
# Rewrites the file VS Code has open every 100 ms: 60 lines whose length and text change each tick.
zmodload zsh/datetime
f=$1
n=0
while :; do
  n=$((n + 1))
  {
    for i in {1..60}; do
      print -r -- "${(l:$(( (n * 13 + i * 7) % 90 + 5 ))::#:)} $EPOCHREALTIME tick $n line $i"
    done
  } > "$f.tmp"
  cat "$f.tmp" > "$f"
  sleep 0.1
done
