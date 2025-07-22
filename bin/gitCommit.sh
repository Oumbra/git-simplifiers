#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function gitCommit() {
    if [[ $(needToCallHelpFunction "$@") == 1 ]]; then gitCommitHelp; return; fi

    if [[ "$@" =~ "--azure-workitem" ]]; then
        local $isAzure=true
    fi

    if [[ "${isAzure:-false}" == true ]]; then
        azureGitCommit.sh $@
    else
        notionGitCommit.sh $@
    fi
}

function gitCommitHelp() {
  echo -e "
Usage: gitCommit [WORKITEM_ID] [OPTION...] [COMMAND]...
Create normalized commit from notion task or azure workitem

Options:
  --azure-workitem                   Set azure flag to recover azure or notion workitem from id 
  -e, --env [develop|staging|main]   Set environment of branch (default: develop)
  -p, --push                         Push branch after commit created
  -i, --in-place                     Set in place flag to create branch from
  -pr, --pull-request                Create pull request for branch on specified environment
  -t, --tech                         Set tech flag for branch name and commit name
Commands:
  -h, --help                         Displays this help and exists
Examples:
  gitCommit TASK-1138 -pr                        // create branch from develop, commit and pull request for notion task
  gitCommit SUP-213 -i -p                        // create branch from actual place, commit and push
  gitCommit 2783 -pr -e main --azure-workitem    // create branch from main, commit and pull request to main for azure workitem
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitCommit "$@"
fi