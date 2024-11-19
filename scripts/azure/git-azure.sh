#!/bin/bash

gitazure_script_dir=$(dirname "${BASH_SOURCE:-$0}")

# import shared constants and functions
source "$gitazure_script_dir/../shared/constantes.sh"
source "$gitazure_script_dir/../shared/functions.sh"

sopht_azure_organization="sopht"
sopht_azure_project="sopht"
sopht_azure_repository="monorepo"
sopht_azure_repository_id="79a2b0c0-14d8-4a0c-86ad-2bec24d9ccd5"

function azureRestApi() {
  local url=$1
  local jsonBody=$2

  if [[ -z $url ]]; then
    echo -e "${redColor}azureRestApi function need a url !${resetColor}"
    return
  fi

  if [[ -z "${SOPHT_AZURE_ACCESSTOKEN}" ]]; then
    echo -e "${redColor}Environnment variable SOPHT_AZURE_ACCESSTOKEN is undefined !${resetColor}"
    return
  fi

  if [[ -z "$jsonBody" ]]; then local method="GET"; else local method="POST"; fi

  local fullUrl="https://dev.azure.com/$sopht_azure_organization/$sopht_azure_project/_apis/$url"
  
  echo -e "fullUrl: $fullUrl\nmethod: $method\nBasic $(echo -n ":$SOPHT_AZURE_ACCESSTOKEN" | base64)\nbody: $jsonBody" > ~/git-utils.log

  curl -s -X $method \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $(echo -n ":$SOPHT_AZURE_ACCESSTOKEN" | base64)" \
    -d "${jsonBody:-}" \
    $fullUrl
}

function azureRepositoryId() {
  local repositoryName=$1
  if [[ -z $repositoryName ]]; then
    echo -e "${redColor}azureRepositoryId function need a repository name !${resetColor}"
    return
  fi

  # Appel de l'API pour lister les dépôts
  local response=$(azureRestApi "git/repositories?api-version=7.1-preview.1")

  echo "$response" | jq -r '.value[] | select(.name == "'$repositoryName'") | .id'
}

function azureWorkItem() {
  local workitemId=$1
  
  if [[ -z $workitemId ]]; then
    echo -e "${redColor}azureWorkItem function need a workitem id !${resetColor}"
    return
  fi

  local response=$(azureRestApi "wit/workitems/$workitemId?api-version=7.1-preview.3")
  if [[ $(isJson "$response") == 1 ]]; then
    echo -e "${redColor}Impossible to recover workitem #$workitemId :\n${response}${resetColor}"
    return 1
  fi

  local workitemNotExists=$(echo "$response" | jq -e 'has("message")' )
  if [[ $workitemNotExists == true ]]; then
    local message=$( echo $response | jq -r '.message' )
    echo -e "${redColor}${message}${resetColor}"
    return 1
  fi

  echo "$response"
}

# Not working now
# https://spsprodweu5.vssps.visualstudio.com/Ab95eb898-978a-4b51-8d3f-b3f69bdecc9f/_apis/Identities/88107802-59ba-608a-bccc-edbdc136922d
function azureIdentities() {
  curl GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $(echo -n ":$sopht_azure_accessToken" | base64)" \
    "https://vssps.dev.azure.com/$sopht_azure_organization/_apis/graph/users/?api-version=7.2-preview.1"
    # "https://dev.azure.com/$sopht_azure_organization/_apis/graph/descriptors/user?api-version=7.1-preview.3"
    # "https://dev.azure.com/$sopht_azure_organization/_apis/identities?api-version=7.2-preview.1"
}

function azureBranchName() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
  
  if [[ -z "$workitem" && -z "$workitemId" ]]; then
    echo -e "${redColor}azureBranchName function need a workitem id or workitem !${resetColor}"
    return
  fi

  if [[ -z "$workitem" ]]; then
    local workitem=$(azureWorkItem $workitemId)
    if [[ $(isJson "$workitem") == 1 ]]; then
      echo -e "${redColor}${workitem}${resetColor}"
      return
    fi
  fi
  
  local trigram=$(cd ~ && pwd | perl -pe 's/.*\/([^\/]{3}).*$/\L$1/g')
  local workitemType=$( echo $workitem | jq -r '.fields."System.WorkItemType"' )

  case "$workitemType" in
    "Bug") local branchType="fix";;
    *) 
      if [[ "${isTechWork:-false}" == true ]]; then local branchType="tech" 
      else local branchType="f"
      fi
    ;;
  esac

  local branchName="$branchType/$trigram/$workitemId"
  if [[ ! -z "$env" ]] && [[ "$env" != "develop" ]]; then local branchName="${branchName}-${env}"; fi

  echo $branchName
}

