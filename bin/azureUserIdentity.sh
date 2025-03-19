#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function azureUserIdentity() {
    if [[ $(needToCallHelpFunctionWithoutArgs $@) == 1 ]]; then azureUserIdentityHelp; return; fi

    local email=$1
    if [[ $(echo "$email" | perl -ne '$count++ if /^[\w\-\.]+@(?:[\w-]+\.)+[\w-]{2,}$/; END { print $count || 0 }') == 0 ]]; then
        echo -e "${redColor}The parameter does not conform to the email format!${resetColor}"
        return 1
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

    local identity=$(
        curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n ":$token" | base64)" \
        "https://vssps.dev.azure.com/$organization/_apis/identities?api-version=7.2-preview.1&searchFilter=MailAddress&filterValue=$email"
    )

    local id=$(echo $identity | jq -r '.value[0].id')
    local descriptor=$(echo $identity | jq -r '.value[0].subjectDescriptor')
    local displayName=$(echo $identity | jq -r '.value[0].providerDisplayName')

    echo "id: $id, descriptor: $descriptor, displayName: $displayName"

    jq -c -n \
        --arg id "$id" \
        --arg displayName "$displayName" \
        --arg uniqueName "$email" \
        --arg descriptor "$descriptor" \
        --arg imageUrl "https://dev.azure.com/$organization/_api/_common/identityImage?id=$id" \
        --arg url "https://vssps.dev.azure.com/$organization/_apis/Identities/$id" \
        --arg href "https://dev.azure.com/$organization/_apis/GraphProfile/MemberAvatars/$descriptor" \
        '{
            "id": $id,
            "displayName": $displayName,
            "uniqueName": $uniqueName,
            "descriptor": $descriptor,
            "imageUrl": $imageUrl,
            "url": $url,
            "_links": {
                "avatar": {
                    "href": $href
                }
            },
        }'
}

function azureUserIdentityHelp() {
    echo -e "
Usage: azureUserIdentity EMAIL
Return identity of user from email

Arguments:
    email                   User email, mandatory
Commands:
    -h, --help              Displays this help and exists
Examples:
    azureIdentities
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureUserIdentity $*
fi