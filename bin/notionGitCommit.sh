#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"
source "$root_dir/bin/notionPage.sh"

function notionGitCommit() {
  if [[ $(needToCallHelpFunction "$@") == 1 ]]; then notionGitCommitHelp; return; fi

  writeLog "$# inputs: $@"

  local commandArgs="$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--in-place)
        local isInPlace=true
        shift # past argument
        ;;
      -e|--env)
        if [[ ! " ${ENABLE_ENVIRONMENTS[*]} " =~ " $2 " ]]; then
          writeErrorLog "$2 is not a valid environment name ! (${ENABLE_ENVIRONMENTS[*]})"
          return
        fi
        local env=$2
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local techArg="--tech"
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
        # notion uuid || notion url || notion id
        if [[ $(isNotionUid "$1") == 0 || $(isNotionUrl "$1") == 0 || $(isNotionId "$1") == 0 ]]; then 
          local workitemId=$1
          shift # past argument
        else
          writeErrorLog "Unknown option $1 !"
          return
        fi
        ;;
    esac
  done
    
  local env="$env"
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi

  if [[ -z $workitemId ]]; then
    writeErrorLog "Need a task id !"
    return
  fi
  
  # recover ticket information on Azure
  echo -e "${CYAN_COLOR}Recover work item #${workitemId}${RESET_COLOR}" 
  local workitem=$( notionPage.sh $workitemId -s )
  if [[ $(isJson "$workitem") == 1 ]]; then
    writeErrorLog "$workitem"
    return
  fi

  writeLog "workitem: $workitem"

  local branchName=$( branchName.sh --workitem "$workitem" ${techArg:-} -e $env )
  local currentBranch=$(git symbolic-ref --short HEAD)
  writeLog "branchName: $branchName, currentBranch: $currentBranch"

  if [[ "$currentBranch" != "$branchName" ]]; then
    echo -e "${CYAN_COLOR}Creating branch $branchName${RESET_COLOR}"
    if [[ "$isInPlace" != true ]]; then 
      git branch -D $env &> /dev/null
      git checkout -q $env && git pull -q && git fetch -q
    fi
    git checkout -q -b $branchName
  else 
    echo -e "${CYAN_COLOR}Branch \"$branchName\" exists${RESET_COLOR}"
  fi

  local commitMessage=$( commitStandardMessage.sh --workitem "$workitem" ${techArg:-} )
  writeLog "commitMessage: $commitMessage"

  echo -e "${CYAN_COLOR}Creating commit $commitMessage${RESET_COLOR}"
  git add -A &> /dev/null
  git commit -q -m "$commitMessage"

  if [[ "${needPush:-false}" == true ]]; then
    # push or refresh remote branch
    echo -e "${CYAN_COLOR}Pushing branch $branchName${RESET_COLOR}"
    local remoteBranchExists=$(git ls-remote --heads origin refs/heads/${branchName})
    if [[ -z "$remoteBranchExists" ]]; then 
      git push -q --set-upstream origin "$branchName"
    else
      git push -q -u --force
    fi
  fi

  if [[ "${buildPullRequest:-false}" == true ]]; then
    echo -e "${CYAN_COLOR}Building pull request on $env${RESET_COLOR}"
    azureCreatePullRequest.sh -e $env --workitem "$workitem" 
  fi
}

function notionGitCommitHelp() {
  echo -e "
Usage: notionGitCommit [WORKITEM_ID] [OPTION...] [COMMAND]...
Create normalized commit from notion task

Options:
  -t, --tech                         Set tech flag for branch name and commit name
  -i, --in-place                     Set in place flag to create branch from
  -e, --env [develop|staging|main]   Set environment of branch (default: develop)
  -p, --push                         Push branch after commit created
  -pr, --pull-request                Create pull request for branch on specified environment
Commands:
  -h, --help                         Displays this help and exists
Examples:
  notionGitCommit 2783
  notionGitCommit 2783 -pr -e main
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    notionGitCommit "$@"
fi