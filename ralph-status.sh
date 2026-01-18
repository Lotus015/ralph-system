#!/usr/bin/env bash
# Ralph Status - Show current progress
# Displays story completion status and recent activity

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if prd.json exists
if [[ ! -f "prd.json" ]]; then
    echo -e "${RED}Error: prd.json not found${NC}"
    echo "Run ralph-init to set up a new project"
    exit 1
fi

# Validate prd.json
if ! jq empty prd.json 2>/dev/null; then
    echo -e "${RED}Error: prd.json is not valid JSON${NC}"
    exit 1
fi

# Get counts
total=$(jq '.userStories | length' prd.json)
completed=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json)
pending=$((total - completed))

# Get current iteration
iteration=0
if [[ -f ".ralph-state" ]]; then
    iteration=$(cat .ralph-state)
fi

# Get project info
project=$(jq -r '.project // "Unknown"' prd.json)
branch=$(jq -r '.branchName // "main"' prd.json)
description=$(jq -r '.description // "No description"' prd.json)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Project: ${GREEN}$project${NC}"
echo -e "Branch: $branch"
echo -e "Description: $description"
echo ""
echo -e "${BLUE}Progress:${NC} ${GREEN}$completed${NC}/${total} stories complete (${pending} pending)"
echo -e "Current iteration: ${YELLOW}$iteration${NC}"
echo ""

# Show story list with status
echo -e "${BLUE}Stories:${NC}"
jq -r '.userStories[] | "\(.id)|\(.title)|\(.passes)|\(.priority)"' prd.json | sort -t'|' -k4 -n | while IFS='|' read -r id title passes priority; do
    if [[ "$passes" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} [$id] $title"
    else
        echo -e "  ${YELLOW}○${NC} [$id] $title"
    fi
done

echo ""

# Show next story to be worked on
next_story=$(jq -r '.userStories | map(select(.passes == false)) | sort_by(.priority) | .[0] // empty' prd.json)
if [[ -n "$next_story" ]]; then
    next_id=$(echo "$next_story" | jq -r '.id')
    next_title=$(echo "$next_story" | jq -r '.title')
    echo -e "${BLUE}Next story:${NC} ${YELLOW}$next_id${NC} - $next_title"
    echo ""
fi

# Show last 10 lines from progress.txt
if [[ -f "progress.txt" ]] && [[ -s "progress.txt" ]]; then
    echo -e "${BLUE}Recent progress (last 10 lines):${NC}"
    echo -e "${BLUE}─────────────────────────────────${NC}"
    tail -10 progress.txt
    echo -e "${BLUE}─────────────────────────────────${NC}"
    echo ""
fi

# Show last 5 git commits
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${BLUE}Recent commits:${NC}"
    git log --oneline -5 2>/dev/null || echo "  No commits yet"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
