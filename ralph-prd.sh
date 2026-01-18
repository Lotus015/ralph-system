#!/usr/bin/env bash
# Ralph PRD - Convert markdown PRD to JSON
# Parses markdown project description into prd.json format

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo "Usage: ralph-prd [options] <markdown-file>"
    echo ""
    echo "Convert a markdown PRD to prd.json format"
    echo ""
    echo "Options:"
    echo "  -v, --validate  Validate existing prd.json structure"
    echo "  -l, --list      List incomplete stories from prd.json"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  ralph-prd prd-template.md    # Convert markdown to JSON"
    echo "  ralph-prd -v                 # Validate prd.json"
    echo "  ralph-prd -l                 # List incomplete stories"
    exit 0
}

# Validate prd.json structure
validate_prd() {
    if [[ ! -f "prd.json" ]]; then
        echo -e "${RED}Error: prd.json not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}Validating prd.json structure...${NC}"
    echo ""

    local errors=0

    # Check if valid JSON
    if ! jq empty prd.json 2>/dev/null; then
        echo -e "${RED}✗${NC} Invalid JSON syntax"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Valid JSON syntax"

    # Check required top-level fields
    local project branch description
    project=$(jq -r '.project // empty' prd.json)
    branch=$(jq -r '.branchName // empty' prd.json)
    description=$(jq -r '.description // empty' prd.json)

    if [[ -z "$project" ]]; then
        echo -e "${RED}✗${NC} Missing 'project' field"
        ((errors++))
    else
        echo -e "${GREEN}✓${NC} Has 'project' field: $project"
    fi

    if [[ -z "$branch" ]]; then
        echo -e "${RED}✗${NC} Missing 'branchName' field"
        ((errors++))
    else
        echo -e "${GREEN}✓${NC} Has 'branchName' field: $branch"
    fi

    if [[ -z "$description" ]]; then
        echo -e "${RED}✗${NC} Missing 'description' field"
        ((errors++))
    else
        echo -e "${GREEN}✓${NC} Has 'description' field"
    fi

    # Check userStories array
    local story_count
    story_count=$(jq '.userStories | length' prd.json 2>/dev/null || echo "0")

    if [[ "$story_count" -eq 0 ]]; then
        echo -e "${RED}✗${NC} No user stories found"
        ((errors++))
    else
        echo -e "${GREEN}✓${NC} Has $story_count user stories"
    fi

    # Validate each story
    echo ""
    echo -e "${BLUE}Validating stories...${NC}"

    jq -r '.userStories[] | @base64' prd.json | while read -r story_b64; do
        local story id title
        story=$(echo "$story_b64" | base64 --decode)
        id=$(echo "$story" | jq -r '.id // empty')
        title=$(echo "$story" | jq -r '.title // empty')

        local story_errors=""

        # Check required fields
        [[ -z "$id" ]] && story_errors+="id, "
        [[ -z "$title" ]] && story_errors+="title, "
        [[ $(echo "$story" | jq '.priority // empty') == "" ]] && story_errors+="priority, "
        [[ $(echo "$story" | jq -r '.description // empty') == "" ]] && story_errors+="description, "
        [[ $(echo "$story" | jq '.acceptance | length') -eq 0 ]] && story_errors+="acceptance, "
        [[ $(echo "$story" | jq '.tests | length') -eq 0 ]] && story_errors+="tests, "
        [[ $(echo "$story" | jq 'has("passes")') == "false" ]] && story_errors+="passes, "

        if [[ -n "$story_errors" ]]; then
            echo -e "${RED}✗${NC} Story ${id:-???}: Missing ${story_errors%, }"
        else
            echo -e "${GREEN}✓${NC} Story $id: $title"
        fi
    done

    echo ""
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}Validation failed with $errors errors${NC}"
        exit 1
    else
        echo -e "${GREEN}prd.json is valid!${NC}"
    fi
}

