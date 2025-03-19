#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureGitCommit() {
  if [[ $(needToCallHelpFunction $*) == 1 ]]; then azureGitCommitHelp; return; fi

  local commandArgs="$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--in-place)
        local isInPlace=true
        shift # past argument
        ;;
      -e|--env)
        if [[ ! " ${environments[*]} " =~ " $2 " ]]; then
          echo -e "${redColor}$2 is not a valid environment name ! (${environments[*]})${resetColor}"
          return
        fi
        local env=$2
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -p|--push)
        local needPush=true
        shift # past argument
        ;;
      -pr|--pull-resquest)
        local needPush=true
        local buildPullRequest=true
        shift # past argument
        ;;
      *|-*|--*)
        if [[ $(echo "$1" | grep -Ec '^[0-9]+$') == 1 ]]; then 
          local workitemId=$1
          shift # past argument
        else
          echo -e "${redColor}Unknown option $1 !${resetColor}"
          return
        fi
        ;;
    esac
  done
  
  local env="$env"
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi

  if [[ -z $workitemId ]]; then
    echo -e "${redColor}azureGitCommit function need a workitem id !${resetColor}"
    return
  fi
  
  # recover ticket information on Azure
  echo -e "${cyanColor}Recover work item #${workitemId}${resetColor}" 
  local workitem=$( azureWorkItem.sh $workitemId )
  if [[ $(isJson "$workitem") == 1 ]]; then
    echo -e "${redColor}$workitem${resetColor}"
    return
  fi

  if [[ "$isTechWork" == true ]]; then local techArg="--tech"; fi

  local branchName=$( azureBranchName.sh --workitem "$workitem" ${techArg:-} -e $env )
  local currentBranch=$(git symbolic-ref --short HEAD)

  if [[ "$currentBranch" != "$branchName" ]]; then
    echo -e "${cyanColor}Creating branch $branchName${resetColor}"
    if [[ "$isInPlace" != true ]]; then 
      git branch -D $env &> /dev/null
      git checkout -q $env && git pull -q && git fetch -q
    fi
    git checkout -q -b $branchName
  else 
    echo -e "${cyanColor}Branch \"$branchName\" exists${resetColor}"
  fi

  local commitMessage=$( azureBranchNormalizedTitle.sh --workitem "$workitem" ${techArg:-} )

  echo -e "${cyanColor}Creating commit $commitMessage${resetColor}"
  git add -A &> /dev/null
  git commit -q -m "$commitMessage"

  if [[ "${needPush:-false}" == true ]]; then
    # push or refresh remote branch
    echo -e "${cyanColor}Pushing branch $branchName${resetColor}"
    local remoteBranchExists=$(git ls-remote --heads origin refs/heads/${branchName})
    if [[ -z "$remoteBranchExists" ]]; then 
      git push -q --set-upstream origin "$branchName"
    else
      git push -q --force
    fi
  fi

  if [[ "${buildPullRequest:-false}" == true ]]; then
    echo -e "${cyanColor}Building pull request on $env${resetColor}"
    azureCreatePullRequest.sh -e $env --workitem "$workitem"
  fi
}

function azureGitCommitHelp() {
  echo -e "
Usage: azureGitCommit [WORKITEM_ID] [OPTION...] [COMMAND]...
Create normalized commit from azure workitem

Options:
  -t, --tech                         Set tech flag for branch name and commit name
  -i, --in-place                     Set in place flag to create branch from
  -e, --env [develop|staging|main]   Set environment of branch (default: develop)
  -p, --push                         Push branch after commit created
  -pr, --pull-request                Create pull request for branch on specified environment
Commands:
  -h, --help                         Displays this help and exists
Examples:
  azureGitCommit 2783
  azureGitCommit 2783 -pr -e main
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureGitCommit $*
fi