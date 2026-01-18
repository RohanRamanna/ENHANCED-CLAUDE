#!/usr/bin/env python3
"""
Skill Tracker Hook - PostToolUse
Automatically tracks skill usage when SKILL.md files are read.

Trigger: After Read/Write/Edit tools complete
Action: Updates skill's metadata.json (useCount++, lastUsed)
"""

import json
import sys
import os
import re
from datetime import datetime

SKILLS_DIR = os.path.expanduser("~/.claude/skills")

def update_skill_metadata(skill_name):
    """Update a skill's metadata.json with usage info."""
    metadata_path = os.path.join(SKILLS_DIR, skill_name, "metadata.json")

    # Load existing metadata or create new
    metadata = {}
    if os.path.exists(metadata_path):
        try:
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
        except (json.JSONDecodeError, IOError):
            metadata = {}

    # Update fields
    metadata["useCount"] = metadata.get("useCount", 0) + 1
    metadata["lastUsed"] = datetime.now().strftime("%Y-%m-%d")

    # Preserve other fields
    if "successCount" not in metadata:
        metadata["successCount"] = 0
    if "failureCount" not in metadata:
        metadata["failureCount"] = 0

    # Write back
    try:
        os.makedirs(os.path.dirname(metadata_path), exist_ok=True)
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        return True
    except IOError:
        return False

def update_skill_index(skill_name):
    """Update the skill in the main index."""
    index_path = os.path.join(SKILLS_DIR, "skill-index", "index.json")

    try:
        with open(index_path, 'r') as f:
            index = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return False

    # Find and update the skill
    for skill in index.get("skills", []):
        if skill.get("name") == skill_name:
            skill["useCount"] = skill.get("useCount", 0) + 1
            skill["lastUsed"] = datetime.now().strftime("%Y-%m-%d")
            break

    # Write back
    try:
        with open(index_path, 'w') as f:
            json.dump(index, f, indent=2)
        return True
    except IOError:
        return False

def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Get tool info
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    # Only track Read operations on skill files
    if tool_name != "Read":
        sys.exit(0)

    file_path = tool_input.get("file_path", "")

    # Check if this is a skill file
    # Pattern: ~/.claude/skills/<skill-name>/SKILL.md
    # or: /Users/.../skills/<skill-name>/SKILL.md
    skill_pattern = r'skills/([^/]+)/SKILL\.md$'
    match = re.search(skill_pattern, file_path)

    if match:
        skill_name = match.group(1)

        # Don't track meta-skill index reads
        if skill_name == "skill-index":
            sys.exit(0)

        # Update metadata and index
        update_skill_metadata(skill_name)
        update_skill_index(skill_name)

    sys.exit(0)

if __name__ == "__main__":
    main()
