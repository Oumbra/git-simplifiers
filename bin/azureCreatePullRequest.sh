#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

# https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests/create?view=azure-devops-rest-7.1&tabs=HTTP
function azureCreatePullRequest() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureCreatePullRequestHelp; return; fi

  local email
  email=$( getUserEmail; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$email"
      return $cmdState
  fi

  local organization
  organization=$( getAzureOrganizaton; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$organization"
      return $cmdState
  fi

  local project
  project=$( getAzureProject; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$project"
      return $cmdState
  fi

  local repository
  repository=$( getAzureRepository; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$repository"
      return $cmdState
  fi

  local repositoryId
  repositoryId=$( getAzureRepositoryId; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$repositoryId"
      return $cmdState
  fi

  local commandArgs="$@"
  local commandArgsCount="$#"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--source)
        if [[ $(echo "$2" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[a-z0-9_\-]+$') == 0 ]]; then
          echo -e "${redColor}$2 is not a valid branch name !${resetColor}"
          return
        fi
        local source=$2
        shift 2 # past argument and value
        ;;
      -t|--target)
        if [[ $(echo "$2" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[a-z0-9_\-]+$') == 0 ]]; then
          echo -e "${redColor}$2 is not a valid branch name !${resetColor}"
          return
        fi
        local target=$2
        shift 2 # past argument and value
        ;;
      -e|--env)
        if [[ ! " ${environments[@]} " =~ " $2 " ]]; then
          echo -e "${redColor}$2 is not a valid environment name ! (${environments[@]})${resetColor}"
          return
        fi
        local env=$2
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -i|--in-place)
        local isInPlace=true
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
      --workitem)
        if [[ $(isJson "$2") == 1 ]]; then
          echo -e "${redColor}Workitem is not a valid JSON: $2${resetColor}"
          return
        fi
        local workitem=$2
        shift 2 # past argument and value
        ;;
      *|-*|--*)
        echo -e "${redColor}Unknown option $1 !${resetColor}"
        return
        ;;
    esac
  done
  
  echo -e "${cyanColor}Checking parameters...${resetColor}" 

  local env="$env"
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi

  if [[ "$isInPlace" == true ]]; then
    # recover current branch name
    local source=$(git symbolic-ref --short HEAD)
    # recover workitem id if possible
    if [[ $(echo "$source" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[0-9]+(-[a-z]*)?$') == 1 ]]; then
      local workitemId=$(echo "$source" | perl -lne 'print $1 if /[a-z]{1,3}\/[a-z]{3}\/([0-9]+)(-[a-z]*)?/')
    fi
    # eval env if possible else develop
    local env=${env:-develop}
    for _env in "${environments[@]}"; do
      local countBranchInEnv=$(git branch --contains $_env 2> /dev/null | fgrep -cw "$source")
      if [[ $countBranchInEnv -eq 1 ]]; then
        local env="$_env"
        break
      fi
    done
  fi

  if [[ -z $source && -z "$workitem" && -z "$workitemId" ]]; then
    echo -e "${redColor}azureCreatePullRequest function need a source branch or a workitem id or workitem !${resetColor}"
    return
  fi
  
  if [[ -z $target && -z $env ]]; then
    echo -e "${redColor}azureCreatePullRequest function need a target branch or an environment !${resetColor}"
    return
  fi

  if [[ -n "$workitemId" ]]; then
      local workitem=$( azureWorkItem.sh $workitemId )
      if [[ $(isJson "$workitem") == 1 ]]; then
        echo -e "${redColor}${workitem}${resetColor}"
        return
      fi
  fi

  if [[ -n "$workitem" ]]; then 
    local branchName=$( azureBranchName.sh --workitem "$workitem" ${techArg:-} --env "$env" )
    local title=$( azureBranchNormalizedTitle.sh --workitem "$workitem" ${techArg:-} )
    # echo "\$commandArgsCount: $commandArgsCount, \$commandArgs: $commandArgs, \$env: $env, \$branchName: $branchName"
    if [[ -f "$workitem" ]]; then
      local workitemId=$( jq -r '.id' "$workitem" )
      local workitemUrl=$( jq -r '.url' "$workitem" )
    else
      local workitemId=$( echo $workitem | jq -r '.id' )
      local workitemUrl=$( echo $workitem | jq -r '.url' )
    fi
    local workItemRef=$(jq -c -n --arg workitemId "$workitemId" --arg workitemUrl "$workitemUrl" '[{ "id": $workitemId, "url": $workitemUrl }]')
  elif [[ -n "$source" ]]; then
    local title=$(git log -1 --pretty=%B)
  fi

  local sourceBranch="refs/heads/${source:-$branchName}"
  echo -e "${cyanColor}Checking remote source branch '$sourceBranch' exists...${resetColor}" 
  local remoteSourceBranchExists=$(git ls-remote --heads origin $sourceBranch)
  if [[ -z "$remoteSourceBranchExists" ]]; then 
    echo -e "${redColor}Source branch '${source:-$branchName}' not exists !${resetColor}"
    return
  fi

  local targetBranch="refs/heads/${target:-$env}"
  echo -e "${cyanColor}Checking remote target branch '$targetBranch' exists...${resetColor}" 
  local remoteTargetBranchExists=$(git ls-remote --heads origin $targetBranch)
  if [[ -z "$remoteTargetBranchExists" ]]; then 
    echo -e "${redColor}Target branch '${target:-$env}' not exists !${resetColor}"
    return
  fi

  #  TODO ADD identifierRef to autocomplete and reviewer
  local identityRef=$( azureUserIdentity.sh $email )

  echo -e "${cyanColor}Preparing pull request creation...${resetColor}" 
  # TODO trouvé un moyen de récupérer la liste des reviewers possible et de les rendre sélectionnable
  local jsonBody=$(
    jq -c -n \
    --arg title "$title" \
    --arg sourceBranch "$sourceBranch" \
    --arg targetBranch "$targetBranch" \
    --argjson workItemRef ${workItemRef:-'[]'} \
    --argjson identityRef "$identityRef" \
    '{
      "sourceRefName": $sourceBranch,
      "targetRefName": $targetBranch,
      "title": $title,
      "workItemRefs": $workItemRef,
      "autoCompleteSetBy": $identityRef,
      "reviewers": []
    }'
  )

  echo -e "${cyanColor}Creating pull request...${resetColor}" 
  local response=$( azureRestApi.sh "git/repositories/$repositoryId/pullRequests?api-version=7.1" "$jsonBody" )
  if [[ $(isJson "$response") == 1 ]]; then
    echo -e "${redColor}${response}${resetColor}"
    echo -e "${redColor}sended json :\n${jsonBody}${resetColor}"
    return
  fi

  local hasCreationError=$(jq -e 'has("message")' "$response")
  if [[ $hasCreationError == true ]]; then
    local message=$(jq -r '.message' "$response")
    echo -e "${redColor}${message}${resetColor}"
    echo -e "${redColor}sended json :\n${jsonBody}${resetColor}"
    return 1
  fi

  local pullRequestId=$(jq -r '.pullRequestId' "$response")
  local pullRequestUrl="https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$pullRequestId"
  echo -e "${greenColor}Pull request created: $pullRequestUrl${resetColor}"

  echo -e "${cyanColor}Clearing local branch '${source:-$branchName}'...${resetColor}" 
  git checkout -q develop && git pull -q && git fetch -q
  git branch -D "${source:-$branchName}" &> /dev/null
}


function azureCreatePullRequestHelp() {
  echo -e "
Usage: azureCreatePullRequest [OPTION...] [COMMAND]...
Create an azure pull request from two branch or a azure workitem

Options:
  -i, --in-place                     Set in place flag to eval source branch and target env
  -w, --workitem-id                  Set workitem id
  --workitem                         Set workitem object
  -s, --source                       Set source branch name
  -t, --target                       Set target branch name
  -e, --env [develop|staging|main]   Set environment of branch (default: develop)
  -t, --tech                         Set tech flag for branch name and commit name
Commands:
  -h, --help                         Displays this help and exists
Examples:
  azureCreatePullRequest -w 2783
  azureCreatePullRequest -w 2783 -t
  azureCreatePullRequest -w 2783 -e staging
  azureCreatePullRequest -s f/dam/2783 -t f/dam/2783-main
  azureCreatePullRequest -w 2783 -e main
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureCreatePullRequest $*
fi