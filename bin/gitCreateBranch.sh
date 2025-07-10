#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function gitCreateBranch() {
    writeLog "$# inputs: $@"
    if [[ $(needToCallHelpFunction $@) == 1 ]]; then gitCreateBranchHelp; return; fi
  
    local commandArgs="$@"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--in-place)
                local isInPlace=true
                shift # past argument
                ;;
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
            -w|--workitem-id)
                if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
                    writeErrorLog "$2 is not workitem id !"
                    return
                fi
                local workitemId=$2
                shift 2 # past argument and value
                ;;
            --workitem)
                local workitem="$2"
                if [[ $(isJson "$workitem") == 1 || $(checkJsonStructure "$workitem" $WORKITEM_KEYS) == 1 ]]; then
                    writeErrorLog "workitem object not valid for $WORKITEM_KEYS :\n${workitem}"
                    return
                fi
                shift 2 # past argument and value
                ;;
            --azure-workitem)
                local isAzureWorkitem=true
                shift 1
                ;;
            *|-*|--*)
                writeErrorLog "Unknown option "$1" !"
                return
                ;;
        esac
    done


}

function gitCreateBranchHelp() {
    echo -e "
Usage: gitCreateBranch [OPTION...] [COMMAND]...
Create the branch and swith on from workitem

Worktitem must have propeties: id, state, title, type and link 

Options:
    -e, --env [develop|staging|main]   Set environment of branch (default: develop)
    -i, --in-place                     Set in place flag to create branch from
    -t, --tech                         Set tech flag for branch name and commit name
    -w, --workitem-id                  Set workitem object
    --workitem                         Set workitem object (standard)
    --azure-workitem                   Set azure flag to recover azure or notion workitem from id (only with -w or --workitem-id)
Commands:
    -h, --help                         Displays this help and exists
Examples:
    gitCreateBranch -w 1005
    gitCreateBranch -w 465 --azure-workitem
    gitCreateBranch --worktitem "{...}"
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  gitCreateBranch "$@"
fi