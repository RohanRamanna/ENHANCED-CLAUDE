#!/bin/bash
#
# Enhanced Claude - Installation Script
# Installs hooks and configures Claude Code for automatic session persistence,
# skill matching, history search, and more.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Enhanced Claude - Installation"
echo "========================================"
echo ""

# Detect script directory (where repo is cloned)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
HISTORY_DIR="$CLAUDE_DIR/history"
SKILLS_DIR="$CLAUDE_DIR/skills"

echo "Source directory: $SCRIPT_DIR"
echo "Claude directory: $CLAUDE_DIR"
echo ""

# Step 1: Create directories
echo -e "${YELLOW}[1/5]${NC} Creating directories..."
mkdir -p "$HOOKS_DIR"
mkdir -p "$SESSIONS_DIR"
mkdir -p "$HISTORY_DIR"
mkdir -p "$SKILLS_DIR"
echo -e "${GREEN}Done${NC}"

# Step 2: Copy hooks
echo -e "${YELLOW}[2/5]${NC} Installing hooks (8 files)..."
if [ -d "$SCRIPT_DIR/hooks" ]; then
    cp "$SCRIPT_DIR/hooks/"*.py "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/"*.py
    echo -e "${GREEN}Done - Installed:${NC}"
    ls -1 "$HOOKS_DIR/"*.py | xargs -n1 basename | sed 's/^/  - /'
else
    echo -e "${RED}Error: hooks/ directory not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Step 3: Copy or merge settings.json
echo -e "${YELLOW}[3/5]${NC} Configuring settings.json..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Existing settings.json found.${NC}"
    echo "Options:"
    echo "  1) Backup existing and replace (recommended for fresh install)"
    echo "  2) Keep existing (you'll need to merge hooks manually)"
    echo "  3) Show what would be added"
    read -p "Choose [1/2/3]: " choice

    case $choice in
        1)
            BACKUP="$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$SETTINGS_FILE" "$BACKUP"
            echo "Backed up to: $BACKUP"
            cp "$SCRIPT_DIR/.claude/settings.json" "$SETTINGS_FILE"
            echo -e "${GREEN}Settings replaced${NC}"
            ;;
        2)
            echo -e "${YELLOW}Keeping existing settings. You'll need to add hooks manually.${NC}"
            echo "See .claude/settings.json in repo for required hook configuration."
            ;;
        3)
            echo ""
            echo "Hooks configuration needed:"
            cat "$SCRIPT_DIR/.claude/settings.json"
            echo ""
            echo -e "${YELLOW}Add these to your existing settings.json${NC}"
            ;;
        *)
            echo "Invalid choice, keeping existing settings."
            ;;
    esac
else
    cp "$SCRIPT_DIR/.claude/settings.json" "$SETTINGS_FILE"
    echo -e "${GREEN}Done - settings.json created${NC}"
fi

# Step 4: Copy skills (optional)
echo -e "${YELLOW}[4/5]${NC} Installing skills library..."
if [ -d "$SCRIPT_DIR/skills" ]; then
    # Don't overwrite existing skills
    SKILLS_COPIED=0
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
        skill_name=$(basename "$skill_dir")
        if [ ! -d "$SKILLS_DIR/$skill_name" ]; then
            cp -r "$skill_dir" "$SKILLS_DIR/"
            SKILLS_COPIED=$((SKILLS_COPIED + 1))
        fi
    done
    echo -e "${GREEN}Done - $SKILLS_COPIED new skills installed${NC}"
else
    echo "No skills directory found, skipping."
fi

# Step 5: Create persistence file templates (if in a project directory)
echo -e "${YELLOW}[5/5]${NC} Checking persistence files..."
if [ -f "$PWD/CLAUDE.md" ] || [ -f "$PWD/.claude/settings.json" ]; then
    # We're in a project directory
    for file in context.md todos.md insights.md; do
        if [ ! -f "$PWD/$file" ]; then
            if [ -f "$SCRIPT_DIR/templates/$file" ]; then
                cp "$SCRIPT_DIR/templates/$file" "$PWD/$file"
                echo "  Created $file"
            fi
        else
            echo "  $file already exists"
        fi
    done
else
    echo "  Not in a project directory, skipping persistence files."
    echo "  Copy templates/ files to your project to enable session persistence."
fi

echo ""
echo "========================================"
echo -e "${GREEN}  Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code or run: /hooks"
echo "  2. Start a conversation - hooks will run automatically"
echo ""
echo "What's installed:"
echo "  - 8 automation hooks in ~/.claude/hooks/"
echo "  - Hook configuration in ~/.claude/settings.json"
echo "  - Skills library in ~/.claude/skills/"
echo ""
echo "Documentation:"
echo "  - README.md - Quick overview"
echo "  - docs/HOW_TO_USE.md - Complete guide"
echo "  - CLAUDE.md - Full reference"
echo ""
