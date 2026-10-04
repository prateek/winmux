#!/bin/zsh
cd ~/desk/repo
export PS1='%F{244}desk%f %F{cyan}main%f %# '
clear
printf '\e]0;desk\a'
print -P '%F{244}desk%f %F{cyan}main%f %# git log --oneline'
git --no-pager log --oneline --color=always
exec zsh -f
