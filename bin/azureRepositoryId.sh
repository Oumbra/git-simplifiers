#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureRepositoryId() {
    if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureRepositoryIdHelp; return; fi
    
    local repositoryName=$1
    # Appel de l'API pour lister les dépôts
    local responsePath=$( azureRestApi.sh "git/repositories?api-version=7.1-preview.1" )

    jqAlias -r '.value[] | select(.name == "'$repositoryName'") | .id' "$responsePath"
}

function azureRepositoryIdHelp() {
    echo "
Usage: azureRepositoryId REPOSITORY_NAME
Return id of repository

Arguments:
    Repository Name             Is mandatory
Commands:
    -h, --help                  Displays this help and exists
Examples:
    azureRepositoryId sopht
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureRepositoryId "$@"
fi