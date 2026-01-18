#!/usr/bin/env bash
# Ralph Init - Initialize Ralph in a project
# Sets up the necessary files and structure for Ralph Loop

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TEMPLATES_DIR="$HOME/.ralph-templates"

# Check if prd.json already exists
if [[ -f "prd.json" ]]; then
    echo -e "${YELLOW}Warning: prd.json already exists in this directory${NC}"
    echo "Use ralph-reset to start fresh, or delete prd.json manually"
    exit 1
fi

# Check for templates directory
if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo -e "${YELLOW}Templates directory not found at $TEMPLATES_DIR${NC}"
    echo "Creating templates directory..."
    mkdir -p "$TEMPLATES_DIR"

    # Create default prd-template.md if it doesn't exist
    if [[ ! -f "$TEMPLATES_DIR/prd-template.md" ]]; then
        cat > "$TEMPLATES_DIR/prd-template.md" << 'TEMPLATE'
# Project: [Your Project Name]

Branch: main
Description: What you're building and why

## User Stories

### Story 1: [Title]
Priority: 1
Description: Detailed description of what to build
Acceptance Criteria:
- Criterion 1
- Criterion 2
- Criterion 3
Tests: npm test
Status: pending

### Story 2: [Title]
Priority: 2
Description: Next story description
Acceptance Criteria:
- Criterion 1
Tests: npm test
Status: pending
TEMPLATE
    fi

    # Create default prompt.md if it doesn't exist
    if [[ ! -f "$TEMPLATES_DIR/prompt.md" ]]; then
        cat > "$TEMPLATES_DIR/prompt.md" << 'PROMPT'
You are working on story STORY_ID: STORY_TITLE

PROJECT CONTEXT:
Read prd.json for full project details
Read progress.txt for learnings from previous iterations

CURRENT STORY:
STORY_DESCRIPTION

ACCEPTANCE CRITERIA:
ACCEPTANCE_CRITERIA

INSTRUCTIONS:
1. Read the current codebase to understand existing structure
2. Implement ONLY this story - stay focused
3. Keep changes minimal and atomic
4. Write or update tests as specified
5. Run all tests: TEST_COMMANDS
6. If tests pass, commit: git add . && git commit -m "feat(STORY_ID): STORY_TITLE"
7. Update progress.txt with learnings

COMPLETION SIGNALS:
When story is 100% complete and all tests pass:
<promise>COMPLETE</promise>

If you need to continue working or are blocked:
<promise>CONTINUE</promise>

PROGRESS LOGGING:
Append to progress.txt in this format:
=== Iteration N - STORY_ID - TIMESTAMP ===
Status: COMPLETE or IN_PROGRESS or BLOCKED
Learnings:
- What worked well
- What was challenging
- Gotchas for future stories
- Test results
PROMPT
    fi
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Project Initialization${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Copy prd-template.md to current directory
cp "$TEMPLATES_DIR/prd-template.md" ./prd-template.md
echo -e "${GREEN}✓${NC} Created prd-template.md"

# Copy prompt.md to current directory
cp "$TEMPLATES_DIR/prompt.md" ./prompt.md
echo -e "${GREEN}✓${NC} Created prompt.md"

# Create empty progress.txt
touch progress.txt
echo -e "${GREEN}✓${NC} Created progress.txt"

# Create .ralph-state with 0
echo "0" > .ralph-state
echo -e "${GREEN}✓${NC} Created .ralph-state"

# Initialize git if not exists
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}Git repository not found. Initializing...${NC}"
    git init
    echo -e "${GREEN}✓${NC} Initialized git repository"
fi

# Create or append to .gitignore
GITIGNORE_ENTRIES=".ralph-state
.ralph-iteration-*.log"

if [[ -f ".gitignore" ]]; then
    # Check if entries already exist
    if ! grep -q ".ralph-state" .gitignore 2>/dev/null; then
        echo "" >> .gitignore
        echo "# Ralph Loop artifacts" >> .gitignore
        echo "$GITIGNORE_ENTRIES" >> .gitignore
        echo -e "${GREEN}✓${NC} Updated .gitignore"
    else
        echo -e "${YELLOW}○${NC} .gitignore already configured"
    fi
else
    echo "# Ralph Loop artifacts" > .gitignore
    echo "$GITIGNORE_ENTRIES" >> .gitignore
    echo -e "${GREEN}✓${NC} Created .gitignore"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Initialization complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Edit ${YELLOW}prd-template.md${NC} with your project details and stories"
echo -e "  2. Run ${YELLOW}ralph-prd prd-template.md${NC} to convert to prd.json"
echo -e "  3. Run ${YELLOW}ralph${NC} to start the loop"
echo ""

# Ask if user wants to open editor
read -p "Open prd-template.md in editor now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Try common editors
    if [[ -n "$EDITOR" ]]; then
        "$EDITOR" prd-template.md
    elif command -v code &> /dev/null; then
        code prd-template.md
    elif command -v nano &> /dev/null; then
        nano prd-template.md
    elif command -v vim &> /dev/null; then
        vim prd-template.md
    else
        echo -e "${YELLOW}No editor found. Please edit prd-template.md manually.${NC}"
    fi

    echo ""
    read -p "Convert to prd.json now? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v ralph-prd &> /dev/null; then
            ralph-prd prd-template.md
        elif [[ -f "./ralph-prd.sh" ]]; then
            ./ralph-prd.sh prd-template.md
        else
            echo -e "${YELLOW}ralph-prd not found. Run 'ralph-prd prd-template.md' after installation.${NC}"
        fi
    fi
fi
