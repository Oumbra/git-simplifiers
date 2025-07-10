#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function commitStandardMessage() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then commitStandardMessageHelp; return; fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -w|--workitem)
        local workitem="$2"
        if [[ $(isJson "$workitem") == 1 || $(checkJsonStructure "$workitem" $WORKITEM_KEYS) == 1 ]]; then
          writeErrorLog "Workitem is not a valid JSON: $2"
          return
        fi
        shift 2 # past argument and value
        ;;
      *|-*|--*)
        writeErrorLog "Unknown option $1 !"
        return
        ;;
    esac
  done
  
  if [[ -z "$workitem" ]]; then
    writeErrorLog "Need a workitem !"
    return
  fi

  local workitemId=$( jqAlias "$workitem" -r '.id'  )
  local workitemTitle=$( jqAlias "$workitem" -r '.title' )
  local workitemType=$( jqAlias "$workitem" -r '.type' )

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

function commitStandardMessageHelp() {
    echo -e "
Usage: commitStandardMessage [OPTION...] [COMMAND]...
Return standard commit message

Worktitem must have propeties: id, state, title, type and link 

Options:
    -t, --tech                         Set tech flag for branch name and commit name
    -w, --workitem                     Set workitem object
Commands:
    -h, --help                         Displays this help and exists
Examples:
    commitStandardMessage -w "{...}"
    commitStandardMessage -w "{...}" -t
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    commitStandardMessage "$@"
fi