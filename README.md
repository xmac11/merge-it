# merge-it
Shell script to automatically rebase and merge your PRs when they are out-of-date

## Requirements
- [GitHub CLI](https://github.com/cli/cli#installation)
- Auto-merge must be allowed in the repository (See [here](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request))

## Getting Started
- **Clone this repository**
```bash
git clone https://github.com/xmac11/merge-it.git
```

- **Set the `GH_TOKEN` environment variable**

For example, if you are using `zsh`:

```bash
echo 'export GH_TOKEN=your-token' >> ~/.zprofile
```

- **Create a cron job**

Run:
```bash
crontab -e
```

and schedule the cron job. For example, if you are using `zsh` and you want to merge `feature-branch` into `develop` for a repository named `my-repo` owned by `my-company`:
```bash
* * * * * source ~/.zprofile; /path/to/script/merge_it.sh /path/to/repo my-company my-repo develop feature-branch >> /path/to/script/mergeit.log 2>&1
```

## Pop-up notifications (macOS)

#### Successful merge
<img width="342" alt="image" src="https://user-images.githubusercontent.com/55348322/222266830-d7737a25-088c-43ac-a138-3856b11661f9.png">

#### Successful rebase
<img width="344" alt="image" src="https://user-images.githubusercontent.com/55348322/222262816-fc4485ae-335d-42ae-8fa4-7304ac64e4ab.png">

#### Merge conflict
<img width="340" alt="image" src="https://user-images.githubusercontent.com/55348322/222266492-d53bc891-6232-43a2-b750-2570fe2243a3.png">

#### Failed pipeline
<img width="342" alt="image" src="https://user-images.githubusercontent.com/55348322/222262401-d0bdbbb4-fb7d-428d-a1f1-c73c6f092e0c.png">

## Notes
1. A PR must have been already opened manually.
2. A single PR must exist for a given branch.
3. The first time the script runs, it enables auto-merge. However, if you disable it, you will have to re-enable it manually.
4. When the branch is merged, running the script will do nothing. Nonetheless, you should remove the cron job. Ideally, this would be done automatically, and might be added in the future.

## Troubleshooting

1. (macOS) `Operation not permitted` when cron runs the script  
   Give `cron` Full Disc Access ([source](https://serverfault.com/questions/954586/osx-mojave-crontab-tmp-tmp-x-operation-not-permitted/1012212#1012212))


2. `gh: command not found` when cron runs the script  
   Make sure that GitHub CLI is installed and present in the `PATH` when the cron job runs.  
   For example, if the GitHub CLI was installed with `Homebrew` and you are using `zsh`:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 
```
