#!/bin/bash
#
# Enhanced Claude - System C: Uninstaller
# Auto Skills & Skills Library
#
# This removes:
# - skill-matcher, skill-tracker, detect-learning, learning-moment-pickup hooks
# - All 18 skills
# - Associated settings.json entries
#
# Does NOT remove:
# - hook_logger.py (may be used by other systems)
# - Session data
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=============================================="
echo "  Enhanced Claude - System C Uninstaller"
echo "  Auto Skills & Skills Library"
echo "=============================================="
echo -e "${NC}"

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo -e "${YELLOW}Removing System C hooks...${NC}"

for hook in skill-matcher.py skill-tracker.py detect-learning.py learning-moment-pickup.py; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
        rm "$HOOKS_DIR/$hook"
        echo "  Removed: $hook"
    fi
done

echo -e "${YELLOW}Removing System C skills...${NC}"

# List of skills to remove
skills=(
    "skill-index"
    "skill-creator"
    "skill-updater"
    "skill-loader"
    "skill-health"
    "skill-improver"
    "skill-tracker"
    "skill-validator"
    "skill-matcher"
    "web-research"
    "llm-api-tool-use"
    "deno2-http-kv-server"
    "hono-bun-sqlite-api"
    "udcp"
    "markdown-to-pdf"
    "history"
    "rlm"
    "hook-development"
)

for skill in "${skills[@]}"; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
        rm -rf "$SKILLS_DIR/$skill"
        echo "  Removed: $skill"
    fi
done

echo -e "${YELLOW}Updating settings.json...${NC}"

python3 << 'SETTINGS_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except:
    print("No settings file found")
    exit(0)

if "hooks" not in settings:
    exit(0)

system_c_scripts = [
    "skill-matcher.py",
    "skill-tracker.py",
    "detect-learning.py",
    "learning-moment-pickup.py"
]

modified = False

for event in list(settings["hooks"].keys()):
    event_hooks = settings["hooks"][event]
    new_event_hooks = []
    for hook_group in event_hooks:
        hooks_list = hook_group.get("hooks", [])
        filtered_hooks = [h for h in hooks_list if not any(script in h.get("command", "") for script in system_c_scripts)]
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
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
    print("Settings updated - System C hooks removed")
SETTINGS_SCRIPT

# Remove pending learning moment file if exists
if [ -f "$CLAUDE_DIR/pending-learning-moment.json" ]; then
    rm "$CLAUDE_DIR/pending-learning-moment.json"
    echo "  Removed: pending-learning-moment.json"
fi

echo -e "${GREEN}"
echo "=============================================="
echo "  Uninstallation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Removed components:"
echo "  - 4 hooks (skill-matcher, skill-tracker, detect-learning, learning-moment-pickup)"
echo "  - 18 skills"
echo ""
echo -e "${YELLOW}Preserved:${NC}"
echo "  - hook_logger.py (may be used by other systems)"
echo ""
echo "Restart Claude Code or run /hooks to reload hooks."
