#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureWorkItem() {
  writeLog "azureWorkItem() $@"
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureWorkItemHelp; return; fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--standard)
        local isStandard=true
        shift 1 # past argument
        ;;
      *|-*|--*)
        if [[ $(echo "$1" | grep -Ec '^[0-9]+$') == 0 ]]; then
          writeErrorLog "Unknown option $1 !"
          return
        fi
        local workitemId=$1
        shift 1 # past argument
        ;;
    esac
  done

  local responsePath=$(azureRestApi.sh "wit/workitems/$workitemId?api-version=7.1-preview.3")
  if [[ $(isJson "$responsePath") == 1 ]]; then
    writeErrorLog "Cannot recover workitem #$workitemId :\n$responsePath"
    return 1
  fi

  local workitemNotExists=$(jqAlias "$responsePath" -e 'has("message")')
  if [[ $workitemNotExists == true ]]; then
    local message=$( jqAlias "$responsePath" -r '.message' )
    writeErrorLog "$message"
    return 1
  fi

  if [[ "${isStandard:-false}" == true ]]; then
    azureWorkitemStandardized $responsePath
  else
    echo $responsePath
  fi
}

function azureWorkitemStandardized() {
  writeLog "$# input(s): $@"
  
  local workitem=$1
  local workitemId=$(jqAlias "$workitem" -r '.id')
  local workitemState=$(jqAlias "$workitem" -r '.fields."System.State"')
  local workitemTitle=$(jqAlias "$workitem" -r '.fields."System.Title"')
  local workitemType=$(jqAlias "$workitem" -r '.fields."System.WorkItemType"')
  local workitemLink=$(jqAlias "$workitem" -r '.url')

  jq -c -n \
    --arg id "$workitemId" \
    --arg state "$workitemState" \
    --arg title "$workitemTitle" \
    --arg type "$workitemType" \
    --arg link "$workitemLink" \
    '{
      "id": $id,
      "state": $state,
      "title": $title,
      "type": $type,
      "link": $link
    }'

}

function azureWorkItemHelp() {
    echo -e "
Usage: azureWorkItem WorkitemId
Return path of file containing workitem json

Options:
  -s, --standard                       Set standard flag to return a standard workitem object
Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureWorkItem 2783
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureWorkItem "$@"
fi