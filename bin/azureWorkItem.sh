#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureWorkItem() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureWorkItemHelp; return; fi

  local workitemId=$1
  local responsePath=$(azureRestApi.sh "wit/workitems/$workitemId?api-version=7.1-preview.3")
  if [[ $(isJson "$responsePath") == 1 ]]; then
    echo -e "${redColor}Cannot recover workitem #$workitemId :\n$responsePath${resetColor}"
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