#!/bin/bash

# Git rename branch : Renomme la branche en cours (ou la branche désigné) en local et en remote
function gitRenameBranch() {
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
    gitDeleteRemoteBranch.sh "${old_branch_name}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitRenameBranch "$@"
fi