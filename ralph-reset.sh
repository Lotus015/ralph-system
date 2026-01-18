#!/usr/bin/env bash
# Ralph Reset - Reset state and progress
# Archives current progress and resets all stories to incomplete

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
    echo "Nothing to reset"
    exit 1
fi

# Validate prd.json
if ! jq empty prd.json 2>/dev/null; then
    echo -e "${RED}Error: prd.json is not valid JSON${NC}"
    exit 1
fi

# Show current progress summary
total=$(jq '.userStories | length' prd.json)
completed=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json)
iteration=0
if [[ -f ".ralph-state" ]]; then
    iteration=$(cat .ralph-state)
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Reset${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Current state:"
echo -e "  Stories: ${GREEN}$completed${NC}/${total} complete"
echo -e "  Iterations: ${YELLOW}$iteration${NC}"
echo ""

# Count log files
log_count=$(ls -1 .ralph-iteration-*.log 2>/dev/null | wc -l | tr -d ' ')
if [[ "$log_count" -gt 0 ]]; then
    echo -e "  Log files: $log_count"
fi

echo ""
echo -e "${RED}This will:${NC}"
echo "  - Set all stories to passes: false"
echo "  - Clear all completedAt timestamps"
echo "  - Archive progress.txt"
echo "  - Reset iteration counter to 0"
echo "  - Remove all iteration log files"
echo ""

# Ask for confirmation
read -p "Are you sure you want to reset all progress? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Reset cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Resetting...${NC}"

# Reset prd.json - set all passes to false and completedAt to null
jq '.userStories = [.userStories[] | .passes = false | .completedAt = null]' prd.json > prd.json.tmp && mv prd.json.tmp prd.json
echo -e "${GREEN}✓${NC} Reset all stories to incomplete"

# Archive progress.txt
if [[ -f "progress.txt" ]] && [[ -s "progress.txt" ]]; then
    timestamp=$(date +"%Y%m%d-%H%M%S")
    mv progress.txt "progress-${timestamp}.txt"
    echo -e "${GREEN}✓${NC} Archived progress.txt to progress-${timestamp}.txt"
fi

# Create fresh progress.txt
touch progress.txt
echo -e "${GREEN}✓${NC} Created fresh progress.txt"

# Reset .ralph-state
echo "0" > .ralph-state
echo -e "${GREEN}✓${NC} Reset iteration counter to 0"

# Remove log files
if [[ "$log_count" -gt 0 ]]; then
    rm -f .ralph-iteration-*.log
    echo -e "${GREEN}✓${NC} Removed $log_count iteration log files"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Reset complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Run ${YELLOW}ralph${NC} to start fresh"
