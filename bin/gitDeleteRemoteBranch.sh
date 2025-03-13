#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

# TODO 
function gitDeleteRemoteBranch() {
  if [[ -n "$1" ]]; then
    git push origin --delete "$1"
  fi
}

function gitDeleteRemoteBranchHelp() {
    echo -e "
# Git delete branch : supprime la branche désigné en remote (sur le serveur)
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitDeleteRemoteBranch $*
fi