#!/bin/bash
#
# Enhanced Claude - System A: Uninstaller
# Session Persistence & Searchable History
#
# This removes:
# - Session persistence hooks
# - History indexing hooks
# - History skill
# - Associated settings.json entries
#
# Does NOT remove:
# - Existing session data (~/.claude/sessions/)
# - Existing history index (~/.claude/history/)
# - Other systems' hooks or skills
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=============================================="
echo "  Enhanced Claude - System A Uninstaller"
echo "  Session Persistence & Searchable History"
echo "=============================================="
echo -e "${NC}"

# Detect home directory
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups"

echo -e "${YELLOW}Removing System A hooks...${NC}"

# Remove hooks
HOOKS_TO_REMOVE=(
    "session-recovery.py"
    "live-session-indexer.py"
    "history-indexer.py"
    "history-search.py"
)

for hook in "${HOOKS_TO_REMOVE[@]}"; do
    hook_path="$HOOKS_DIR/$hook"
    if [ -f "$hook_path" ]; then
        rm "$hook_path"
        echo "  Removed: $hook"
    fi
done

# Note: We don't remove hook_logger.py as it may be used by other systems

echo -e "${YELLOW}Removing System A skill...${NC}"

# Remove history skill
if [ -d "$SKILLS_DIR/history" ]; then
    rm -rf "$SKILLS_DIR/history"
    echo "  Removed: history skill"
fi

echo -e "${YELLOW}Updating settings.json...${NC}"

# Use Python to remove System A hooks from settings
python3 << 'SETTINGS_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")

# Load existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("No settings file found")
    exit(0)

if "hooks" not in settings:
    print("No hooks in settings")
    exit(0)

# Hooks to remove (System A specific)
system_a_scripts = [
    "history-search.py",
    "history-indexer.py",
    "live-session-indexer.py",
    "session-recovery.py"
]

modified = False

# Remove System A hooks from each event
for event in list(settings["hooks"].keys()):
    event_hooks = settings["hooks"][event]
    new_event_hooks = []

    for hook_group in event_hooks:
        hooks_list = hook_group.get("hooks", [])
        # Filter out System A hooks
        filtered_hooks = [
            h for h in hooks_list
            if not any(script in h.get("command", "") for script in system_a_scripts)
        ]

        if filtered_hooks:
            hook_group["hooks"] = filtered_hooks
            new_event_hooks.append(hook_group)
            if len(filtered_hooks) != len(hooks_list):
                modified = True
        elif len(hooks_list) > 0:
            modified = True

    if new_event_hooks:
        settings["hooks"][event] = new_event_hooks
    else:
        del settings["hooks"][event]
        modified = True

if modified:
    # Save updated settings
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
    print("Settings updated - System A hooks removed")
else:
    print("No System A hooks found in settings")
SETTINGS_SCRIPT

echo -e "${GREEN}"
echo "=============================================="
echo "  Uninstallation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Removed components:"
echo "  - 4 hooks (session-recovery, live-session-indexer, history-indexer, history-search)"
echo "  - 1 skill (history)"
echo ""
echo -e "${YELLOW}Note: The following were preserved:${NC}"
echo "  - Session data in ~/.claude/sessions/"
echo "  - History index in ~/.claude/history/"
echo "  - hook_logger.py (may be used by other systems)"
echo ""
echo "Restart Claude Code or run /hooks to reload hooks."
