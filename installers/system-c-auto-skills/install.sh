#!/bin/bash
#
# Enhanced Claude - System C: Auto Skills & Skills Library
# macOS/Linux Installer
#
# This installs:
# - 5 hooks (skill-matcher, skill-tracker, detect-learning, learning-moment-pickup, hook_logger)
# - 18 skills with metadata
# - Settings.json entries for UserPromptSubmit, PostToolUse, and Stop events
#
# Requirements: Python 3.6+
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=============================================="
echo "  Enhanced Claude - System C Installer"
echo "  Auto Skills & Skills Library"
echo "=============================================="
echo -e "${NC}"

# Define paths
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$HOOKS_DIR/logs"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups/system-c-$(date +%Y%m%d_%H%M%S)"

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$HOOKS_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$SKILLS_DIR"
mkdir -p "$BACKUP_DIR"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    echo "Backing up existing settings..."
    cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.backup"
fi

# -------------------------------------------
# HOOK: hook_logger.py
# -------------------------------------------
echo -e "${YELLOW}Installing hooks...${NC}"

if [ ! -f "$HOOKS_DIR/hook_logger.py" ]; then
cat > "$HOOKS_DIR/hook_logger.py" << 'HOOK_LOGGER_EOF'
#!/usr/bin/env python3
"""
Shared logging utility for Claude Code hooks.
"""

import os
import json
import traceback
from datetime import datetime
from pathlib import Path

LOG_DIR = Path(os.path.expanduser("~/.claude/hooks/logs"))
MAX_LOG_SIZE = 1_000_000
MAX_LOG_FILES = 3

class HookLogger:
    def __init__(self, hook_name: str):
        self.hook_name = hook_name
        self.log_dir = LOG_DIR
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.log_file = self.log_dir / f"{hook_name}.log"
        self._rotate_if_needed()

    def _rotate_if_needed(self):
        if self.log_file.exists() and self.log_file.stat().st_size > MAX_LOG_SIZE:
            for i in range(MAX_LOG_FILES - 1, 0, -1):
                old_file = self.log_dir / f"{self.hook_name}.{i}.log"
                new_file = self.log_dir / f"{self.hook_name}.{i + 1}.log"
                if old_file.exists():
                    if i + 1 >= MAX_LOG_FILES:
                        old_file.unlink()
                    else:
                        old_file.rename(new_file)
            backup = self.log_dir / f"{self.hook_name}.1.log"
            self.log_file.rename(backup)

    def _write(self, level: str, message: str, **kwargs):
        timestamp = datetime.now().isoformat()
        entry = {"timestamp": timestamp, "level": level, "hook": self.hook_name, "message": message}
        if kwargs.get("exc_info"):
            entry["traceback"] = traceback.format_exc()
        if kwargs.get("data"):
            entry["data"] = kwargs["data"]
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass

    def debug(self, message: str, **kwargs): self._write("DEBUG", message, **kwargs)
    def info(self, message: str, **kwargs): self._write("INFO", message, **kwargs)
    def warning(self, message: str, **kwargs): self._write("WARNING", message, **kwargs)
    def error(self, message: str, **kwargs): self._write("ERROR", message, **kwargs)
    def log_input(self, hook_input: dict):
        sanitized = {"prompt_length": len(hook_input.get("prompt", "")), "prompt_preview": hook_input.get("prompt", "")[:100], "cwd": hook_input.get("cwd", ""), "has_transcript": bool(hook_input.get("transcript_path"))}
        self.debug("Hook input received", data=sanitized)
    def log_output(self, output: dict): self.debug("Hook output", data=output)
HOOK_LOGGER_EOF
echo "  Created: hook_logger.py"
fi

# -------------------------------------------
# HOOK: skill-matcher.py
# -------------------------------------------
cat > "$HOOKS_DIR/skill-matcher.py" << 'SKILL_MATCHER_EOF'
#!/usr/bin/env python3
"""
Skill Matcher Hook - UserPromptSubmit
Automatically suggests relevant skills based on user prompts.
"""

import json
import sys
import os
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("skill-matcher")
SKILL_INDEX_PATH = os.path.expanduser("~/.claude/skills/skill-index/index.json")

def load_skill_index():
    try:
        with open(SKILL_INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"skills": []}

