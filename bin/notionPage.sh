#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function notionPage() {
    writeLog "inputs: $@"
    if [[ $(needToCallHelpFunction $@) == 1 ]]; then notionPageHelp; return; fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s|--standard)
            local standardArg="--standard"
            shift 1 # past argument
            ;;
        *|-*|--*)
            local isNotionUid=$(isNotionUid $1)
            local isNotionId=$(isNotionId $1)
            local isNotionUrl=$(isNotionUrl $1)
            if [[ $isNotionUid == 1 && $isNotionId == 1 && $isNotionUrl == 1 ]]; then
                writeErrorLog "notionPage need an uid, id or url parameter !"
                notionPageHelp
                return
            fi
            writeLog "isNotionUid: $isNotionUid, isNotionId: $isNotionId, isNotionUrl: $isNotionUrl !"
            local notionIdentifier="$1"
            shift 1 # past argument
            ;;
        esac
    done

    local dateStart=$(date +%s%3N)
    
    if [[ $isNotionId == 0 ]]; then 
        notionPageById "$notionIdentifier" ${standardArg:-}
    elif [[ $isNotionUrl == 0 ]]; then
        local pageUid=$(extractNotionUidFromUrl "$notionIdentifier")
        notionPageWithUid "$pageUid" ${standardArg:-}
    elif [[ $isNotionUid == 0 ]]; then
        notionPageWithUid "$notionIdentifier" ${standardArg:-}
    else
        writeErrorLog "Page uid is not conform to Notion page uid format!"
        return 1
    fi
    
    writeLog "finished in $(elapsedTime $dateStart)"
}

function notionPageWithUid() {
    writeLog "inputs: $@"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s|--standard)
            local standardArg="--standard"
            shift 1 # past argument
            ;;
        *|-*|--*)
            if [[ $(isNotionUid $1) == 1 ]]; then
                writeErrorLog "Need an uid parameter !"
                notionPageByIdHelp
                return
            fi
            local pageUid=$1
            shift 1 # past argument
            ;;
        esac
    done
    
    local responsePath=$(notionRestApi.sh "v1/pages/$pageUid")
    if [[ $(isJson "$responsePath") == 1 ]]; then
        writeErrorLog "Cannot recover page :\n$responsePath"
        return 1
    fi
    
    local pageNotExists=$(jqAlias "$responsePath" -e '.object == "error"')
    if [[ $pageNotExists == true ]]; then
        local responseMessage=$( jqAlias "$responsePath" -r '.message' )
        writeErrorLog "$message\n$responsePath"
        return 1
    fi

    if [[ -z $standardArg ]]; then
        echo $responsePath
    else
        notionPageFormatter $responsePath
    fi
}

function notionPageById() {
    writeLog "inputs: $@"

    if [[ $(needToCallHelpFunction $@) == 1 ]]; then notionPageByIdHelp; return; fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s|--standard)
            local standardArg="--standard"
            shift 1 # past argument
            ;;
        *|-*|--*)
            if [[ $(isNotionId $1) == 1 ]]; then
                writeErrorLog "notionPageById need an id parameter !"
                notionPageByIdHelp
                return
            fi
            local workitemId="$1"
            shift 1 # past argument
            ;;
        esac
    done

    local dateStart=$(date +%s%3N)

    notionPagesWithId $workitemId ${standardArg:-}

    writeLog "finished in $(elapsedTime $dateStart)"
}

function notionPagesWithId() {
    writeLog "inputs: $@"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s|--standard)
            local standardArg="--standard"
            shift 1 # past argument
            ;;
        -c|--cursor)
            local cursor="$2"
            shift 2 # past argument
            ;;
        *|-*|--*)
            if [[ $(isNotionId $1) == 1 ]]; then
                writeErrorLog "notionPageById need an id parameter !"
                notionPageByIdHelp
                return
            fi
            local workitemId="$1"
            shift 1 # past argument
            ;;
        esac
    done

    writeLog "workitemId: $workitemId, cursor: $cursor"
    
    local responsePath=$( notionPages "$cursor")
    if [[ $(isJson "$responsePath") == 1 ]]; then
        writeErrorLog "Cannot recover page :\n$responsePath"
        return 1
    fi
    
    local pageNotExists=$( jqAlias "$responsePath" -e '.object == "error"' )
    if [[ $pageNotExists == true ]]; then
        writeErrorLog $( jqAlias "$responsePath" -r '.message' )
        return 1
    fi

    local nextCursor=$( jqAlias "$responsePath" -r '.next_cursor' )
    local resultPage=$( notionPageFilter "$responsePath" $workitemId )
    local hasPageFound=0
    if [[ $(isJson "$resultPage") -eq 0 ]]; then
        hasPageFound=1
    fi

    if [[ $hasPageFound -gt 0 ]]; then
        if [[ -z $standardArg ]]; then
            echo $resultPage
        else
            notionPageFormatter "$resultPage"
        fi
        return
    elif [[ $hasPageFound -eq 0 && -n "$nextCursor" && "$nextCursor" != "null" ]]; then
        notionPagesWithId "$workitemId" --cursor "$nextCursor" ${standardArg:-}
        return
    fi

    writeErrorLog "No result was found for $workitemId"
}

function notionPageByUrl() {
    writeLog "inputs: $@"

    if [[ $(needToCallHelpFunction $@) == 1 ]]; then notionPageByUrlHelp; return; fi
    if [[ $(isNotionUrl $1) == 1 ]]; then
        writeErrorLog "Need an URL parameter !"
        notionPageByUrlHelp
        return
    fi

    local dateStart=$(date +%s%3N)

    local pageUid=$(extractNotionUidFromUrl $1)
    notionPage $pageUid

    writeLog "finished in $(elapsedTime $dateStart)"
}

