#!/bin/bash

function gitDeleteLocalOrphanBranch() {
  git fetch -q --prune
  local remote=($( git branch -r --format="%(refname:short)" | while read b; do echo '"'$b'"'; done )) 
  local local=($( git branch --format="%(refname:short)" | while read b; do echo '"origin/'$b'"'; done ))

  for branch in "${local[@]}"; do
    if [[ $(echo ${remote[@]} | fgrep -cw "$branch") -eq 0 ]]; then
      local localBranchName=$(echo $branch | sed -E 's/"origin\/(.+)"/\1/g')
      git branch -D $localBranchName
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitDeleteLocalOrphanBranch "$@"
fi