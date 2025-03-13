#!/bin/bash

# Empêcher l'exécution directe
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Ce script ne peut pas être exécuté directement."
    exit 1
fi

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/functions.sh"

sopht_azure_organization="sopht"
sopht_azure_project="sopht"

function azureRestApi() {
    local url=$1
    local jsonBody=$2

    if [[ -z "$url" ]]; then
        echo -e "${redColor}azureRestApi function need a url !${resetColor}"
        return
    fi

    if [[ -z "${SOPHT_AZURE_ACCESSTOKEN}" ]]; then
        echo -e "${redColor}Environnment variable SOPHT_AZURE_ACCESSTOKEN is undefined !${resetColor}"
        return
    fi

    if [[ -z "$jsonBody" ]]; then local method="GET"; else local method="POST"; fi

    local fullUrl="https://dev.azure.com/$sopht_azure_organization/$sopht_azure_project/_apis/$url"
    local filePath="/tmp/$(randomAlphaNumeric)"

    echo -e "fullUrl: $fullUrl\nmethod: $method\nBasic $(echo -n ":$SOPHT_AZURE_ACCESSTOKEN" | base64)\nfile path: $filePath\nbody: $jsonBody" > ~/git-simplifiers.log

    curl -s -X $method \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $(echo -n ":$SOPHT_AZURE_ACCESSTOKEN" | base64)" \
    -d "${jsonBody:-}" \
    $fullUrl > $filePath

    echo $filePath
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureRestApi $*
fi