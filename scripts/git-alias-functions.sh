#!/bin/bash

# Git clean branch : passe sur develop et supprime la branche précédemment en cours
function gcb() {
  local current_branch=$(git symbolic-ref --short HEAD)
  if [[ "$current_branch" != 'develop' ]]; then
    gcd
    git br -D ${current_branch}
  fi
}

# Git delete branch : supprime la branche désigné en remote (sur le serveur)
function gdb() {
  if [[ -n "$1" ]]; then
    git push origin --delete "$1"
  fi
}

# Git rename branch : Renomme la branche en cours (ou la branche désigné) en local et en remote
function grb() {
  local old_branch_name
  local new_branch_name

  if [[ $# == 2 && -n "${1}" && -n "${2}" ]]; then
    old_branch_name="${1}"
    new_branch_name="${2}"
  else
    old_branch_name=$(git symbolic-ref --short HEAD)
    new_branch_name="${1}"
  fi

  if [[ -n "${new_branch_name}" && -n "${old_branch_name}" ]]; then
    git br -m "${new_branch_name}"
    git push origin -u "${new_branch_name}"
    gdb "${old_branch_name}"
  fi
}

function removeLocalOrphanBranch() {
  local remote=( $( git branch -r --format="%(refname:short)" | while read b; do echo '"'$b'"'; done ) ) 
  local local=( $( git branch --format="%(refname:short)" | while read b; do echo '"'$b'"'; done ) )

  for branch in "${local[@]}"; do
    if [[ $(echo ${remote[@]} | fgrep -cw "$branch") -eq 0 ]]; then
      git branch -D $branch
    fi
  done
}