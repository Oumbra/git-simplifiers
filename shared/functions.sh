#!/bin/bash

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
  if [[ $# -gt 0 &&  $(echo "$1" | grep -Ec '^[0-9]+$') == 1 ]]; then
    local length=$1
  else 
    local length=40
  fi

  cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c $length
}