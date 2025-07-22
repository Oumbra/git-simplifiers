#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureRestApi() {
    if [[ $(needToCallHelpFunction "$@") == 1 ]]; then azureRestApiHelp; return; fi
  
    local url=$1
    local jsonBody=$2

    if [[ -z "$url" ]]; then
        writeErrorLog "azureRestApi function need a url !"
        return
    fi

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

    local project
    project=$( getAzureProject; exit $? )
    local cmdState=$?
    if [[ $cmdState -gt 0 ]]; then 
        echo "$project"
        return $cmdState
    fi

    if [[ -z "$jsonBody" ]]; then local method="GET"; else local method="POST"; fi

    local fullUrl="https://dev.azure.com/$organization/$project/_apis/$url"
    local filePath="/tmp/$(randomAlphaNumeric)"

    writeLog "fullUrl: $fullUrl\nmethod: $method\nBasic $(echo -n ":$token" | base64 -w 0)\nfile path: $filePath\nbody: $jsonBody"

    curl -L -s -X $method \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n ":$token" | base64 -w 0)" \
        -d "${jsonBody:-}" \
        $fullUrl > $filePath

    echo $filePath
}


function azureRestApiHelp() {
    echo -e "
Usage: azureRestApi API_URL [BODY]
Call an Azure API and return path of file containing the json response

Commands:
    -h, --help                         Displays this help and exists
Examples:
    azureRestApi 2783
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureRestApi "$@"
fi