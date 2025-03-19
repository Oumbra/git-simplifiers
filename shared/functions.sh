#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/constantes.sh"

function isJson() {
  local maybeJson=$1

  if [[ -f "$maybeJson" ]]; then
    jq -e '.' "$maybeJson" >/dev/null 2>&1
  else
    echo "$maybeJson" | jq -e >/dev/null 2>&1
  fi

  if [[ $? -gt 0 ]]; then
    echo 1
    return 1
  else
    echo 0
    return 0
  fi
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
    jq -c '.' ~/.git-simplifier.conf
  else
    echo -e "${redColor}Cannot found configuration file ~/.git-simplifier.conf !${resetColor}"
    return 1
  fi
}

function getConfigValue() {
  local jsonPath="$1"
  if [[ -z "$jsonPath" ]]; then
    echo -e "${redColor}getConfigValue command need json path to work !${resetColor}"
    return 1
  fi
  
  local config
  config=$( readLocalConfig; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
    echo -e "${redColor}$config${resetColor}"
    return $cmdState
  fi
  
  local value=$( echo $config | jq -r "$jsonPath" )
  if [[ -z "$value" || "$value" == "null" || "$value" == "" ]]; then
    echo -e "${redColor}$jsonPath not found ! Please configure it in ~/.git-simplifier.conf${resetColor}"
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
    echo -e "${redColor}$email${resetColor}"
    return $cmdState
  fi

  if [[ $(echo "$email" | perl -ne '$count++ if /^[\w\-\.]+@(?:[\w-]+\.)+[\w-]{2,}$/; END { print $count || 0 }') == 0 ]]; then
      echo -e "${redColor}Configured email is not conform to the email format!${resetColor}"
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