function azureBranchNormalizedTitle() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
  
  if [[ -z "$workitem" && -z "$workitemId" ]]; then
    echo -e "${redColor}azureBranchNormalizedTitle function need a workitem id or workitem !${resetColor}"
    return
  fi

  if [[ -z "$workitem" ]]; then
    local workitem=$(azureWorkItem $workitemId)
    if [[ $(isJson "$workitem") == 1 ]]; then
      echo -e "${redColor}${workitem}${resetColor}"
      return
    fi
  fi

  local workitemTitle=$( echo $workitem | jq -r '.fields."System.Title"' )
  local workitemType=$( echo $workitem | jq -r '.fields."System.WorkItemType"' )
  case "$workitemType" in
    "Bug") local commitType="Fix";;
    *) 
      if [[ "${isTechWork:-false}" == true ]]; then local commitType="Tech" 
      else local commitType="Feat"
      fi
    ;;
  esac

  echo "${commitType}: #${workitemId} ${workitemTitle}"
}

function gitCommit() {
  function gitCommitHelp() {
    echo -e "\nUsage: gitCommit [WORKITEM_ID] [OPTION...] [COMMAND]...\nCreate normalized commit from azure workitem\n\nOptions:\n\t-t, --tech                         Set tech flag for branch name and commit name\n\t-e, --env [develop|staging|main]   Set environment of branch (default: develop)\n\t-p, --push                         Push branch after commit created\n\t-pr, --pull-request                Create pull request for branch on specified environment\nCommands:\n\t-h, --help                         Displays this help and exists\nExamples:\n\tgitCommit 2783\n\tgitCommit 2783 -pr -e main"
  }
  if [[ $# == 0 || "$@" =~ "-h" ]]; then gitCommitHelp; return; fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
      -p|--push)
        local needPush=true
        shift # past argument
        ;;
      -pr|--pull-resquest)
        local needPush=true
        local buildPullRequest=true
        shift # past argument
        ;;
      *|-*|--*)
        if [[ $(echo "$1" | grep -Ec '^[0-9]+$') == 1 ]]; then 
          local workitemId=$1
          shift # past argument
        else
          echo -e "${redColor}Unknown option $1 !${resetColor}"
          return
        fi
        ;;
    esac
  done
  
  local env="${env:-develop}"

  if [[ -z $workitemId ]]; then
    echo -e "${redColor}gitCommit function need a workitem id !${resetColor}"
    return
  fi
  
  # recover ticket information on Azure
  echo -e "${cyanColor}Recover work item #${workitemId}${resetColor}" 
  local workitem=$(azureWorkItem $workitemId)
  if [[ $(isJson "$workitem") == 1 ]]; then
    echo -e "${redColor}${workitem}${resetColor}"
    return
  fi

  if [[ "$isTechWork" == true ]]; then local techArg="--tech"; fi

  local branchName=$(azureBranchName --workitem "$workitem" ${techArg:-} -e $env)
  local currentBranch=$(git symbolic-ref --short HEAD)

  if [[ "$currentBranch" != "$branchName" ]]; then
    echo -e "${cyanColor}Creating branch $branchName${resetColor}"
    git branch -D $env &> /dev/null
    git checkout -q $env && git pull -q && git fetch -q
    git checkout -q -b $branchName
  fi

  local commitMessage=$(azureBranchNormalizedTitle --workitem "$workitem" ${techArg:-})

  echo -e "${cyanColor}Creating commit $commitMessage${resetColor}"
  git add -A &> /dev/null
  git commit -q -m "$commitMessage"

  if [[ "${needPush:-false}" == true ]]; then
    # push or refresh remote branch
    echo -e "${cyanColor}Pushing branch $branchName${resetColor}"
    local remoteBranchExists=$(git ls-remote --heads origin refs/heads/${branchName})
    if [[ -z "$remoteBranchExists" ]]; then 
      git push -q --set-upstream origin "$branchName"
    else
      git push -q --force
    fi
  fi

  if [[ "${buildPullRequest:-false}" == true ]]; then
    echo -e "${cyanColor}Building pull request on $env${resetColor}"
    azureCreatePullRequest -e $env --workitem "$workitem"
  fi
}