# List incomplete stories
list_incomplete() {
    if [[ ! -f "prd.json" ]]; then
        echo -e "${RED}Error: prd.json not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}Incomplete Stories${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local count
    count=$(jq '[.userStories[] | select(.passes == false)] | length' prd.json)

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}All stories are complete!${NC}"
        exit 0
    fi

    echo ""
    jq -r '.userStories[] | select(.passes == false) | "\(.priority)|\(.id)|\(.title)|\(.description)"' prd.json | \
        sort -t'|' -k1 -n | while IFS='|' read -r priority id title desc; do
            echo -e "${YELLOW}[$id]${NC} (Priority: $priority)"
            echo "  Title: $title"
            echo "  Description: $desc"
            echo ""
        done

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total: ${YELLOW}$count${NC} incomplete stories"
}

# Convert markdown to JSON
convert_markdown() {
    local md_file="$1"

    if [[ ! -f "$md_file" ]]; then
        echo -e "${RED}Error: File not found: $md_file${NC}"
        exit 1
    fi

    # Check for Claude CLI
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Error: Claude Code CLI is not installed${NC}"
        exit 1
    fi

    echo -e "${BLUE}Converting $md_file to prd.json...${NC}"
    echo ""

    # Read markdown content
    local md_content
    md_content=$(cat "$md_file")

    # Create conversion prompt
    local prompt="Convert the following markdown PRD to a valid JSON object matching this exact structure:

{
  \"project\": \"Project Name\",
  \"branchName\": \"main\",
  \"description\": \"Project description\",
  \"userStories\": [
    {
      \"id\": \"S1\",
      \"priority\": 1,
      \"title\": \"Story title\",
      \"description\": \"Story description\",
      \"acceptance\": [\"criterion 1\", \"criterion 2\"],
      \"tests\": [\"test command\"],
      \"passes\": false,
      \"completedAt\": null
    }
  ]
}

Rules:
- Extract project name from the # Project: line
- Extract branch from Branch: line (default to 'main')
- Extract description from Description: line
- Parse each ### Story section into a userStory object
- Set priority based on the order or Priority: line
- Parse 'Acceptance Criteria:' bullet points into the acceptance array
- Parse 'Tests:' line into tests array (split by comma or newline)
- Always set passes: false and completedAt: null
- Story IDs should be S1, S2, S3, etc.
- Output ONLY valid JSON, no markdown or explanation

Markdown content:
$md_content"

    # Run Claude to convert
    local output
    if output=$(claude --dangerously-skip-permissions -p "$prompt" 2>&1); then
        # Extract JSON from output (Claude might add explanation)
        local json_output
        json_output=$(echo "$output" | grep -o '{.*}' | head -1 || echo "$output")

        # Try to parse as JSON
        if echo "$json_output" | jq empty 2>/dev/null; then
            echo -e "${GREEN}Conversion successful!${NC}"
            echo ""
            echo -e "${BLUE}Preview:${NC}"
            echo "$json_output" | jq '.'

            echo ""
            read -p "Save as prd.json? (y/n): " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$json_output" | jq '.' > prd.json
                echo -e "${GREEN}Saved to prd.json${NC}"
            else
                echo "$json_output" | jq '.' > prd-draft.json
                echo -e "${YELLOW}Saved to prd-draft.json${NC}"
            fi
        else
            echo -e "${RED}Error: Claude output is not valid JSON${NC}"
            echo ""
            echo "Raw output:"
            echo "$output"
            echo ""
            echo -e "${YELLOW}Saving raw output to prd-draft.txt for manual editing${NC}"
            echo "$output" > prd-draft.txt
            exit 1
        fi
    else
        echo -e "${RED}Error running Claude${NC}"
        echo "$output"
        exit 1
    fi
}

# Main
case "${1:-}" in
    -v|--validate)
        validate_prd
        ;;
    -l|--list)
        list_incomplete
        ;;
    -h|--help)
        show_usage
        ;;
    "")
        show_usage
        ;;
    *)
        convert_markdown "$1"
        ;;
esac
