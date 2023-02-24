#!/bin/bash

path_to_project=$1
owner=$2
repo=$3
base_branch=$4
pr_branch=$5

log_prefix=$repo
green_checkmark='\xe2\x9c\x85'
cross_mark='\xe2\x9d\x8c'
party_popper='\xf0\x9f\x8e\x89'

# Check that required arguments have been specified
[[ -z "$path_to_project" ]] && { echo "Path to project was not specified"; exit 1; }
[[ -z "$owner" ]] && { echo "Repository owner was not specified"; exit 1; }
[[ -z "$repo" ]] && { echo "Repository was not specified"; exit 1; }
[[ -z "$base_branch" ]] && { echo "Base branch was not specified"; exit 1; }
[[ -z "$pr_branch" ]] && { echo "PR branch was not specified"; exit 1; }

# Check that GitHub cli is installed
command -v gh &> /dev/null || { echo "GitHub cli is not installed"; exit 1; }

# Navigate inside the project
cd "$path_to_project" &> /dev/null || { echo "Directory $path_to_project was not found"; exit 1; }

echo "[$log_prefix] Running for branch: $pr_branch"; echo;

# Fetch pipeline state (success, pending, failure) and exit if it has failed
pipeline_state=$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/"$owner"/"$repo"/commits/"$pr_branch"/status --jq '.state')
if [ "$pipeline_state" = "failure" ]; then
  echo -e "[$log_prefix] $cross_mark Pipeline has failed for $pr_branch. Please resolve any issues."; echo;
  [[ $(uname) = "Darwin" ]] && { osascript -e 'display notification "['"$log_prefix"'] Pipeline has failed for '"$pr_branch"'. Please resolve any issues." with title "merge-it"'; }
  exit 0
fi

# Fetch PR number
# GitHub's PR search endpoint (https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28#list-pull-requests) could not be relied upon, since it returned non-unique results, even when searching for a specific branch
# So until a better solution is found, we resort to this workaround
pr_number=$(echo $(gh pr list --state all --search head:"$pr_branch") | cut -f1 -d " ")

# Fetch PR state (open/closed)
# https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28#get-a-pull-request
pr_state=$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/"$owner"/"$repo"/pulls/"$pr_number" --jq '.state')

# Remove slashes from branch name in order to be able to use it in the worktree directory name
pr_branch_suffix=$(echo "$pr_branch" | awk -F/ '{print $NF}')
worktree=".mergeit_${repo}_${pr_branch_suffix}"
path_to_worktree="$path_to_project"/../"$worktree"

# If the PR is open and the worktree doesn't exist, it means that the script is running for the first time
if [ "$pr_state" = "open" ] && [ ! -d "$path_to_worktree" ]; then
  # Create worktree and navigate inside it
  # A worktree is used in order to not interfere with the user's current working copy
  # https://stackoverflow.com/questions/4913360/can-i-rebase-a-git-branch-without-modifying-my-working-copy
  echo "[$log_prefix] Creating git worktree in $path_to_worktree"; echo;
  git worktree add --detach ../"$worktree" "$pr_branch" && cd "$path_to_worktree"

  # Enable auto-merge for the PR
  # https://cli.github.com/manual/gh_pr_merge
  echo "[$log_prefix] Enabling auto-merge for branch: $pr_branch"; echo;
  gh pr merge "$pr_branch" --auto --merge
fi

# Navigate inside the worktree
cd "$path_to_worktree" || exit

# If the PR state is closed (i.e. PR has been merged or closed) but the worktree still exists, remove it
if [ "$pr_state" = "closed" ]; then
  if [ -d "$path_to_worktree" ]; then
    echo "[$log_prefix] Removing worktree: $worktree for branch: $pr_branch"; echo;
    git worktree remove -f "$worktree"
    echo -e "[$log_prefix] $party_popper $pr_branch was successfully merged into $base_branch"; echo;
    [[ $(uname) = "Darwin" ]] && { osascript -e 'display notification "['"$log_prefix"'] '"$pr_branch"' was successfully merged into '"$base_branch"'!" with title "merge-it"'; }
    exit 0
  fi
  
  echo "[$log_prefix] Branch $pr_branch has already been merged, nothing to do"; echo;
  exit 0
fi

# Fetch branch_status (diverged, ahead, behind, identical) and number of commits left behind
# https://docs.github.com/en/rest/commits/commits#compare-two-commits
read -r -d "\n" branch_status behind_by < <(gh api -H "Accept: application/vnd.github+json" /repos/"$owner"/"$repo"/compare/"$base_branch"..."$pr_branch" --jq '.status, .behind_by')

# If our branch is ahead of base branch, then there is nothing to do, exit
# Either condition should be enough, but checking both nonetheless
if [ "$branch_status" = "ahead" ] && [ "$behind_by" -eq 0 ]; then
  echo "[$log_prefix] Branch $pr_branch is ahead of $base_branch, nothing to do"; echo;
  exit 0
fi

# Rebase and push branch
echo "[$log_prefix] Branch $pr_branch is out-of-date with $base_branch, rebasing..."; echo;
git checkout --detach "$pr_branch"
git pull --rebase origin "$pr_branch"
git fetch --all
git rebase origin/"$base_branch"
if [ $? -ne 0 ]; then
  echo -e "[$log_prefix] $cross_mark Merge conflict in $pr_branch, aborting..."; echo;
  [[ $(uname) = "Darwin" ]] && { osascript -e 'display notification "['"$log_prefix"'] Merge conflict in '"$pr_branch"'. Please resolve any issues." with title "merge-it"'; }
  git rebase --abort
  exit 0
fi
git push origin HEAD:"$pr_branch" --force-with-lease
echo -e "[$log_prefix] $green_checkmark Successfully rebased branch: $pr_branch"; echo;
[[ $(uname) = "Darwin" ]] && { osascript -e 'display notification "['"$log_prefix"'] '"$pr_branch"' was out-of-date and was successfully rebased!" with title "merge-it"'; }
