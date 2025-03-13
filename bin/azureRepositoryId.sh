#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/constantes.sh"
source "$root_dir/shared/azure/azureRestApi.sh"

function __azureRepositoryId() {
    local repositoryName=$1
    if [[ -z $repositoryName ]]; then
    echo -e "${redColor}azureRepositoryId function need a repository name !${resetColor}"
    return
    fi

    # Appel de l'API pour lister les dépôts
    local responsePath=$(azureRestApi "git/repositories?api-version=7.1-preview.1")

    jq -r '.value[] | select(.name == "'$repositoryName'") | .id' "$responsePath"
}

__azureRepositoryId $*