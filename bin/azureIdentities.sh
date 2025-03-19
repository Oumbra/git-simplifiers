#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureIdentities() {
    if [[ $(needToCallHelpFunctionWithoutArgs $@) == 1 ]]; then azureIdentitiesHelp; return; fi

    local token
    token=$( getAzureToken; exit $? )
    local cmdState=$?
    if [[ $cmdState -gt 0 ]]; then 
        echo "$token"
        return $cmdState
    fi

    local organization
    organization=$( getAzureOrganizaton; exit $? )
    local cmdState=$?
    if [[ $cmdState -gt 0 ]]; then
        echo "$organization"
        return $cmdState
    fi

    curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n ":$token" | base64)" \
        "https://vssps.dev.azure.com/$organization/_apis/identities?api-version=7.2-preview.1"
}

function azureIdentitiesHelp() {
    echo -e "
Usage: azureIdentities
Return list of identities

Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureIdentities
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureIdentities $*
fi