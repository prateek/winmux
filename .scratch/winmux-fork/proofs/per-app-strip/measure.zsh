#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
tree=${1:?source tree}
label=${2:?base or head}
proof=$HOME/per-app-proof
flags=()
[[ $label == head ]] && flags+=(-D HEAD)
swiftc $flags "$tree/Sources/AppBundle/lens/Tile.swift" "$tree/Sources/AppBundle/lens/GridLayout.swift" "$proof/main.swift" -o "$proof/measure-$label"
for count in 10 11; do
  "$proof/measure-$label" "$HOME/per-app-captures/$label/$count-world.json" "$HOME/per-app-captures/$label/$count-mru.txt" > "$HOME/per-app-captures/$label/$count-measurements.txt"
done
