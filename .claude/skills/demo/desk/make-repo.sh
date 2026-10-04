#!/bin/zsh
# The desk's own repository: its log is what the terminal shows.
cd ~/desk/repo && rm -rf .git && git init -q -b main && git config user.name desk && git config user.email desk@example.invalid
for message in "initial commit. it gets worse" "add columns" "remove columns" "add columns, but correctly this time" "wip: do not look at this" 'revert "trust me"' "fix: it was the cache. it is always the cache." "final. (not final)"; do
  git commit -q --allow-empty -m "$message"
done
