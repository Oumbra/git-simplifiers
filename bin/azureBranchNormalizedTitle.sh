#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/constantes.sh"
source "$root_dir/bin/azureWorkItem.sh"

function azureBranchNormalizedTitle() {
  if [[ $# == 0 || "$@" =~ " -h " || $# == 1 && $1 == '-h' ]]; then azureBranchNormalizedTitleHelp; return; fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
  
  if [[ -z "$workitem" && -z "$workitemId" ]]; then
    echo -e "${redColor}azureBranchNormalizedTitle function need a workitem id or workitem !${resetColor}"
    return
  fi

  if [[ -z "$workitem" ]]; then
    local workitem=$(azureWorkItem $workitemId)
    if [[ $(isJson "$workitem") == 1 ]]; then
      echo -e "${redColor}$workitem${resetColor}"
      return
    fi
  fi

  if [[ -f "$workitem" ]]; then
    local workitemTitle=$( jq -r '.fields."System.Title"' "$workitem" )
    local workitemType=$( jq -r '.fields."System.WorkItemType"' "$workitem" )
  else
    local workitemTitle=$( echo $workitem | jq -r '.fields."System.Title"' )
    local workitemType=$( echo $workitem | jq -r '.fields."System.WorkItemType"' )
  fi

  case "$workitemType" in
    "Bug") local commitType="Fix";;
    *) 
      if [[ "${isTechWork:-false}" == true ]]; then local commitType="Tech" 
      else local commitType="Feat"
      fi
    ;;
  esac

  echo "${commitType}: #${workitemId} ${workitemTitle}"
}

function azureBranchNormalizedTitleHelp() {
    echo -e "
Usage: azureBranchNormalizedTitle [OPTION...] [COMMAND]...
Return azure workitem title

Options:
    -t, --tech                         Set tech flag for branch name and commit name
    -w, --workitem-id                  Set workitem id
    --workitem                         Set workitem object
Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureBranchNormalizedTitle -w 2783
    azureBranchNormalizedTitle -w 2783 -t
    azureBranchNormalizedTitle --workitem "{...}"
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureBranchNormalizedTitle $*
fi