def score_skill(skill, prompt_lower, prompt_words):
    score = 0
    tags = [t.lower() for t in skill.get("tags", [])]
    for tag in tags:
        if tag in prompt_lower:
            score += 3
        for tag_word in tag.split("-"):
            if tag_word in prompt_words and len(tag_word) > 2:
                score += 2
    category = skill.get("category", "").lower()
    if category in prompt_lower:
        score += 5
    summary = skill.get("summary", "").lower()
    summary_words = set(summary.split())
    matching_summary_words = prompt_words & summary_words
    common_words = {"a", "an", "the", "with", "and", "or", "for", "to", "in", "on", "by", "is", "are"}
    meaningful_matches = matching_summary_words - common_words
    score += len(meaningful_matches) * 2
    name = skill.get("name", "").lower()
    name_parts = name.replace("-", " ").split()
    for part in name_parts:
        if part in prompt_words and len(part) > 2:
            score += 3
    last_used = skill.get("lastUsed")
    if last_used:
        try:
            last_used_date = datetime.strptime(last_used, "%Y-%m-%d")
            if datetime.now() - last_used_date < timedelta(days=7):
                score += 1
        except ValueError:
            pass
    return score

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except Exception as e:
        logger.error(f"Error reading input: {e}", exc_info=True)
        sys.exit(0)
    prompt = hook_input.get("prompt", "")
    if not prompt:
        sys.exit(0)
    prompt_lower = prompt.lower()
    prompt_words = set(prompt_lower.replace("-", " ").replace("_", " ").split())
    try:
        index = load_skill_index()
        skills = index.get("skills", [])
    except Exception as e:
        logger.error(f"Error loading skill index: {e}", exc_info=True)
        sys.exit(0)
    scored_skills = []
    for skill in skills:
        score = score_skill(skill, prompt_lower, prompt_words)
        if score >= 5:
            scored_skills.append((score, skill))
    scored_skills.sort(key=lambda x: x[0], reverse=True)
    if scored_skills:
        top_matches = scored_skills[:3]
        strong_matches = [(s, sk) for s, sk in top_matches if s >= 10]
        if strong_matches:
            lines = ["[SKILL MATCH] Relevant skills detected:"]
            for score, skill in strong_matches:
                name = skill.get("name", "unknown")
                summary = skill.get("summary", "")
                lines.append(f"  - {name} (score:{score}): {summary}")
                lines.append(f"    Load with: cat ~/.claude/skills/{name}/SKILL.md")
            output = {"hookSpecificOutput": {"additionalContext": "\n".join(lines)}}
            logger.log_output(output)
            print(json.dumps(output), flush=True)
    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
SKILL_MATCHER_EOF
echo "  Created: skill-matcher.py"

# -------------------------------------------
# HOOK: skill-tracker.py
# -------------------------------------------
cat > "$HOOKS_DIR/skill-tracker.py" << 'SKILL_TRACKER_EOF'
#!/usr/bin/env python3
"""
Skill Tracker Hook - PostToolUse
Automatically tracks skill usage when SKILL.md files are read.
"""

import json
import sys
import os
import re
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("skill-tracker")
SKILLS_DIR = os.path.expanduser("~/.claude/skills")

def update_skill_metadata(skill_name):
    metadata_path = os.path.join(SKILLS_DIR, skill_name, "metadata.json")
    metadata = {}
    if os.path.exists(metadata_path):
        try:
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
        except (json.JSONDecodeError, IOError):
            metadata = {}
    metadata["useCount"] = metadata.get("useCount", 0) + 1
    metadata["lastUsed"] = datetime.now().strftime("%Y-%m-%d")
    if "successCount" not in metadata:
        metadata["successCount"] = 0
    if "failureCount" not in metadata:
        metadata["failureCount"] = 0
    try:
        os.makedirs(os.path.dirname(metadata_path), exist_ok=True)
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        return True
    except IOError:
        return False

def update_skill_index(skill_name):
    index_path = os.path.join(SKILLS_DIR, "skill-index", "index.json")
    try:
        with open(index_path, 'r') as f:
            index = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return False
    for skill in index.get("skills", []):
        if skill.get("name") == skill_name:
            skill["useCount"] = skill.get("useCount", 0) + 1
            skill["lastUsed"] = datetime.now().strftime("%Y-%m-%d")
            break
    try:
        with open(index_path, 'w') as f:
            json.dump(index, f, indent=2)
        return True
    except IOError:
        return False

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
    except Exception as e:
        logger.error(f"Error reading input: {e}", exc_info=True)
        sys.exit(0)
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    if tool_name != "Read":
        sys.exit(0)
    file_path = tool_input.get("file_path", "")
    skill_pattern = r'skills/([^/]+)/SKILL\.md$'
    match = re.search(skill_pattern, file_path)
    if match:
        skill_name = match.group(1)
        if skill_name == "skill-index":
            sys.exit(0)
        if update_skill_metadata(skill_name):
            logger.info(f"Updated metadata for skill: {skill_name}")
        if update_skill_index(skill_name):
            logger.debug(f"Updated index for skill: {skill_name}")
    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
SKILL_TRACKER_EOF
echo "  Created: skill-tracker.py"

# -------------------------------------------
# HOOK: detect-learning.py
# -------------------------------------------
cat > "$HOOKS_DIR/detect-learning.py" << 'DETECT_LEARNING_EOF'
#!/usr/bin/env python3
"""
Learning Detection Hook - Stop
Detects trial-and-error learning moments and saves them for pickup.
"""

import json
import sys
import os
import re
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("detect-learning")
MAX_MESSAGES_TO_ANALYZE = 30
MIN_FAILURES_FOR_TRIGGER = 3

def load_transcript(transcript_path):
    messages = []
    try:
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        messages.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except (FileNotFoundError, IOError):
        pass
    return messages

