#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function branchName() {
  writeLog "$# inputs: $@"
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then branchNameHelp; return; fi
  
  local commandArgs="$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        if [[ ! " ${ENABLE_ENVIRONMENTS[@]} " =~ " $2 " ]]; then
          writeErrorLog "$2 is not a valid environment name ! (${ENABLE_ENVIRONMENTS[@]})"
          return
        fi
        local env="$2"
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -w|--workitem)
        local workitem="$2"
        if [[ $(isJson "$workitem") == 1 || $(checkJsonStructure "$workitem" $WORKITEM_KEYS) == 1 ]]; then
          writeErrorLog "workitem object not valid for $WORKITEM_KEYS :\n${workitem}"
          return
        fi
        shift 2 # past argument and value
        ;;
      *|-*|--*)
        writeErrorLog "Unknown option "$1" !"
        return
        ;;
    esac
  done

  local env="$env"
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi
  if [[ -z "$workitem" ]]; then
    writeErrorLog "Need a workitem !"
    return
  fi

  local workitemId=$( jqAlias "$workitem" -r '.id' )
  local workitemType=$( jqAlias "$workitem" -r '.type |= ascii_upcase | .type' )
  local trigram=$(cd ~ && pwd | perl -pe 's/.*\/([^\/]{3}).*$/\L$1/g')
  writeLog "workitemId: $workitemId, workitemType: $workitemType, trigram: $trigram"

  case "$workitemType" in
    "BUG") local branchType="fix";;
    *) 
      if [[ "${isTechWork:-false}" == true ]]; then local branchType="tech" 
      else local branchType="feature"
      fi
    ;;
  esac

  local branchName="$branchType/$trigram/$workitemId"
  if [[ ! -z "$env" ]] && [[ "$env" != "develop" ]]; then local branchName="${branchName}-${env}"; fi

  echo $branchName
}

function branchNameHelp() {
    echo -e "
Usage: branchName [OPTION...] [COMMAND]...
Return branch name from workitem

Worktitem must have propeties: id, state, title, type and link 

Options:
    -e, --env [develop|staging|main]   Set environment of branch (default: develop)
    -t, --tech                         Set tech flag for branch name and commit name
    -w, --workitem                     Set workitem object
Commands:
    -h, --help                         Displays this help and exists
Examples:
    branchName -w "{...}"
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  branchName "$@"
fi