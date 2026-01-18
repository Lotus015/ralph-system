#!/usr/bin/env bash
# Ralph Uninstall - Clean removal script
# Removes Ralph Loop System from ~/bin

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

BIN_DIR="$HOME/bin"
TEMPLATES_DIR="$HOME/.ralph-templates"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Uninstall${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List what will be removed
echo -e "${BLUE}The following will be removed:${NC}"
echo ""

SCRIPTS=("ralph" "ralph-init" "ralph-status" "ralph-reset" "ralph-logs" "ralph-prd")
found_any=false

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$BIN_DIR/$script" ]]; then
        echo "  $BIN_DIR/$script"
        found_any=true
    fi
done

if [[ -d "$TEMPLATES_DIR" ]]; then
    echo "  $TEMPLATES_DIR/ (templates directory)"
    found_any=true
fi

if [[ "$found_any" == false ]]; then
    echo -e "${YELLOW}No Ralph installation found${NC}"
    exit 0
fi

echo ""
read -p "Are you sure you want to uninstall? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Uninstall cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Removing...${NC}"

# Remove scripts
for script in "${SCRIPTS[@]}"; do
    if [[ -f "$BIN_DIR/$script" ]]; then
        rm "$BIN_DIR/$script"
        echo -e "${GREEN}✓${NC} Removed $script"
    fi
done

# Remove templates directory
if [[ -d "$TEMPLATES_DIR" ]]; then
    rm -rf "$TEMPLATES_DIR"
    echo -e "${GREEN}✓${NC} Removed templates directory"
fi

# Check for PATH entry in shell configs
echo ""
echo -e "${BLUE}Checking shell configuration...${NC}"

SHELL_CONFIGS=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
for rc_file in "${SHELL_CONFIGS[@]}"; do
    if [[ -f "$rc_file" ]] && grep -q "# Ralph Loop System" "$rc_file" 2>/dev/null; then
        echo -e "${YELLOW}Found Ralph PATH entry in $rc_file${NC}"
        read -p "Remove PATH entry from $rc_file? (y/n): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove Ralph lines from config
            sed -i.bak '/# Ralph Loop System/d' "$rc_file"
            sed -i.bak '/export PATH="\$HOME\/bin:\$PATH"/d' "$rc_file"
            rm -f "$rc_file.bak"
            echo -e "${GREEN}✓${NC} Removed PATH entry from $rc_file"
        fi
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Ralph uninstalled successfully${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Note: Project files (prd.json, progress.txt, etc.) remain in your projects."
echo ""
