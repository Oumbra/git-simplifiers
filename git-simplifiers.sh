#!/bin/bash

. /scripts/shared/constantes.sh
. /scripts/git-aliases.sh
. /scripts/git-alias-functions.sh
. /scripts/azure/git-azure.sh

# Git Cherry Pick Branch Environment
function gcpbe() {
  function gcpbeHelp() {
    echo -e "gcpbe [OPTIONS...]\n
    Options:
    -w, --workitem-id                  Set Azure workitem id (mandatory)
    -c, --commit-sha                   Set commitSHA to cherry pick (mandatory)
    -e, --env [develop|staging|main]   Set environments of branch (mandatory). One or two environments, separated by comma, where create branch (develop | staging | main)
    -pr, --pull-request                Create pull request for branch on specified environment
    -t, --tech                         Set tech flag for branch name and commit name"
  }

  if [[ $# == 0 || "$@" =~ "-h" ]]; then 
    gcpbeHelp
    return 
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--commit-sha)
        if [[ $(echo "${#2}") != 40 ]]; then
          echo -e "${redColor}$2 is not a valid branch name !${resetColor}"
          return
        fi
        local commitSHA=$2
        shift 2 # past argument and value
        ;;
      -e|--env)
        local envs=( $(echo "$2" | tr ',' ' ') )
        for env in ${envs[@]}; do
          if [[ ! " ${environments[@]} " =~ " $env " ]]; then
            echo -e "${redColor}$2 is not a valid environment name ! (${environments[@]})${resetColor}"
            return
          fi
        done
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -w|--workitem-id)
        if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
          echo -e "${redColor}$2 is not workitem id !${resetColor}"
          return
        fi
        local workitemId=$2
        shift 2 # past argument and value
        ;;
      -pr|--pull-resquest)
        local buildPullRequest=true
        shift # past argument
        ;;
      *|-*|--*)
        echo -e "${redColor}Unknown option $1 !${resetColor}"
        return
        ;;
    esac
  done

  if [[ -z "$envs" ]]; then echo -e "${redColor}Environnments is mandatory !${resetColor}"; return; fi
  if [[ -z "$workitemId" ]]; then echo -e "${redColor}Workitem id is mandatory !${resetColor}"; return; fi
  if [[ -z "$commitSHA" ]]; then echo -e "${redColor}Commit SHA is mandatory !${resetColor}"; return; fi

  if [[ "$isTechWork" == true ]]; then local techArg="--tech"; fi

  for env in ${envs[@]}; do
    echo -e "${cyanColor}## Env: $env${resetColor}"
    local branchName=$(azureBranchName -w $workitemId -e $env ${techArg:-})

    git brd $env &> /dev/null

    echo -e "${cyanColor}Going to branch $env...${resetColor}"
    git checkout -q $env && git pull -q && git fetch -q

    echo -e "${cyanColor}Creating branch $branchName...${resetColor}"
    git checkout -q -b $branchName

    echo -e "${cyanColor}Cherry picking...${resetColor}"
    git cherry-pick $commitSHA > /dev/null 2>&1

    # check if cp has conflit
    if git status | grep -q "Unmerged paths"; then
      echo -e "${redColor}There are merge conflicts. Please resolve them, then gcpc and gp${resetColor}"
      return
    fi

    echo -e "${cyanColor}Pushing branch $branchName...${resetColor}"
    git push -q --set-upstream origin "$branchName"
    
    if [[ "${buildPullRequest:-false}" == true ]]; then
      echo -e "${cyanColor}Building pull request on $env...${resetColor}"
      azureCreatePullRequest -e $env -w $workitemId
    fi
    echo ""
  done
}