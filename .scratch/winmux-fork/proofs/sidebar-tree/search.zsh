#!/bin/zsh
set -eu
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
keys() { ~/desk/keys "$(date +%s)" "$HOME/takes/sidebar-tree/$1.events.json" "${@:2}"; }
live clicklabel column-collapsed 'Column 1 · 28%'
live clicklabel column-reopened 'Column 1 · 28%'
live disclose safari-collapsed '@tabs:3'
live disclose both-tabs-collapsed '@tabs:2'
keys search-safari down:shift tap:s up:shift tap:a tap:f tap:a tap:r tap:i wait:1
live snapshot search-safari
keys clear-safari tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace wait:1
live snapshot clear-safari
keys search-grievances down:shift tap:g up:shift tap:r tap:i tap:e tap:v tap:a tap:n tap:c tap:e tap:s wait:1
live snapshot search-grievances
keys clear-grievances tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace wait:1
live snapshot clear-grievances
keys search-none tap:q tap:z tap:x tap:n tap:o tap:m tap:a tap:t tap:c tap:h wait:1
live snapshot search-none
keys clear-none tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace tap:backspace wait:1
live snapshot clear-none
live disclose safari-reopened '@tabs:3'
live disclose disclosure-reopened '@tabs:2'
