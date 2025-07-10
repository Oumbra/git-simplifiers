#!/bin/bash

git_script_dir=$(dirname "${BASH_SOURCE:-$0}")

source "$git_script_dir/scripts/shared/constantes.sh"
source "$git_script_dir/scripts/git-aliases.sh"
source "$git_script_dir/scripts/git-aliases-fn.sh"

# Git Cherry Pick Branch Environment
function gcpbe() {
  function gcpbeHelp() {
    echo -e "gcpbe [OPTIONS...]\n
    Options:
    -w, --workitem-id                  Set Azure workitem id (mandatory)
    -c, --commit-sha                   Set commitSHA to cherry pick (mandatory)
    -e, --env [develop|staging|main]   Set ENABLE_ENVIRONMENTS of branch (mandatory). One or two ENABLE_ENVIRONMENTS, separated by comma, where create branch (develop | staging | main)
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
          writeErrorLog "$2 is not a valid branch name !"
          return
        fi
        local commitSHA=$2
        shift 2 # past argument and value
        ;;
      -e|--env)
        local envs=( $(echo "$2" | tr ',' ' ') )
        for env in ${envs[@]}; do
          if [[ ! " ${ENABLE_ENVIRONMENTS[@]} " =~ " $env " ]]; then
            writeErrorLog "$2 is not a valid environment name ! (${ENABLE_ENVIRONMENTS[@]})"
            return
          fi
        done
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local techArg="--tech"
        shift # past argument
        ;;
      -w|--workitem-id)
        if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
          writeErrorLog "$2 is not workitem id !"
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
        writeErrorLog "Unknown option $1 !"
        return
        ;;
    esac
  done

  if [[ -z "$envs" ]]; then writeErrorLog "Environnments is mandatory !"; return; fi
  if [[ -z "$workitemId" ]]; then writeErrorLog "Workitem id is mandatory !"; return; fi
  if [[ -z "$commitSHA" ]]; then writeErrorLog "Commit SHA is mandatory !"; return; fi


  for env in ${envs[@]}; do
    echo -e "${CYAN_COLOR}## Env: $env${RESET_COLOR}"
    local workitem=$(azureWorkItem.sh $workitemId -s)
    local branchName=$(branchName.sh -w "$workitem" -e $env ${techArg:-})

    git brd $env &> /dev/null

    echo -e "${CYAN_COLOR}Going to branch $env...${RESET_COLOR}"
    git checkout -q $env && git pull -q && git fetch -q

    echo -e "${CYAN_COLOR}Creating branch $branchName...${RESET_COLOR}"
    git checkout -q -b $branchName

    echo -e "${CYAN_COLOR}Cherry picking...${RESET_COLOR}"
    git cherry-pick $commitSHA > /dev/null 2>&1

    # check if cp has conflit
    if git status | grep -q "Unmerged paths"; then
      writeErrorLog "There are merge conflicts. Please resolve them, then gcpc and gp"
      return
    fi

    local remoteBranchExists=$(git ls-remote --heads origin $branchName)
    echo -e "${CYAN_COLOR}Pushing branch $branchName...${RESET_COLOR}"
    if [[ -z "$remoteBranchExists" ]]; then 
      git push -q --set-upstream origin "$branchName"
    else
      git push -q --force origin "$branchName"
    fi
    
    if [[ "${buildPullRequest:-false}" == true ]]; then
      echo -e "${CYAN_COLOR}Building pull request on $env...${RESET_COLOR}"
      azureCreatePullRequest.sh -e "$env" -w $workitem
    fi
    echo ""
  done
}