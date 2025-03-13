#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

sopht_azure_organization="sopht"

function azureIdentities() {
  curl GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $(echo -n ":$SOPHT_AZURE_ACCESSTOKEN" | base64)" \
    "https://vssps.dev.azure.com/$sopht_azure_organization/_apis/identities?api-version=7.2-preview.1"
    # &searchFilter=MailAddress&filterValue=damien.amoury@sopht.com
    # "https://vssps.dev.azure.com/$sopht_azure_organization/_apis/graph/users/?api-version=7.2-preview.1"
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