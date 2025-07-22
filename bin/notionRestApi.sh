#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function notionRestApi() {
    if [[ $(needToCallHelpFunction "$@") == 1 ]]; then notionRestApiHelp; return; fi

    writeLog "notionRestApi() $@"

    local version
    version=$( getNotionVersion; exit $? )
    local cmdState=$?
    if [[ $cmdState -gt 0 ]]; then 
        echo "$version"
        return $cmdState
    fi

    local token
    token=$( getNotionToken; exit $? )
    local cmdState=$?
    if [[ $cmdState -gt 0 ]]; then 
        echo "$token"
        return $cmdState
    fi

    local url=$1
    local jsonBody=$2

    if [[ -z "$url" ]]; then
        writeErrorLog "notionRestApi function need a url !"
        return
    fi

    if [[ -z "$jsonBody" ]]; then local method="GET"; else local method="POST"; fi

    local fullUrl="https://api.notion.com/$url"
    local filePath="/tmp/$(randomAlphaNumeric)"

    writeLog "fullUrl: $fullUrl\nmethod: $method\nBearer $token\nfile path: $filePath\nbody: $jsonBody"

    curl -s -X $method \
        -H "Content-Type: application/json" \
        -H "Notion-Version: $version" \
        -H "Authorization: Bearer $token" \
        -d "${jsonBody:-}" \
        $fullUrl > $filePath

    echo $filePath
}


function notionRestApiHelp() {
    echo -e "
Usage: notionRestApi API_URL [BODY]
Call an Notion API and return path of file containing the json response

Commands:
    -h, --help                         Displays this help and exists
Examples:
    notionRestApi 2783
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    notionRestApi "$@"
fi