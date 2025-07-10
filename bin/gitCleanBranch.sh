#!/bin/bash

# Git clean branch : passe sur develop et supprime la branche précédemment en cours
function gitCleanBranch() {
  local current_branch=$(git symbolic-ref --short HEAD)
  if [[ "$current_branch" != 'develop' ]]; then
    git co develop
    git brd ${current_branch}
  fi

  git fetch && git pull
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitCleanBranch "$@"
fi