#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureBranchName() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureBranchNameHelp; return; fi

  local commandArgs="$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        if [[ ! " ${environments[@]} " =~ " $2 " ]]; then
          echo -e "${redColor}$2 is not a valid environment name ! (${environments[@]})${resetColor}"
          return
        fi
        local env=$2
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -w|--workitem-id)
        if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
          echo -e "${redColor}$2 is not workitem id !${resetColor}"
          return
        fi
        local workitemId=$2
        shift 2 # past argument and value
        ;;
      --workitem)
        if [[ $(isJson "$2") == 1 ]]; then
          echo -e "${redColor}Workitem is not a valid JSON: $2${resetColor}"
          return
        fi
        local workitem=$2
        shift 2 # past argument and value
        ;;
      *|-*|--*)
        echo -e "${redColor}Unknown option $1 !${resetColor}"
        return
        ;;
    esac
  done
  
  local env="$env"
  # if [[ "$commandArgs" =~ "--env " ]] then echo "have --env option : $env"; fi
  # if [[ "$commandArgs" =~ "-e " ]] then echo "have -e option : $env"; fi
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi
  
  if [[ -z "$workitem" && -z "$workitemId" ]]; then
    echo -e "${redColor}azureBranchName function need a workitem id or workitem !${resetColor}"
    return
  fi

  if [[ -z "$workitem" ]]; then
    local workitem=$(azureWorkItem.sh $workitemId)
    if [[ $(isJson "$workitem") == 1 ]]; then
      echo -e "${redColor}${workitem}${resetColor}"
      return
    fi
  fi

  if [[ -f "$workitem" ]]; then
    local workitemType=$( jq -r '.fields."System.WorkItemType"' "$workitem" )
  else
    local workitemType=$( echo $workitem | jq -r '.fields."System.WorkItemType"' )
  fi
  
  local trigram=$(cd ~ && pwd | perl -pe 's/.*\/([^\/]{3}).*$/\L$1/g')

  case "$workitemType" in
    "Bug") local branchType="fix";;
    *) 
      if [[ "${isTechWork:-false}" == true ]]; then local branchType="tech" 
      else local branchType="f"
      fi
    ;;
  esac

  local branchName="$branchType/$trigram/$workitemId"
  if [[ ! -z "$env" ]] && [[ "$env" != "develop" ]]; then local branchName="${branchName}-${env}"; fi

  echo $branchName
}

function azureBranchNameHelp() {
    echo -e "
Usage: azureBranchName [OPTION...] [COMMAND]...
Return branch name of azure workitem

Options:
    -e, --env [develop|staging|main]   Set environment of branch (default: develop)
    -t, --tech                         Set tech flag for branch name and commit name
    -w, --workitem-id                  Set workitem id
    --workitem                         Set workitem object
Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureBranchName -w 2783
    azureBranchName -w 2783 -t
    azureBranchName -w 2783 -e staging
    azureBranchName --workitem "{...}"
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureBranchName $*
fi