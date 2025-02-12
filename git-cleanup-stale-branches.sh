#!/bin/bash

# cleanup-gh-branches.sh
#
# Description:
#   Cleans up old/stale branches in a GitHub repository by identifying and optionally
#   deleting branches that haven't been touched since a specified cutoff date.
#
# Usage:
#   ./cleanup-gh-branches.sh -o <org> -r <repo> [-f] [-d YYYY-MM-DD]
#
# Options:
#   -o <org>         GitHub organization name (required)
#   -r <repo>        Repository name (required)
#   -f               Force delete branches (without this flag, runs in dry-run mode)
#   -d YYYY-MM-DD    Cutoff date (default: 2024-01-01)
#
# Examples:
#   # Dry run for TheNightProject/handy-scripts showing branches older than 2024-01-01
#   ./cleanup-gh-branches.sh -o TheNightProject -r handy-scripts
#
#   # Actually delete branches older than 2023-06-01
#   ./cleanup-gh-branches.sh -o TheNightProject -r handy-scripts -f -d 2023-06-01
#
# Notes:
#   - Requires GitHub CLI (gh) to be installed and authenticated
#   - Protected branches (main, master, develop) are never deleted
#   - Always runs in dry-run mode unless -f flag is specified

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
FORCE_DELETE=false
CUTOFF_DATE="2024-01-01"
ORG=""
REPO=""

# Parse command line arguments
while getopts "o:r:fd:" opt; do
  case $opt in
    o) ORG="$OPTARG" ;;
    r) REPO="$OPTARG" ;;
    f) FORCE_DELETE=true ;;
    d) CUTOFF_DATE="$OPTARG" ;;
    \?) echo -e "${RED}Usage: $0 -o <org> -r <repo> [-f] [-d YYYY-MM-DD]${NC}" >&2
        exit 1 ;;
  esac
done

# Validate required parameters
if [ -z "$ORG" ] || [ -z "$REPO" ]; then
    echo -e "${RED}Error: Organization (-o) and repository (-r) are required${NC}" >&2
    echo -e "Usage: $0 -o <org> -r <repo> [-f] [-d YYYY-MM-DD]" >&2
    exit 1
fi

# Validate date format
if ! [[ $CUTOFF_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${RED}Error: Invalid date format. Use YYYY-MM-DD${NC}" >&2
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it first: https://cli.github.com/"
    exit 1
fi

# Check if authenticated with gh
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Please run 'gh auth login' first"
    exit 1
fi

echo -e "${GREEN}Fetching repository branches...${NC}"

# Get all branches first
ALL_BRANCHES=$(gh api \
  -X GET \
  "/repos/$ORG/$REPO/branches" \
  --paginate \
  --jq '.[] | .name')

TOTAL_BRANCHES=$(echo "$ALL_BRANCHES" | wc -l | tr -d ' ')

echo -e "${GREEN}Total branches in repository: ${YELLOW}$TOTAL_BRANCHES${NC}"
echo -e "${GREEN}Checking for inactive branches...${NC}"
echo -e "${YELLOW}Debug: Looking for branches not touched since $CUTOFF_DATE${NC}"

OLD_BRANCHES=""
while IFS= read -r branch; do
    if [ -n "$branch" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ] && [ "$branch" != "develop" ]; then
        # Get the last commit date for this branch
        LAST_COMMIT_DATE=$(gh api \
            -X GET \
            "/repos/$ORG/$REPO/commits/$branch" \
            --jq '.commit.author.date' 2>/dev/null || echo "error")
        
        if [ "$LAST_COMMIT_DATE" != "error" ]; then
            COMMIT_DATE=${LAST_COMMIT_DATE:0:10}  # Extract YYYY-MM-DD
            if [[ "$COMMIT_DATE" < "$CUTOFF_DATE" ]]; then
                OLD_BRANCHES+="$branch"$'\n'
                echo -e "${YELLOW}Debug: Branch $branch last commit: $LAST_COMMIT_DATE${NC}"
            fi
        fi
    fi
done <<< "$ALL_BRANCHES"

# Count old branches to be deleted
OLD_BRANCH_COUNT=$(echo "$OLD_BRANCHES" | grep -v '^$' | wc -l | tr -d ' ')
echo -e "${GREEN}Found ${YELLOW}$OLD_BRANCH_COUNT${GREEN} inactive branches (not touched since $CUTOFF_DATE)${NC}"
if [ $OLD_BRANCH_COUNT -gt 0 ]; then
    echo -e "${GREEN}This represents ${YELLOW}$(($OLD_BRANCH_COUNT * 100 / $TOTAL_BRANCHES))%${GREEN} of total branches${NC}"
fi

if [ "$FORCE_DELETE" = false ]; then
  if [ $OLD_BRANCH_COUNT -gt 0 ]; then
    echo -e "\n${YELLOW}DRY RUN: The following branches would be deleted (use -f to perform actual deletion):${NC}"
    echo "$OLD_BRANCHES" | while read -r branch; do
      if [ -n "$branch" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ] && [ "$branch" != "develop" ]; then
        echo -e "${GREEN}[DRY RUN] Would delete:${NC} $branch"
      fi
    done
  fi
  exit 0
fi

# If we get here, we're in force delete mode
if [ $OLD_BRANCH_COUNT -eq 0 ]; then
    echo -e "${GREEN}No old branches to delete.${NC}"
    exit 0
fi

echo -e "\n${RED}WARNING: About to perform actual branch deletion!${NC}"
echo -e "${RED}This action cannot be undone!${NC}"
read -p "Do you want to proceed with deletion? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${YELLOW}Aborting...${NC}"
    exit 1
fi

# Process each branch
DELETED=0
ERRORS=0
while read -r branch; do
  if [ -n "$branch" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ] && [ "$branch" != "develop" ]; then
    echo -e "${YELLOW}Deleting branch:${NC} $branch"
    if gh api \
      -X DELETE \
      "/repos/$ORG/$REPO/git/refs/heads/$branch" &> /dev/null; then
      ((DELETED++))
      echo -e "${GREEN}Progress: $DELETED/$OLD_BRANCH_COUNT branches deleted${NC}"
    else
      ((ERRORS++))
      echo -e "${RED}Error deleting branch: $branch${NC}"
    fi
  fi
done <<< "$OLD_BRANCHES"

echo -e "\n${GREEN}Cleanup complete:${NC}"
echo -e "- ${GREEN}Successfully deleted:${NC} $DELETED branches"
if [ $ERRORS -gt 0 ]; then
  echo -e "- ${RED}Failed to delete:${NC} $ERRORS branches"
fi