def count_tool_failures(messages):
    failures = 0
    successes_after_failure = 0
    saw_failure = False
    for msg in messages[-MAX_MESSAGES_TO_ANALYZE:]:
        content = str(msg)
        error_patterns = [r'error:', r'Error:', r'ERROR', r'failed', r'Failed', r'FAILED', r'exception', r'Exception', r'not found', r'No such file', r'Permission denied', r'command not found', r'ModuleNotFoundError', r'ImportError', r'SyntaxError', r'TypeError', r'ValueError', r'exit code [1-9]']
        for pattern in error_patterns:
            if re.search(pattern, content):
                failures += 1
                saw_failure = True
                break
        else:
            if saw_failure:
                success_patterns = [r'worked', r'success', r'fixed', r'resolved', r'completed', r'exit code 0']
                for pattern in success_patterns:
                    if re.search(pattern, content, re.IGNORECASE):
                        successes_after_failure += 1
                        break
    return failures, successes_after_failure

def detect_trial_and_error_phrases(messages):
    phrases_found = 0
    trial_error_patterns = [r'let me try', r'trying again', r'another approach', r'different approach', r'turns out', r'the issue was', r'the problem was', r"that didn't work", r'that failed', r"I'll try", r'attempting', r'workaround']
    for msg in messages[-MAX_MESSAGES_TO_ANALYZE:]:
        content = str(msg)
        for pattern in trial_error_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                phrases_found += 1
                break
    return phrases_found