function notionPages() {
    local cursor=$1
    local searchBody=$(
        jq -c -n \
            --arg cursor "$cursor" \
            '{
                "query":"",
                "filter": { "value": "page", "property": "object" },
                "sort":{ "direction":"descending", "timestamp":"last_edited_time" },
            } + (if $cursor != "" then { "start_cursor": $cursor } else {} end)'
    )
    
    writeLog "cursor: $cursor, filePath: $filePath"

    notionRestApi.sh "v1/search" $searchBody
}

function notionPageFilter() {
    local outputFile="/tmp/$(randomAlphaNumeric)"
    local jqFilter='.results[] |
        select(.properties.ID != null) |
        select(.properties.ID.unique_id.prefix != "INIT") |
        select(.properties.ID.unique_id.number == $id)'
    
    local inputFile=$1
    local isPrefixedId=$(echo "$2" | grep -Ec '^(TASK|SUP|DT)-[0-9]+$')
    if [[ $isPrefixedId == 1 ]]; then
        local workitemId=${2#*-}
        local workitemPrefix=${2%-*}
        jqFilter+=' | select(.properties.ID.unique_id.prefix == $prefix)'
    else 
        local workitemId=$2
    fi

    writeLog "workitemId: $workitemId, workitemPrefix: ${workitemPrefix:-null}, inputFile: $inputFile, outputFile: $outputFile"

    # .properties.ID.unique_id.prefix == $prefix
    jq -c \
        --argjson id "$workitemId" \
        --arg prefix "$workitemPrefix" \
        "$jqFilter" \
        $inputFile > $outputFile
    
    echo "$outputFile"
}

function isNotionUid() {
    writeLog "isNotionUid() $@"

    if [[ $(needToCallHelpFunction $@) == 1 ]]; then 
        writeErrorLog "isNotionUid need an uid parameter !"
        return
    fi

    local isFormatedUid=$(echo "$1" | grep -Ec '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$')
    local isCompressUid=$(echo "$1" | grep -Ec '^\w{32}$')

    if [[ $isFormatedUid == 1 || $isCompressUid == 1 ]]; then
        echo 0
        return 0
    else
        echo 1
        return 1
    fi
}

function isNotionId() {
    writeLog "isNotionId() $@"

    if [[ $(needToCallHelpFunction $@) == 1 ]]; then 
        writeErrorLog "isNotionId need a parameter !"
        return
    fi

    local isId=$(echo "$1" | grep -Ec '^[0-9]+$')
    local isPrefixedId=$(echo "$1" | grep -Ec '^(TASK|SUP|DT)-[0-9]+$')

    if [[ $isId == 1 || $isPrefixedId == 1 ]]; then
        echo 0
        return 0
    else
        echo 1
        return 1
    fi
}

function isNotionUrl() {
    writeLog "isNotionUrl() $@"

    if [[ $(needToCallHelpFunction $@) == 1 ]]; then 
        writeErrorLog "isNotionUrl need a url parameter !"
        return
    fi

    if [[ $(echo "$1" | grep -Ec '^https:\/\/www.notion.so\/.*\w{32}(?:\?.+)?$') == 1 ]]; then
        echo 0
        return 0
    else
        echo 1
        return 1
    fi
}

function extractNotionUidFromUrl() {
    writeLog "extractNotionUidFromUrl() $@"
    echo $1 | sed -nE 's/https:\/\/www.notion.so\/.*(\w{8})(\w{4})(\w{4})(\w{4})(\w{12})(\?.+)?$/\1-\2-\3-\4-\5/p' 
}

function notionPageFormatter() {
    local inputFile=$1
    
    writeLog "inputFile: $inputFile"

    jqAlias $inputFile -c \
        '{
            id: .properties.ID.unique_id.number,
            state: .properties.Status.status.name,
            title: .properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text,
            type: (if .properties.ID.unique_id.prefix == "DT" then "Delivery" elif .properties.ID.unique_id.prefix == "SUP" then "Bug" elif .properties.ID.unique_id.prefix == "INIT" then "Issue" elif .properties.Type.select != null then .properties.Type.select.name else "Tech" end),
            link: .url
        }'
}

function notionPageHelp() {
    echo -e "
Usage: notionPage [PageUid | PageUrl | TaskId]
Return path of file containing page json

Commands:
    -h, --help                         Displays this help and exists
Examples:
    notionPage 1eb0aff8-095c-807b-9e1f-df8fc3810043
    notionPage 1eb0aff8095c807b9e1fdf8fc3810043
    notionPage https://www.notion.so/sopht/ETQ-Keolis-SA-je-vois-mes-donn-es-VMware-dans-On-Prem-1eb0aff8095c807b9e1fdf8fc3810043
    notionPage 223 // return first object with id 223
    notionPage SUP-223
"
}

function notionPageByIdHelp() {
    echo -e "
Usage: notionPageById NotionId
Return path of file containing page json

Commands:
    -h, --help                         Displays this help and exists
Examples:
    notionPageById 719
"
}

function notionPageByUrlHelp() {
    echo -e "
Usage: notionPageByUrl NotionUrl
Return path of file containing page json

Commands:
    -h, --help                         Displays this help and exists
Examples:
    notionPageByUrl https://www.notion.so/sopht/ETQ-Keolis-SA-je-vois-mes-donn-es-VMware-dans-On-Prem-1eb0aff8095c807b9e1fdf8fc3810043
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    notionPage "$@"
fi