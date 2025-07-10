#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/constantes.sh"

function writeLog() {
  echo -e "[${FUNCNAME[1]}] $@" >> ~/git-simplifiers.log
}

function writeErrorLog() {
  echo -e "${RED_COLOR}$@${RESET_COLOR}"
  echo -e "[${FUNCNAME[1]}] $@" >> ~/git-simplifiers.log
}

function jqAlias() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then writeErrorLog "Need arguments !"; return 1; fi

  local input="$1"
  shift

  if [[ -f "$input" ]]; then
    jq "$@" "$input"
  else
    jq "$@" <<< "$input"
  fi
}

function isJson() {
  local maybeJson="$1"

  if [[ -n $(jqAlias "$maybeJson" 'type' 2>/dev/null) ]]; then
    echo 0
    return 0
  else
    echo 1
    return 1
  fi
}

function isFile() {
  if [[ -f "$1" ]]; then
    echo 0
    return 0
  else
    echo 1
    return 1
  fi
}

function checkJsonStructure() {
  writeLog "$# inputs: $@"

  local json="$1"
  readarray -t expectKeys < <(awk '{$1=$1;print}' <<< $(jqAlias "$2" -r '.[]'))

  if [[ $( isJson "$json" ) == 1 ]]; then
    writeLog "checkJsonStructure() is not a valid JSON!\n$json"
    echo 1
    return 1
  fi

  local jsonKeys=$( jqAlias "$json" -r 'keys | .[]' )
  readarray -t jsonKeys < <(awk '{$1=$1;print}' <<< $jsonKeys)

  local diff=$( comm -3 <(printf "%s\n" "${jsonKeys[@]}" | sort) <(printf "%s\n" "${expectKeys[@]}" | sort)  )
  if [[ -z "$diff" ]]; then 
    echo 0
    return 0
  fi
  
  writeLog "Miss properties:\n$diff"
  echo 1
  return 1
}

function elapsedTime() {
  writeLog "$# inputs: $@"
  
  local dateStart="$1"
  local dateEnd=$(date +%s%3N)
  local diff=$((dateEnd - dateStart))

  local hours=$((diff / 3600000))
  local minutes=$(((diff % 3600000) / 60000))
  local seconds=$(((diff % 60000) / 1000))
  local millis=$((diff % 1000))

  local output=()
  ((hours > 0)) && output+=("${hours}h")
  ((minutes > 0)) && output+=("${minutes}m")
  ((seconds > 0)) && output+=("${seconds}s")
  ((millis > 0)) && output+=("${millis}ms")

  echo "${output[@]:0:2}"
}

function randomAlphaNumeric() {
  if [[ $# -gt 0 && $(echo "$1" | grep -Ec '^[0-9]+$') == 1 ]]; then
    local length=$1
  else
    local length=40
  fi

  cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c $length
}

function needToCallHelpFunction() {
  if [[ $# == 0 ]]; then
    echo 1
    return 1
  fi

  needToCallHelpFunctionWithoutArgs
}

function needToCallHelpFunctionWithoutArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      echo 1
      return 1
      ;;
    * | -* | --*) shift ;;
    esac
  done

  echo 0
  return 0
}

function readLocalConfig() {
  if [[ -f ~/.git-simplifier.conf ]]; then
    jqAlias ~/.git-simplifier.conf -c '.'
  else
    writeErrorLog "Cannot found configuration file ~/.git-simplifier.conf !"
    return 1
  fi
}

function getConfigValue() {
  local jsonPath="$1"
  if [[ -z "$jsonPath" ]]; then
    writeErrorLog "getConfigValue command need json path to work !"
    return 1
  fi
  
  local config
  config=$( readLocalConfig; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
    writeErrorLog "$config"
    return $cmdState
  fi
  
  local value=$( jqAlias "$config" -r "$jsonPath" )
  if [[ -z "$value" || "$value" == "null" || "$value" == "" ]]; then
    writeErrorLog "$jsonPath not found ! Please configure it in ~/.git-simplifier.conf"
    return 1
  fi

  echo $value
  return 0
}

function getUserEmail() {
  local email
  email=$( getConfigValue '.email'; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
    writeErrorLog "$email"
    return $cmdState
  fi

  if [[ $(echo "$email" | perl -ne '$count++ if /^[\w\-\.]+@(?:[\w-]+\.)+[\w-]{2,}$/; END { print $count || 0 }') == 0 ]]; then
      writeErrorLog "Configured email is not conform to the email format!"
      return 1
  fi

  echo $email
  return 0
}
function getAzureToken() {
  getConfigValue '.azure.token'
  return $?
}
function getAzureOrganizaton() {
  getConfigValue '.azure.organization'
  return $?
}
function getAzureProject() {
  getConfigValue '.azure.project'
  return $?
}
function getAzureRepository() {
  getConfigValue '.azure.repository'
  return $?
}
function getAzureRepositoryId() {
  getConfigValue '.azure.repositoryId'
  return $?
}

function getNotionVersion() {
  getConfigValue '.notion.version'
  return $?
}
function getNotionToken() {
  getConfigValue '.notion.token'
  return $?
}