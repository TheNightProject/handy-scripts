# Handy Scripts

A collection of useful shell scripts for repository maintenance and automation.

## Available Scripts

### git-cleanup-stale-branches.sh

A powerful script for cleaning up old and stale branches in GitHub repositories. It helps maintain repository hygiene by identifying and optionally removing branches that haven't been touched since a specified date.

#### Features
- Identifies branches older than a specified cutoff date
- Dry-run mode to preview changes before execution
- Protected branches (main, master, develop) are never deleted
- Colorized output for better visibility

#### Requirements
- GitHub CLI (`gh`) installed and authenticated

#### Usage
```bash
./git-cleanup-stale-branches.sh -o <org> -r <repo> [-f] [-d YYYY-MM-DD]
```

Options:
- `-o <org>`: GitHub organization name (required)
- `-r <repo>`: Repository name (required)
- `-f`: Force delete branches (without this flag, runs in dry-run mode)
- `-d YYYY-MM-DD`: Cutoff date (default: 2024-01-01)

#### Examples
```bash
# Dry run showing branches older than 2024-01-01
./git-cleanup-stale-branches.sh -o TheNightProject -r handy-scripts

# Delete branches older than 2023-06-01
./git-cleanup-stale-branches.sh -o TheNightProject -r handy-scripts -f -d 2023-06-01
