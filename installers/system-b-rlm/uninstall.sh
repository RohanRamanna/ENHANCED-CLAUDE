#!/bin/bash
#
# Enhanced Claude - System B: Uninstaller
# RLM Detection & Processing
#
# This removes:
# - Large input detection hook
# - RLM skill
# - Associated settings.json entries
#
# Does NOT remove:
# - RLM tools in project directory
# - Existing rlm_context data
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=============================================="
echo "  Enhanced Claude - System B Uninstaller"
echo "  RLM Detection & Processing"
echo "=============================================="
echo -e "${NC}"

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo -e "${YELLOW}Removing System B hooks...${NC}"

if [ -f "$HOOKS_DIR/large-input-detector.py" ]; then
    rm "$HOOKS_DIR/large-input-detector.py"
    echo "  Removed: large-input-detector.py"
fi

echo -e "${YELLOW}Removing System B skill...${NC}"

if [ -d "$SKILLS_DIR/rlm" ]; then
    rm -rf "$SKILLS_DIR/rlm"
    echo "  Removed: rlm skill"
fi

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

system_b_scripts = ["large-input-detector.py"]
modified = False

for event in list(settings["hooks"].keys()):
    event_hooks = settings["hooks"][event]
    new_event_hooks = []
    for hook_group in event_hooks:
        hooks_list = hook_group.get("hooks", [])
        filtered_hooks = [h for h in hooks_list if not any(script in h.get("command", "") for script in system_b_scripts)]
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
    print("Settings updated - System B hooks removed")
SETTINGS_SCRIPT

echo -e "${GREEN}"
echo "=============================================="
echo "  Uninstallation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Removed components:"
echo "  - 1 hook (large-input-detector)"
echo "  - 1 skill (rlm)"
echo ""
echo -e "${YELLOW}Note: The following were preserved:${NC}"
echo "  - RLM tools in project rlm_tools/ directory"
echo "  - Data in rlm_context/ directory"
echo "  - hook_logger.py (may be used by other systems)"
echo ""
echo "Restart Claude Code or run /hooks to reload hooks."