def should_trigger_learning_moment(messages):
    failures, successes_after = count_tool_failures(messages)
    trial_error_phrases = detect_trial_and_error_phrases(messages)
    if failures >= MIN_FAILURES_FOR_TRIGGER and successes_after >= 1:
        return True, f"Detected {failures} failures followed by success"
    if trial_error_phrases >= 5:
        return True, f"Detected {trial_error_phrases} trial-and-error attempts"
    return False, None

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
    except Exception as e:
        logger.error(f"Error reading input: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)
    transcript_path = hook_input.get("transcript_path", "")
    if not transcript_path or not os.path.exists(transcript_path):
        print('{"continue": true}')
        sys.exit(0)
    messages = load_transcript(transcript_path)
    if len(messages) < 5:
        print('{"continue": true}')
        sys.exit(0)
    is_learning_moment, reason = should_trigger_learning_moment(messages)
    if is_learning_moment:
        logger.info(f"Learning moment detected: {reason}")
        session_id = os.path.basename(transcript_path).replace('.jsonl', '')
        pending_file = os.path.expanduser("~/.claude/pending-learning-moment.json")
        learning_moment = {"detected_at": datetime.now().isoformat(), "reason": reason, "session_id": session_id}
        try:
            with open(pending_file, 'w') as f:
                json.dump(learning_moment, f)
        except Exception as e:
            logger.error(f"Failed to save learning moment: {e}")
    logger.info("Hook completed")
    print('{"continue": true}')
    sys.exit(0)

if __name__ == "__main__":
    main()
DETECT_LEARNING_EOF
echo "  Created: detect-learning.py"

# -------------------------------------------
# HOOK: learning-moment-pickup.py
# -------------------------------------------
cat > "$HOOKS_DIR/learning-moment-pickup.py" << 'LEARNING_PICKUP_EOF'
#!/usr/bin/env python3
"""
Learning Moment Pickup Hook - UserPromptSubmit
Checks for pending learning moments and injects them into context.
"""

import json
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("learning-moment-pickup")
PENDING_FILE = os.path.expanduser("~/.claude/pending-learning-moment.json")
MAX_AGE_HOURS = 24

def main():
    logger.info("Hook started")
    if not os.path.exists(PENDING_FILE):
        sys.exit(0)
    try:
        with open(PENDING_FILE, 'r') as f:
            moment = json.load(f)
        detected_at = datetime.fromisoformat(moment['detected_at'])
        age_hours = (datetime.now() - detected_at).total_seconds() / 3600
        if age_hours > MAX_AGE_HOURS:
            os.remove(PENDING_FILE)
            sys.exit(0)
        os.remove(PENDING_FILE)
        output = {"hookSpecificOutput": {"additionalContext": f"""[LEARNING MOMENT - ACTION NEEDED]
{moment['reason']}

A learning moment was detected in your previous response. Before addressing the user's current request:
1. Briefly acknowledge this to the user
2. Ask if they'd like to save this solution as a reusable skill (/skill-creator)
3. Or note it in insights.md for future reference

Then proceed with their current request."""}}
        print(json.dumps(output), flush=True)
        logger.info("Injected learning moment context")
    except Exception as e:
        logger.error(f"Error processing learning moment: {e}", exc_info=True)
        if os.path.exists(PENDING_FILE):
            try:
                os.remove(PENDING_FILE)
            except:
                pass
        sys.exit(0)
    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
LEARNING_PICKUP_EOF
echo "  Created: learning-moment-pickup.py"

# Make hooks executable
chmod +x "$HOOKS_DIR/hook_logger.py"
chmod +x "$HOOKS_DIR/skill-matcher.py"
chmod +x "$HOOKS_DIR/skill-tracker.py"
chmod +x "$HOOKS_DIR/detect-learning.py"
chmod +x "$HOOKS_DIR/learning-moment-pickup.py"

# -------------------------------------------
# SKILLS INSTALLATION
# -------------------------------------------
echo -e "${YELLOW}Installing skills...${NC}"

# Create skill-index
mkdir -p "$SKILLS_DIR/skill-index"
cat > "$SKILLS_DIR/skill-index/index.json" << 'INDEX_EOF'
{
  "skills": [
    {"name": "skill-index", "category": "meta", "tags": ["discovery", "search", "index", "meta-skill"], "summary": "Index and discover available skills by category/tags", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "skill-creator", "category": "meta", "tags": ["learning", "skills", "automation", "meta-skill"], "summary": "Auto-detect learning moments and create reusable skills", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "skill-updater", "category": "meta", "tags": ["learning", "skills", "maintenance", "meta-skill"], "summary": "Update skills when they fail and better solutions found", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "skill-loader", "category": "meta", "tags": ["loading", "context", "efficiency", "meta-skill"], "summary": "Lazy-load skills to minimize context usage", "dependencies": ["skill-index"], "lastUsed": null, "useCount": 0},
    {"name": "skill-health", "category": "meta", "tags": ["tracking", "quality", "maintenance", "analytics", "meta-skill"], "summary": "Track skill usage and identify skills needing updates", "dependencies": ["skill-index"], "lastUsed": null, "useCount": 0},
    {"name": "skill-improver", "category": "meta", "tags": ["improvement", "proactive", "suggestions", "meta-skill"], "summary": "Proactively suggest skill improvements during usage", "dependencies": ["skill-index", "skill-updater"], "lastUsed": null, "useCount": 0},
    {"name": "skill-tracker", "category": "meta", "tags": ["tracking", "metrics", "analytics", "automation", "meta-skill"], "summary": "Automatically track skill usage, success, and failure", "dependencies": ["skill-index"], "lastUsed": null, "useCount": 0},
    {"name": "skill-validator", "category": "meta", "tags": ["validation", "testing", "quality", "dependencies", "meta-skill"], "summary": "Validate skills still work by checking dependencies and examples", "dependencies": ["skill-index", "skill-health"], "lastUsed": null, "useCount": 0},
    {"name": "skill-matcher", "category": "meta", "tags": ["discovery", "matching", "search", "suggestions", "meta-skill"], "summary": "Smart skill discovery with scoring and proactive suggestions", "dependencies": ["skill-index"], "lastUsed": null, "useCount": 0},
    {"name": "web-research", "category": "meta", "tags": ["research", "web", "fallback", "troubleshooting"], "summary": "Fallback research when stuck after initial attempt fails", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "llm-api-tool-use", "category": "api", "tags": ["anthropic", "llm", "tool-use", "python", "sdk", "agents"], "summary": "Claude API tool use with Python SDK", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "deno2-http-kv-server", "category": "setup", "tags": ["deno", "http", "kv", "database", "server", "typescript"], "summary": "Deno 2 HTTP server with KV database", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "hono-bun-sqlite-api", "category": "setup", "tags": ["hono", "bun", "sqlite", "api", "rest", "typescript"], "summary": "REST API with Hono, Bun and SQLite", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "udcp", "category": "meta", "tags": ["git", "commit", "push", "documentation", "workflow", "meta-skill"], "summary": "Update documentation, commit, and push in one command", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "markdown-to-pdf", "category": "setup", "tags": ["markdown", "pdf", "documentation", "export", "macos"], "summary": "Convert Markdown files to PDF on macOS without LaTeX", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "history", "category": "utility", "tags": ["history", "search", "memory", "context", "sessions", "retrieval"], "summary": "Search and retrieve past conversation history without filling context", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "rlm", "category": "processing", "tags": ["rlm", "large-documents", "chunking", "subagents", "aggregation", "context-overflow"], "summary": "Process documents/codebases larger than context window using chunking and subagents", "dependencies": [], "lastUsed": null, "useCount": 0},
    {"name": "hook-development", "category": "development", "tags": ["hooks", "automation", "UserPromptSubmit", "Stop", "SessionStart", "PostToolUse", "claude-code"], "summary": "Develop Claude Code hooks with correct output formats and known bug workarounds", "dependencies": [], "lastUsed": null, "useCount": 0}
  ],
  "lastUpdated": "2026-01-21",
  "categories": ["meta", "setup", "api", "utility", "processing", "development"]
}
INDEX_EOF

cat > "$SKILLS_DIR/skill-index/SKILL.md" << 'SKILL_INDEX_MD_EOF'
---
name: skill-index
description: Index and discover available skills by category/tags. Use when looking for relevant skills, checking what skills exist, categorizing new skills, or finding skills by keyword/category.
---

# Skill Index - Discover and Search Skills

## How to Use

### 1. Check the Index
```bash
cat ~/.claude/skills/skill-index/index.json
```

### 2. Search by Category
Categories: meta, setup, api, debugging, database, utility, processing, development

### 3. Load Relevant Skill
```bash
cat ~/.claude/skills/{skill-name}/SKILL.md
```
SKILL_INDEX_MD_EOF

cat > "$SKILLS_DIR/skill-index/metadata.json" << 'META_EOF'
{"name": "skill-index", "category": "meta", "tags": ["discovery", "search", "index", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-index"

# Create remaining skills with their SKILL.md and metadata.json files
# skill-creator
mkdir -p "$SKILLS_DIR/skill-creator"
cat > "$SKILLS_DIR/skill-creator/SKILL.md" << 'SKILL_EOF'
---
name: skill-creator
description: Auto-detect learning moments and create reusable skills. Use when Claude has solved a problem after multiple attempts, discovered a non-obvious solution, or encountered and resolved unexpected errors.
---

# Skill Creator - Auto-Learning from Problem Solving

## Detection Criteria
Trigger skill creation when:
1. Multiple attempts to success (2+ approaches before working)
2. Non-obvious discovery (solution differs from documentation)
3. Knowledge worth preserving (3+ steps, critical syntax)

## Workflow
1. Offer to save: Present problem/solution/key insight
2. Handle response: yes/no/show me first/different name
3. Create skill: SKILL.md + metadata.json + update index
4. Confirm creation

## Skill Template
```markdown
---
name: {name}
description: {summary}. Use when {triggers}.
---

# {Title}

## Problem Pattern
{Description}

## Solution
{Steps}

## Key Insights
{Non-obvious parts}

## Commands/Code
{Exact commands}
```
SKILL_EOF
cat > "$SKILLS_DIR/skill-creator/metadata.json" << 'META_EOF'
{"name": "skill-creator", "category": "meta", "tags": ["learning", "skills", "automation", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-creator"

# skill-updater
mkdir -p "$SKILLS_DIR/skill-updater"
cat > "$SKILLS_DIR/skill-updater/SKILL.md" << 'SKILL_EOF'
---
name: skill-updater
description: Update skills when they fail or better solutions are found. Use when a skill was applied but didn't work, when you had to deviate from documented steps, or when an existing skill needs corrections.
---

# Skill Updater - Improving Skills When Solutions Fail

## Detection Criteria
Trigger when:
1. Skill failed - solution didn't work, found better one
2. Workaround used - skill worked but you deviated from docs

## Workflow
1. Identify the gap
2. Offer to update (show DOCUMENTED vs ACTUAL)
3. Handle response
4. Update skill + metadata + index
5. Verify all components in sync
SKILL_EOF
cat > "$SKILLS_DIR/skill-updater/metadata.json" << 'META_EOF'
{"name": "skill-updater", "category": "meta", "tags": ["learning", "skills", "maintenance", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-updater"

# skill-loader
mkdir -p "$SKILLS_DIR/skill-loader"
cat > "$SKILLS_DIR/skill-loader/SKILL.md" << 'SKILL_EOF'
---
name: skill-loader
description: Lazy-load skills to minimize context usage. Use when loading skills, managing context efficiency, or deciding what skill content to read.
---

# Skill Loader - Context-Efficient Skill Loading

## Loading Levels
1. **Level 1: Index Only** (~50 tokens) - Check index.json first
2. **Level 2: Core Content** (~500-2000 tokens) - Load SKILL.md when relevant
3. **Level 3: Extended** (optional) - Load examples.md/edge-cases.md if needed

## Best Practices
- Start with index for every lookup
- Only load one skill at a time
- Update usage stats after using a skill
- Run post-task learning check after completing tasks
SKILL_EOF
cat > "$SKILLS_DIR/skill-loader/metadata.json" << 'META_EOF'
{"name": "skill-loader", "category": "meta", "tags": ["loading", "context", "efficiency", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-loader"

# skill-health
mkdir -p "$SKILLS_DIR/skill-health"
cat > "$SKILLS_DIR/skill-health/SKILL.md" << 'SKILL_EOF'
---
name: skill-health
description: Track skill usage and identify skills needing updates. Use when reviewing skill quality, checking for stale skills, or analyzing skill effectiveness.
---

# Skill Health - Quality Tracking & Maintenance

## Health Indicators
| Indicator | Healthy | Warning | Action Needed |
|-----------|---------|---------|---------------|
| Last used | < 30 days | 30-90 days | > 90 days |
| Success rate | > 80% | 50-80% | < 50% |
| Version age | < 90 days | 90-180 days | > 180 days |

## Health Check Process
1. Gather data from all skill metadata.json
2. Analyze against indicators
3. Generate report with recommendations
SKILL_EOF
cat > "$SKILLS_DIR/skill-health/metadata.json" << 'META_EOF'
{"name": "skill-health", "category": "meta", "tags": ["tracking", "quality", "maintenance", "analytics", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-health"

# skill-improver
mkdir -p "$SKILLS_DIR/skill-improver"
cat > "$SKILLS_DIR/skill-improver/SKILL.md" << 'SKILL_EOF'
---
name: skill-improver
description: Proactively suggest skill improvements during usage. Use when a skill worked but could be better, when you notice gaps in skills, or when skills overlap significantly.
---

# Skill Improver - Proactive Improvement Suggestions

## Detection Triggers
1. Workaround not in skill
2. Missing information found
3. Skill overlap detected
4. Edge case hit
5. Deprecated approach detected

## Workflow
1. Detect opportunity during skill use
2. Present suggestion with template
3. Handle response (yes/no/show me)
4. Apply changes if approved
SKILL_EOF
cat > "$SKILLS_DIR/skill-improver/metadata.json" << 'META_EOF'
{"name": "skill-improver", "category": "meta", "tags": ["improvement", "proactive", "suggestions", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-improver"

# skill-tracker
mkdir -p "$SKILLS_DIR/skill-tracker"
cat > "$SKILLS_DIR/skill-tracker/SKILL.md" << 'SKILL_EOF'
---
name: skill-tracker
description: Automatically track skill usage, success, and failure. Use after loading any skill to update its useCount, after confirming a skill worked to update successCount, or when a skill fails to update failureCount.
---

# Skill Tracker - Automatic Usage Metrics

## Tracking Events
1. **Skill Loaded**: useCount++, lastUsed = today
2. **Skill Succeeded**: successCount++
3. **Skill Failed**: failureCount++
4. **Skill Updated**: version++, changelog entry

## Update Both
- metadata.json in skill directory
- index.json in skill-index
SKILL_EOF
cat > "$SKILLS_DIR/skill-tracker/metadata.json" << 'META_EOF'
{"name": "skill-tracker", "category": "meta", "tags": ["tracking", "metrics", "analytics", "automation", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-tracker"

# skill-validator
mkdir -p "$SKILLS_DIR/skill-validator"
cat > "$SKILLS_DIR/skill-validator/SKILL.md" << 'SKILL_EOF'
---
name: skill-validator
description: Validate skills still work by checking dependencies and examples. Use when reviewing skills, before major updates, or when a skill might be outdated.
---

# Skill Validator - Test If Skills Still Work

## Validation Types
1. **Dependency Check** (Safe) - Check if tools installed
2. **Syntax Check** (Safe) - Validate code without execution
3. **URL Check** (Safe) - Verify documentation URLs
4. **Example Execution** (Dangerous) - Run code examples (requires confirmation)

## Validation Report Format
- Dependencies: installed/missing
- Syntax: valid/warnings/errors
- URLs: reachable/redirects/broken
- Overall: VALID/NEEDS REVIEW/BROKEN
SKILL_EOF
cat > "$SKILLS_DIR/skill-validator/metadata.json" << 'META_EOF'
{"name": "skill-validator", "category": "meta", "tags": ["validation", "testing", "quality", "dependencies", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-validator"

# skill-matcher
mkdir -p "$SKILLS_DIR/skill-matcher"
cat > "$SKILLS_DIR/skill-matcher/SKILL.md" << 'SKILL_EOF'
---
name: skill-matcher
description: Smart skill discovery with scoring and proactive suggestions. Use when searching for relevant skills, suggesting skills proactively, or when no obvious skill match exists.
---

# Skill Matcher - Smart Skill Discovery

## Scoring Algorithm
| Match Type | Points |
|------------|--------|
| Exact tag match | +3 |
| Category match | +5 |
| Summary keyword | +2 |
| Description keyword | +1 |
| Recent use bonus | +1 |
| High success rate | +2 |

## Thresholds
- >= 10: Strong match - recommend confidently
- 5-9: Possible match - mention as option
- < 5: Weak match - suggest web-research
SKILL_EOF
cat > "$SKILLS_DIR/skill-matcher/metadata.json" << 'META_EOF'
{"name": "skill-matcher", "category": "meta", "tags": ["discovery", "matching", "search", "suggestions", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: skill-matcher"

# web-research
mkdir -p "$SKILLS_DIR/web-research"
cat > "$SKILLS_DIR/web-research/SKILL.md" << 'SKILL_EOF'
---
name: web-research
description: Fallback research when stuck after initial attempt fails. Use AFTER attempting a solution that failed, when encountering an unfamiliar error, or when existing skills don't cover the situation.
---

# Web Research - Fallback When Stuck

## Decision Flow
1. Check existing skills -> Use if match found
2. Try with existing knowledge -> Attempt solution
3. Hit a wall/error? -> NOW research
4. Still uncertain? -> Research specific gap

## DO research when:
- First attempt failed
- Genuinely unfamiliar
- Error you can't diagnose
- Version/breaking changes suspected

## DO NOT research when:
- Reasonably confident in approach
- An existing skill covers it
- It's fundamental knowledge
SKILL_EOF
cat > "$SKILLS_DIR/web-research/metadata.json" << 'META_EOF'
{"name": "web-research", "category": "meta", "tags": ["research", "web", "fallback", "troubleshooting"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: web-research"

# llm-api-tool-use
mkdir -p "$SKILLS_DIR/llm-api-tool-use"
cat > "$SKILLS_DIR/llm-api-tool-use/SKILL.md" << 'SKILL_EOF'
---
name: llm-api-tool-use
description: Claude API tool use with Python SDK. Use when building agents, adding function calling, creating tools for Claude, or working with the Anthropic API tool_use feature.
---

# Claude API Tool Use Implementation

## Two Approaches

### Approach 1: Tool Runner (Recommended)
```python
from anthropic import beta_tool

@beta_tool
def get_weather(location: str) -> str:
    """Get weather for location."""
    return json.dumps({"location": location, "temp": "72"})

runner = client.beta.messages.tool_runner(
    model="claude-sonnet-4-5-20250514",
    tools=[get_weather],
    messages=[{"role": "user", "content": "Weather in SF?"}]
)
```

### Approach 2: Manual Handling
Define tools with JSON schema, handle response loop manually.

## Key Concepts
- `stop_reason == "tool_use"` -> Claude wants to call tools
- `stop_reason == "end_turn"` -> Claude is done
- Tool results need `tool_use_id` matching the request
SKILL_EOF
cat > "$SKILLS_DIR/llm-api-tool-use/metadata.json" << 'META_EOF'
{"name": "llm-api-tool-use", "category": "api", "tags": ["anthropic", "llm", "tool-use", "python", "sdk", "agents"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: llm-api-tool-use"

# deno2-http-kv-server
mkdir -p "$SKILLS_DIR/deno2-http-kv-server"
cat > "$SKILLS_DIR/deno2-http-kv-server/SKILL.md" << 'SKILL_EOF'
---
name: deno2-http-kv-server
description: Deno 2 HTTP server with KV database. Use when creating web servers with Deno, using Deno.serve, working with Deno KV for persistence, or building APIs with Deno 2.
---

# Deno 2 HTTP Server with KV Database

## Basic Server
```typescript
Deno.serve({ port: 8000 }, (req: Request): Response => {
  return new Response("Hello from Deno 2!");
});
```

## With KV Database
```typescript
const kv = await Deno.openKv();
// Run with: deno run --allow-net --unstable-kv server.ts
```

## Key Insights
- No framework needed - Deno.serve is built-in
- KV requires --unstable-kv flag
- Keys are arrays like ["users", "123"]
- Use atomic operations for concurrent-safe counters
SKILL_EOF
cat > "$SKILLS_DIR/deno2-http-kv-server/metadata.json" << 'META_EOF'
{"name": "deno2-http-kv-server", "category": "setup", "tags": ["deno", "http", "kv", "database", "server", "typescript"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: deno2-http-kv-server"

# hono-bun-sqlite-api
mkdir -p "$SKILLS_DIR/hono-bun-sqlite-api"
cat > "$SKILLS_DIR/hono-bun-sqlite-api/SKILL.md" << 'SKILL_EOF'
---
name: hono-bun-sqlite-api
description: REST API with Hono, Bun and SQLite. Use when creating web APIs with Bun, using Hono framework, working with bun:sqlite, or building CRUD applications.
---

# Hono + Bun + SQLite API

## Quick Setup
```bash
mkdir my-api && cd my-api
bun init -y
bun add hono
```

## Key Insights
- No npm package for SQLite - use bun:sqlite built-in (3-6x faster)
- Synchronous API - no async/await for queries
- Export pattern: export default { port, fetch }
SKILL_EOF
cat > "$SKILLS_DIR/hono-bun-sqlite-api/metadata.json" << 'META_EOF'
{"name": "hono-bun-sqlite-api", "category": "setup", "tags": ["hono", "bun", "sqlite", "api", "rest", "typescript"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: hono-bun-sqlite-api"

# udcp
mkdir -p "$SKILLS_DIR/udcp"
cat > "$SKILLS_DIR/udcp/SKILL.md" << 'SKILL_EOF'
---
name: udcp
description: Update documentation, commit, and push in one command. Use when invoking /udcp or after making skill changes that need to be committed.
---

# /udcp - Update Documentation, Commit, Push

## Workflow
1. Sync skills from ~/.claude/skills to repo
2. Check what changed (git status/diff)
3. Update documentation if needed
4. Stage and commit with Co-Authored-By
5. Push
6. Confirm
SKILL_EOF
cat > "$SKILLS_DIR/udcp/metadata.json" << 'META_EOF'
{"name": "udcp", "category": "meta", "tags": ["git", "commit", "push", "documentation", "workflow", "meta-skill"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: udcp"

# markdown-to-pdf
mkdir -p "$SKILLS_DIR/markdown-to-pdf"
cat > "$SKILLS_DIR/markdown-to-pdf/SKILL.md" << 'SKILL_EOF'
---
name: markdown-to-pdf
description: Convert Markdown files to PDF on macOS. Use when user wants to create a PDF from markdown, export documentation, or generate printable docs.
---

# Markdown to PDF Conversion

## Solution
```bash
npx md-to-pdf your-file.md
```

## Key Insights
- md-to-pdf just works - uses Puppeteer/Chromium internally
- npx handles installation - no global install needed
- Supports GitHub-flavored markdown
SKILL_EOF
cat > "$SKILLS_DIR/markdown-to-pdf/metadata.json" << 'META_EOF'
{"name": "markdown-to-pdf", "category": "setup", "tags": ["markdown", "pdf", "documentation", "export", "macos"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: markdown-to-pdf"

# history
mkdir -p "$SKILLS_DIR/history"
cat > "$SKILLS_DIR/history/SKILL.md" << 'SKILL_EOF'
---
name: history
description: Search and retrieve past conversation history without filling context. Use when searching for past solutions, loading previous sessions, or checking what topics were discussed.
---

# History Skill

## Commands
- /history search <query> - Search current project
- /history search --all <query> - Search all projects
- /history load <session_id> - Load session content
- /history topics - List indexed topics
- /history recent - Show recent sessions
- /history rebuild - Force reindex
SKILL_EOF
cat > "$SKILLS_DIR/history/metadata.json" << 'META_EOF'
{"name": "history", "category": "utility", "tags": ["history", "search", "memory", "context", "sessions", "retrieval"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: history"

# rlm
mkdir -p "$SKILLS_DIR/rlm"
cat > "$SKILLS_DIR/rlm/SKILL.md" << 'SKILL_EOF'
---
name: rlm
description: Process documents/codebases larger than context window using chunking and subagents. Use when processing documents >50K characters, analyzing multiple files at once, or when large-input-detector hook suggests RLM.
---

# RLM: Reading Language Model for Large Documents

## Quick Start
```bash
python rlm_tools/probe.py input.txt
python rlm_tools/chunk.py input.txt --output rlm_context/chunks/
# Process chunks with subagents
python rlm_tools/aggregate.py rlm_context/results/
```

## When to Use
- < 50K chars: Direct processing
- 50K-150K: Consider RLM for complex queries
- > 150K: Use RLM (exceeds context)
- > 800K: Must use RLM
SKILL_EOF
cat > "$SKILLS_DIR/rlm/metadata.json" << 'META_EOF'
{"name": "rlm", "category": "processing", "tags": ["rlm", "large-documents", "chunking", "subagents", "aggregation", "context-overflow"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: rlm"

# hook-development
mkdir -p "$SKILLS_DIR/hook-development"
cat > "$SKILLS_DIR/hook-development/SKILL.md" << 'SKILL_EOF'
---
name: hook-development
description: Develop Claude Code hooks with correct output formats and known bug workarounds. Use when creating new hooks, debugging hook issues, or understanding hook events.
---

# Claude Code Hooks Development

## Hook Events
| Event | When | Use Cases |
|-------|------|-----------|
| UserPromptSubmit | Before processing message | Validation, context injection |
| PostToolUse | After tool executes | Logging, tracking |
| Stop | Before Claude finishes | Analysis, indexing |
| SessionStart | On session start/resume | State recovery |

## Critical: Output Rules
- Nothing to report: NO OUTPUT, just sys.exit(0)
- Has context: Output JSON with hookSpecificOutput.additionalContext
- Stop hooks use different schema: {"continue": true}
SKILL_EOF
cat > "$SKILLS_DIR/hook-development/metadata.json" << 'META_EOF'
{"name": "hook-development", "category": "development", "tags": ["hooks", "automation", "UserPromptSubmit", "Stop", "SessionStart", "PostToolUse", "claude-code"], "useCount": 0, "successCount": 0, "failureCount": 0, "lastUsed": null}
META_EOF
echo "  Created: hook-development"

# -------------------------------------------
# UPDATE SETTINGS.JSON
# -------------------------------------------
echo -e "${YELLOW}Updating settings.json...${NC}"

python3 << SETTINGS_SCRIPT
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")
hooks_dir = os.path.expanduser("~/.claude/hooks")

# Load existing or create new
settings = {}
if os.path.exists(settings_file):
    try:
        with open(settings_file, 'r') as f:
            settings = json.load(f)
    except:
        settings = {}

if "hooks" not in settings:
    settings["hooks"] = {}

# System C hooks
system_c_hooks = {
    "UserPromptSubmit": [
        {"hooks": [
            {"type": "command", "command": f"python3 {hooks_dir}/skill-matcher.py"},
            {"type": "command", "command": f"python3 {hooks_dir}/learning-moment-pickup.py"}
        ]}
    ],
    "PostToolUse": [
        {"matcher": "Read", "hooks": [
            {"type": "command", "command": f"python3 {hooks_dir}/skill-tracker.py"}
        ]}
    ],
    "Stop": [
        {"hooks": [
            {"type": "command", "command": f"python3 {hooks_dir}/detect-learning.py"}
        ]}
    ]
}

# Merge hooks
for event, event_hooks in system_c_hooks.items():
    if event not in settings["hooks"]:
        settings["hooks"][event] = []

    # Check if hook already exists
    for new_group in event_hooks:
        exists = False
        for existing in settings["hooks"][event]:
            if "hooks" in existing and "hooks" in new_group:
                for new_hook in new_group["hooks"]:
                    for old_hook in existing.get("hooks", []):
                        if new_hook.get("command", "") == old_hook.get("command", ""):
                            exists = True
                            break
        if not exists:
            settings["hooks"][event].append(new_group)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings updated with System C hooks")
SETTINGS_SCRIPT

# -------------------------------------------
# INSTALLATION SUMMARY
# -------------------------------------------
echo -e "${GREEN}"
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Installed:"
echo "  - 5 hooks (skill-matcher, skill-tracker, detect-learning,"
echo "             learning-moment-pickup, hook_logger)"
echo "  - 18 skills in $SKILLS_DIR"
echo ""
echo "Settings backup: $BACKUP_DIR"
echo ""
echo -e "${YELLOW}Restart Claude Code or run /hooks to reload hooks.${NC}"
echo ""