# https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests/create?view=azure-devops-rest-7.1&tabs=HTTP
function azureCreatePullRequest() {
  function azureCreatePullRequestHelp() {
    echo -e "Usage: azureCreatePullRequest [OPTION...] [COMMAND]...\nCreate an azure pull request from two branch or a azure workitem\n\nOptions:\n\t-i, --in-place                     Set in place flag to eval source branch and target env\n\t-w, --workitem-id                  Set workitem id\n\t--workitem                         Set workitem object\n\t-s, --source                       Set source branch name\n\t-t, --target                       Set target branch name\n\t-e, --env [develop|staging|main]   Set environment of branch (default: develop)\n\t-t, --tech                         Set tech flag for branch name and commit name\nCommands:\n\t-h, --help                         Displays this help and exists\nExamples:\n\tazureCreatePullRequest -w 2783\n\tazureCreatePullRequest -w 2783 -t\n\tazureCreatePullRequest -w 2783 -e staging\n\tazureCreatePullRequest -s f/dam/2783 -t f/dam/2783-main\n\tazureCreatePullRequestHelp -w 2783 -e main"
  }
  if [[ $# == 0 || "$@" =~ "-h" ]]; then azureCreatePullRequestHelp; return; fi

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
        local env=$_env
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
      local workitem=$(azureWorkItem $workitemId)
      if [[ $(isJson "$workitem") == 1 ]]; then
        echo -e "${redColor}${workitem}${resetColor}"
        return
      fi
  fi

  if [[ -n "$workitem" ]]; then 
    local branchName=$(azureBranchName --workitem "$workitem" ${techArg:-} ${envArg:-})
    local workitemId=$( echo $workitem | jq -r '.id' )
    local workitemUrl=$( echo $workitem | jq -r '.url' )
    local workItemRef=$(jq -c -n --arg workitemId "$workitemId" --arg workitemUrl "$workitemUrl" '[{ "id": $workitemId, "url": $workitemUrl }]')
    local title=$(azureBranchNormalizedTitle --workitem "$workitem" ${techArg:-})
  elif [[ -n "$source" ]]; then
    local title=$(git log -1 --pretty=%B)
  fi

  echo -e "${cyanColor}Checking remote source branch exists...${resetColor}" 
  local sourceBranch="refs/heads/${source:-$branchName}"
  local remoteSourceBranchExists=$(git ls-remote --heads origin $sourceBranch)
  if [[ -z "$remoteSourceBranchExists" ]]; then 
    echo -e "${redColor}Source branch '${source:-$branchName}' not exists !${resetColor}"
    return
  fi

  echo -e "${cyanColor}Checking remote target branch exists...${resetColor}" 
  local targetBranch="refs/heads/${target:-$env}"
  local remoteTargetBranchExists=$(git ls-remote --heads origin $targetBranch)
  if [[ -z "$remoteTargetBranchExists" ]]; then 
    echo -e "${redColor}Target branch '${target:-$env}' not exists !${resetColor}"
    return
  fi

  echo -e "${cyanColor}Preparing pull request creation...${resetColor}" 
  # TODO trouvé un moyen de récupérer la liste des reviewers possible et de les rendre sélectionnable
  local jsonBody=$(
    jq -c -n \
    --arg title "$title" \
    --arg sourceBranch "$sourceBranch" \
    --arg targetBranch "$targetBranch" \
    --argjson workItemRef ${workItemRef:-'[]'} \
    '{
      "sourceRefName": $sourceBranch,
      "targetRefName": $targetBranch,
      "title": $title,
      "workItemRefs": $workItemRef,
      "reviewers": []
    }'
  )

  echo -e "${cyanColor}Creating pull request...${resetColor}" 
  local response=$(azureRestApi "git/repositories/$sopht_azure_repository_id/pullRequests?api-version=7.1" "$jsonBody")
  if [[ $(isJson "$response") == 1 ]]; then
    echo -e "${redColor}${response}${resetColor}"
    return
  fi

  local hasCreationError=$(echo "$response" | jq -e 'has("message")' )
  if [[ $hasCreationError == true ]]; then
    local message=$( echo $response | jq -r '.message' )
    echo -e "${redColor}${message}${resetColor}"
    return 1
  fi

  local pullRequestId=$(echo $response | jq -r '.pullRequestId')
  local pullRequestUrl="https://dev.azure.com/$sopht_azure_organization/$sopht_azure_project/_git/$sopht_azure_repository/pullrequest/$pullRequestId"
  echo -e "${greenColor}Pull request created: $pullRequestUrl${resetColor}"

  echo -e "${cyanColor}Clearing local branch '${source:-$branchName}'...${resetColor}" 
  git checkout -q develop && git pull -q && git fetch -q
  git branch -D "${source:-$branchName}" &> /dev/null
}