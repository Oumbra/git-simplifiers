#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function gitDeleteRemoteBranch() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then gitDeleteRemoteBranchHelp; return; fi

  local branchName=$1
  
  if [[ -z $branchName ]]; then
    echo -e "${redColor}gitDeleteRemoteBranch command need a branch name !${resetColor}"
    return
  fi
  
  git push origin --delete "$1"
}

function gitDeleteRemoteBranchHelp() {
    echo -e "
Usage: gitDeleteRemoteBranchHelp BRANCH_NAME
Delete remote branch by name

Commands:
    -h, --help                         Displays this help and exists
Examples:
    gitDeleteRemoteBranchHelp f/tri/2783
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitDeleteRemoteBranch $*
fi