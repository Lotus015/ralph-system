#!/usr/bin/env bash
# Ralph Install - Global installation script
# Installs Ralph Loop System to ~/bin for system-wide access

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi
echo -e "${GREEN}✓${NC} jq found"

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} git found"

if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}!${NC} Claude Code CLI not found (optional for ralph-prd)"
fi

echo ""

# Create ~/bin directory if it doesn't exist
BIN_DIR="$HOME/bin"
if [[ ! -d "$BIN_DIR" ]]; then
    echo -e "Creating $BIN_DIR..."
    mkdir -p "$BIN_DIR"
    echo -e "${GREEN}✓${NC} Created $BIN_DIR"
else
    echo -e "${GREEN}✓${NC} $BIN_DIR exists"
fi

# Copy scripts to ~/bin
echo ""
echo -e "${BLUE}Installing scripts...${NC}"

cp "$SCRIPT_DIR/ralph.sh" "$BIN_DIR/ralph"
chmod +x "$BIN_DIR/ralph"
echo -e "${GREEN}✓${NC} Installed ralph"

cp "$SCRIPT_DIR/ralph-init.sh" "$BIN_DIR/ralph-init"
chmod +x "$BIN_DIR/ralph-init"
echo -e "${GREEN}✓${NC} Installed ralph-init"

cp "$SCRIPT_DIR/ralph-status.sh" "$BIN_DIR/ralph-status"
chmod +x "$BIN_DIR/ralph-status"
echo -e "${GREEN}✓${NC} Installed ralph-status"

cp "$SCRIPT_DIR/ralph-reset.sh" "$BIN_DIR/ralph-reset"
chmod +x "$BIN_DIR/ralph-reset"
echo -e "${GREEN}✓${NC} Installed ralph-reset"

cp "$SCRIPT_DIR/ralph-logs.sh" "$BIN_DIR/ralph-logs"
chmod +x "$BIN_DIR/ralph-logs"
echo -e "${GREEN}✓${NC} Installed ralph-logs"

cp "$SCRIPT_DIR/ralph-prd.sh" "$BIN_DIR/ralph-prd"
chmod +x "$BIN_DIR/ralph-prd"
echo -e "${GREEN}✓${NC} Installed ralph-prd"

# Create templates directory
TEMPLATES_DIR="$HOME/.ralph-templates"
echo ""
echo -e "${BLUE}Installing templates...${NC}"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    mkdir -p "$TEMPLATES_DIR"
fi

cp "$SCRIPT_DIR/prd-template.md" "$TEMPLATES_DIR/prd-template.md"
echo -e "${GREEN}✓${NC} Installed prd-template.md"

cp "$SCRIPT_DIR/prompt.md" "$TEMPLATES_DIR/prompt.md"
echo -e "${GREEN}✓${NC} Installed prompt.md"

# Check if ~/bin is in PATH
echo ""
echo -e "${BLUE}Checking PATH...${NC}"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}$BIN_DIR is not in your PATH${NC}"
    echo ""

    # Detect shell and config file
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            RC_FILE="$HOME/.bashrc"
            ;;
        zsh)
            RC_FILE="$HOME/.zshrc"
            ;;
        *)
            RC_FILE="$HOME/.profile"
            ;;
    esac

    read -p "Add $BIN_DIR to PATH in $RC_FILE? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" >> "$RC_FILE"
        echo "# Ralph Loop System" >> "$RC_FILE"
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$RC_FILE"
        echo -e "${GREEN}✓${NC} Added to $RC_FILE"
        echo ""
        echo -e "${YELLOW}Run 'source $RC_FILE' or open a new terminal to use Ralph${NC}"
    else
        echo -e "${YELLOW}Add this to your shell config manually:${NC}"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
    fi
else
    echo -e "${GREEN}✓${NC} $BIN_DIR is already in PATH"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Usage:"
echo -e "  ${YELLOW}ralph-init${NC}        Initialize Ralph in a project"
echo -e "  ${YELLOW}ralph${NC}             Run the loop"
echo -e "  ${YELLOW}ralph-status${NC}      Check progress"
echo -e "  ${YELLOW}ralph-reset${NC}       Reset and start fresh"
echo -e "  ${YELLOW}ralph-logs${NC}        View iteration logs"
echo -e "  ${YELLOW}ralph-prd${NC}         Convert markdown to prd.json"
echo ""
echo -e "Quick start:"
echo "  cd my-project"
echo "  ralph-init"
echo "  # Edit prd-template.md"
echo "  ralph-prd prd-template.md"
echo "  ralph"
echo ""
