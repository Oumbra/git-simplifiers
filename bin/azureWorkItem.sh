#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/constantes.sh"
source "$root_dir/shared/azure/azureRestApi.sh"

function azureWorkItem() {
  local workitemId=$1
  
  if [[ -z $workitemId ]]; then
    echo -e "${redColor}azureWorkItem function need a workitem id !${resetColor}"
    return
  fi

  local responsePath=$(azureRestApi "wit/workitems/$workitemId?api-version=7.1-preview.3")
  if [[ $(isJson "$responsePath") == 1 ]]; then
    echo -e "${redColor}Impossible to recover workitem #$workitemId :\n$responsePath${resetColor}"
    return 1
  fi

  local workitemNotExists=$(jq -e 'has("message")' "$responsePath")
  if [[ $workitemNotExists == true ]]; then
    local message=$( jq -r '.message' "$responsePath" )
    echo -e "${redColor}${message}${resetColor}"
    return 1
  fi

  echo $responsePath
}

function azureWorkItemHelp() {
    echo -e "
Usage: azureWorkItem WorkitemId
Return path of file containing workitem json

Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureWorkItem 2783
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureWorkItem $*
fi