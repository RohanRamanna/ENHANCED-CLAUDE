#!/bin/bash
#
# Enhanced Claude Installer
# =========================
# A standalone script to install Enhanced Claude's 5 systems:
#   1. Session Persistence (RLM-based)
#   2. RLM for Large Documents
#   3. Auto-Skills
#   4. Searchable History
#   5. Skills Library
#
# Usage:
#   ./enhanced-claude-install.sh              # Interactive mode
#   ./enhanced-claude-install.sh --global     # Install global components only
#   ./enhanced-claude-install.sh --project    # Install project components only
#   ./enhanced-claude-install.sh --check      # Check installation status
#
# Repository: https://github.com/RohanRamanna/ENHANCED-CLAUDE
#

set -e

# ============================================================================
# COLORS AND HELPERS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}======================================${NC}"
    echo -e "${CYAN}${BOLD}  Enhanced Claude Installer${NC}"
    echo -e "${CYAN}${BOLD}======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "----------------------------------------"
}

confirm() {
    read -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
HISTORY_DIR="$CLAUDE_DIR/history"
LOGS_DIR="$HOOKS_DIR/logs"

PROJECT_DIR="$(pwd)"

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"

    # Check Python 3
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_success "Python 3 found: $PYTHON_VERSION"
    else
        print_error "Python 3 not found. Please install Python 3.8 or later."
        exit 1
    fi

    # Check Claude Code (optional)
    if command -v claude &> /dev/null; then
        print_success "Claude Code CLI found"
    else
        print_warning "Claude Code CLI not found. Install from: https://claude.ai/code"
    fi
}

# ============================================================================
# EMBEDDED CONTENT: HOOKS
# ============================================================================

write_hook_logger() {
    cat > "$HOOKS_DIR/hook_logger.py" << 'HOOK_LOGGER_EOF'
#!/usr/bin/env python3
"""
Shared logging utility for Claude Code hooks.

Usage:
    from hook_logger import HookLogger
    logger = HookLogger("hook-name")
    logger.info("Processing started")
    logger.error("Something went wrong", exc_info=True)
"""

import os
import json
import traceback
from datetime import datetime
from pathlib import Path

# Log directory
LOG_DIR = Path(os.path.expanduser("~/.claude/hooks/logs"))

# Max log file size (1MB)
MAX_LOG_SIZE = 1_000_000

# Max log files to keep per hook
MAX_LOG_FILES = 3


class HookLogger:
    def __init__(self, hook_name: str):
        self.hook_name = hook_name
        self.log_dir = LOG_DIR
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.log_file = self.log_dir / f"{hook_name}.log"
        self._rotate_if_needed()

    def _rotate_if_needed(self):
        """Rotate log file if it exceeds max size."""
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
        """Write a log entry."""
        timestamp = datetime.now().isoformat()
        entry = {
            "timestamp": timestamp,
            "level": level,
            "hook": self.hook_name,
            "message": message
        }
        if kwargs.get("exc_info"):
            entry["traceback"] = traceback.format_exc()
        if kwargs.get("data"):
            entry["data"] = kwargs["data"]
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass

    def debug(self, message: str, **kwargs):
        self._write("DEBUG", message, **kwargs)

    def info(self, message: str, **kwargs):
        self._write("INFO", message, **kwargs)

    def warning(self, message: str, **kwargs):
        self._write("WARNING", message, **kwargs)

    def error(self, message: str, **kwargs):
        self._write("ERROR", message, **kwargs)

    def log_input(self, hook_input: dict):
        """Log the hook input (sanitized)."""
        sanitized = {
            "prompt_length": len(hook_input.get("prompt", "")),
            "prompt_preview": hook_input.get("prompt", "")[:100],
            "cwd": hook_input.get("cwd", ""),
            "has_transcript": bool(hook_input.get("transcript_path")),
        }
        self.debug("Hook input received", data=sanitized)

    def log_output(self, output: dict):
        """Log the hook output."""
        self.debug("Hook output", data=output)
HOOK_LOGGER_EOF
}

write_skill_matcher() {
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
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
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
            print(json.dumps(output))

    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
SKILL_MATCHER_EOF
}

write_large_input_detector() {
    cat > "$HOOKS_DIR/large-input-detector.py" << 'LARGE_INPUT_EOF'
#!/usr/bin/env python3
"""
Large Input Detector Hook - UserPromptSubmit
Detects large user inputs and suggests RLM workflow.
"""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("large-input-detector")

SUGGEST_RLM_THRESHOLD = 50000
STRONG_RLM_THRESHOLD = 150000
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

def estimate_tokens(text):
    return len(text) // 4

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    prompt = hook_input.get("prompt", "")
    if not prompt:
        sys.exit(0)

    char_count = len(prompt)
    token_estimate = estimate_tokens(prompt)

    if char_count >= STRONG_RLM_THRESHOLD:
        message = f"""[LARGE INPUT DETECTED - RLM RECOMMENDED]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)
This exceeds comfortable context limits.

RECOMMENDED: Use RLM (Recursive Language Model) workflow:
1. Save input to file: rlm_context/input.txt
2. Probe structure: python rlm_tools/probe.py rlm_context/input.txt
3. Chunk: python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
4. Process chunks with parallel Task subagents
5. Aggregate: python rlm_tools/aggregate.py rlm_context/results/"""
    elif char_count >= SUGGEST_RLM_THRESHOLD:
        project_dir = hook_input.get("cwd", PROJECT_DIR)
        message = f"""[LARGE INPUT NOTICE]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)

Consider using RLM workflow if you need comprehensive analysis:
- RLM tools available in: {project_dir}/rlm_tools/
- Run: python rlm_tools/probe.py <file> to analyze structure"""
    else:
        sys.exit(0)

    output = {"hookSpecificOutput": {"additionalContext": message}}
    logger.log_output(output)
    print(json.dumps(output))
    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
LARGE_INPUT_EOF
}

write_history_search() {
    cat > "$HOOKS_DIR/history-search.py" << 'HISTORY_SEARCH_EOF'
#!/usr/bin/env python3
"""
History Search Hook - UserPromptSubmit
Suggests relevant past conversation segments based on user prompts.
"""

import json
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("history-search")

INDEX_PATH = os.path.expanduser("~/.claude/history/index.json")
MIN_SCORE_THRESHOLD = 8
COMMON_WORDS = {
    "a", "an", "the", "with", "and", "or", "for", "to", "in", "on", "by",
    "is", "are", "was", "were", "be", "been", "being", "have", "has", "had",
    "do", "does", "did", "will", "would", "could", "should", "may", "might",
    "this", "that", "these", "those", "it", "its", "i", "me", "my", "you",
    "your", "we", "our", "they", "them", "their", "what", "which", "who",
    "how", "when", "where", "why", "can", "help", "want", "need", "please",
    "make", "create", "add", "use", "using", "get", "set", "new", "file"
}

def load_index():
    try:
        with open(INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"sessions": {}, "topics": {}}

def normalize_project_path(cwd):
    if not cwd:
        return None
    normalized = cwd.replace("/", "-").replace(" ", "-")
    if not normalized.startswith("-"):
        normalized = "-" + normalized
    return normalized

def score_session(session, prompt_words, topics_index):
    score = 0
    matching_topics = []
    session_topics = set(session.get("topics", []))
    session_files = set(session.get("files_touched", []))

    for topic in session_topics:
        topic_lower = topic.lower()
        if topic_lower in prompt_words:
            score += 4
            matching_topics.append(topic)
        else:
            topic_words = set(topic_lower.replace("-", " ").replace("_", " ").split())
            matches = topic_words & prompt_words
            meaningful_matches = matches - COMMON_WORDS
            if meaningful_matches:
                score += len(meaningful_matches) * 2
                matching_topics.append(topic)

    for file_path in session_files:
        file_name = os.path.basename(file_path).lower()
        file_base = file_name.split('.')[0]
        if file_base in prompt_words and len(file_base) > 2:
            score += 3

    session_date = session.get("date", "")
    if session_date:
        try:
            date_obj = datetime.strptime(session_date, "%Y-%m-%d")
            days_ago = (datetime.now() - date_obj).days
            if days_ago <= 7:
                score += 2
            elif days_ago <= 30:
                score += 1
        except ValueError:
            pass

    return score, matching_topics[:5]

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    prompt = hook_input.get("prompt", "")
    cwd = hook_input.get("cwd", "")

    if not prompt or len(prompt) < 10:
        sys.exit(0)

    prompt_lower = prompt.lower()
    prompt_words = set(prompt_lower.replace("-", " ").replace("_", " ").split())
    meaningful_words = prompt_words - COMMON_WORDS

    if len(meaningful_words) < 2:
        sys.exit(0)

    index = load_index()
    sessions = index.get("sessions", {})

    if not sessions:
        sys.exit(0)

    current_project = normalize_project_path(cwd)

    scored_sessions = []
    for session_id, session in sessions.items():
        if current_project and session.get("project") != current_project:
            continue
        score, matching_topics = score_session(session, meaningful_words, index.get("topics", {}))
        if score >= MIN_SCORE_THRESHOLD:
            scored_sessions.append({
                "score": score,
                "session_id": session_id,
                "date": session.get("date", "unknown"),
                "topics": matching_topics,
                "line_count": session.get("line_count", 0),
            })

    scored_sessions.sort(key=lambda x: x["score"], reverse=True)

    if scored_sessions:
        top_matches = scored_sessions[:3]
        lines = ["[HISTORY MATCH] Found relevant past work in this project:"]
        for match in top_matches:
            session_id_short = match["session_id"][:8]
            topics_str = ", ".join(match["topics"][:3]) if match["topics"] else "various"
            lines.append(f"  - {match['date']}: {topics_str} (score:{match['score']}, {match['line_count']} lines)")
            lines.append(f"    Load: /history load {session_id_short}")
        lines.append("")
        lines.append("Use /history search <query> for more options.")
        output = {"hookSpecificOutput": {"additionalContext": "\n".join(lines)}}
        logger.log_output(output)
        print(json.dumps(output))

    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
HISTORY_SEARCH_EOF
}

write_skill_tracker() {
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
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
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
}

write_detect_learning() {
    cat > "$HOOKS_DIR/detect-learning.py" << 'DETECT_LEARNING_EOF'
#!/usr/bin/env python3
"""
Learning Detection Hook - Stop
Detects trial-and-error learning moments and suggests skill creation.
"""

import json
import sys
import os
import re

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
        error_patterns = [
            r'error:', r'Error:', r'ERROR', r'failed', r'Failed', r'FAILED',
            r'exception', r'Exception', r'not found', r'No such file',
            r'Permission denied', r'command not found', r'ModuleNotFoundError',
            r'ImportError', r'SyntaxError', r'TypeError', r'ValueError', r'exit code [1-9]',
        ]
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
    trial_error_patterns = [
        r'let me try', r'trying again', r'another approach', r'different approach',
        r'turns out', r'the issue was', r'the problem was', r'that didn\'t work',
        r'that failed', r'I\'ll try', r'attempting', r'workaround',
    ]
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
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    messages = load_transcript(transcript_path)
    if len(messages) < 5:
        sys.exit(0)

    is_learning_moment, reason = should_trigger_learning_moment(messages)

    if is_learning_moment:
        logger.info(f"Learning moment detected: {reason}")
        output = {
            "continue": True,
            "systemMessage": f"""[LEARNING MOMENT DETECTED]
{reason}

You solved a problem through trial-and-error. Consider saving this as a reusable skill:
1. Run /skill-creator to document the solution
2. Or add to insights.md for future reference

This helps avoid re-discovering the same solution later."""
        }
        print(json.dumps(output))

    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
DETECT_LEARNING_EOF
}

write_history_indexer() {
    cat > "$HOOKS_DIR/history-indexer.py" << 'HISTORY_INDEXER_EOF'
#!/usr/bin/env python3
"""
History Indexer Hook - Stop
Builds searchable index of conversation history without duplicating data.
"""

import json
import sys
import os
import re
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("history-indexer")

HISTORY_DIR = os.path.expanduser("~/.claude/history")
INDEX_PATH = os.path.join(HISTORY_DIR, "index.json")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

DOMAIN_KEYWORDS = {
    "authentication", "auth", "login", "logout", "jwt", "oauth", "session",
    "database", "sql", "postgres", "mysql", "sqlite", "mongodb", "redis",
    "api", "rest", "graphql", "endpoint", "route", "http", "request",
    "hooks", "automation", "script", "cron", "scheduled",
    "rlm", "chunking", "context", "memory", "persistence",
    "skills", "skill", "learning", "pattern",
    "testing", "test", "jest", "pytest", "unittest",
    "deployment", "deploy", "docker", "kubernetes", "ci", "cd",
    "error", "bug", "fix", "debug", "troubleshoot",
    "refactor", "optimize", "performance", "cache",
    "ui", "frontend", "react", "vue", "component",
    "backend", "server", "node", "python", "deno", "bun",
}

def ensure_history_dir():
    os.makedirs(HISTORY_DIR, exist_ok=True)

def load_index():
    try:
        with open(INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"version": 1, "last_indexed": None, "sessions": {}, "topics": {}}

def save_index(index):
    ensure_history_dir()
    index["last_indexed"] = datetime.now().isoformat()
    with open(INDEX_PATH, 'w') as f:
        json.dump(index, f, indent=2)

def find_session_files():
    sessions = []
    if not os.path.exists(PROJECTS_DIR):
        return sessions
    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir() or project_dir.name.startswith('.'):
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            if "subagents" in str(jsonl_file):
                continue
            sessions.append({
                "path": str(jsonl_file),
                "project": project_dir.name,
                "session_id": jsonl_file.stem
            })
    return sessions

def extract_topics_from_content(content):
    topics = set()
    content_lower = content.lower()
    for keyword in DOMAIN_KEYWORDS:
        if keyword in content_lower:
            topics.add(keyword)
    files = re.findall(r'["\']([^"\']+\.(py|ts|js|md|json|tsx|jsx|css|html))["\']', content)
    for file_path, _ in files:
        base = os.path.basename(file_path).split('.')[0]
        if len(base) > 2:
            topics.add(base.lower())
    return topics

def index_session(session_info):
    path = session_info["path"]
    try:
        with open(path, 'r') as f:
            lines = f.readlines()
    except (FileNotFoundError, IOError):
        return None

    all_topics = set()
    tools_used = {}
    date = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        if not date and msg.get("timestamp"):
            ts = msg.get("timestamp", "")
            if isinstance(ts, str) and "T" in ts:
                date = ts.split("T")[0]

        if msg.get("type") == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str):
                all_topics.update(extract_topics_from_content(content))

        if msg.get("type") == "assistant":
            content_list = msg.get("message", {}).get("content", [])
            if isinstance(content_list, list):
                for item in content_list:
                    if isinstance(item, dict) and item.get("type") == "tool_use":
                        tool_name = item.get("name", "unknown")
                        tools_used[tool_name] = tools_used.get(tool_name, 0) + 1

    return {
        "id": session_info["session_id"],
        "project": session_info["project"],
        "file": path,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "line_count": len(lines),
        "topics": list(all_topics)[:30],
        "tools_used": dict(sorted(tools_used.items(), key=lambda x: x[1], reverse=True)[:10])
    }

def build_topic_index(sessions_dict):
    topics = {}
    for session_id, session in sessions_dict.items():
        project = session.get("project", "")
        for topic in session.get("topics", []):
            if topic not in topics:
                topics[topic] = []
            topics[topic].append({
                "session": session_id,
                "project": project,
                "date": session.get("date", "")
            })
    for topic in topics:
        topics[topic].sort(key=lambda x: x.get("date", ""), reverse=True)
    return topics

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    try:
        index = load_index()
        existing_sessions = set(index.get("sessions", {}).keys())
    except Exception as e:
        logger.error(f"Error loading index: {e}", exc_info=True)
        sys.exit(0)

    session_files = find_session_files()

    new_sessions = 0
    for session_info in session_files:
        session_id = session_info["session_id"]
        path = session_info["path"]
        if session_id in existing_sessions:
            existing = index["sessions"].get(session_id, {})
            try:
                current_lines = sum(1 for _ in open(path))
                if current_lines <= existing.get("line_count", 0):
                    continue
            except:
                continue

        session_entry = index_session(session_info)
        if session_entry:
            index["sessions"][session_id] = session_entry
            new_sessions += 1

    if new_sessions > 0:
        index["topics"] = build_topic_index(index["sessions"])
        save_index(index)
        logger.info(f"Indexed {new_sessions} new sessions")

    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
HISTORY_INDEXER_EOF
}

write_live_session_indexer() {
    cat > "$HOOKS_DIR/live-session-indexer.py" << 'LIVE_SESSION_EOF'
#!/usr/bin/env python3
"""
Live Session Indexer Hook - Stop
Chunks the current session into semantic segments for intelligent recovery.
"""

import json
import sys
import os
import re
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("live-session-indexer")

SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

MIN_SEGMENT_LINES = 10
MAX_SEGMENT_LINES = 100
TIME_GAP_MINUTES = 5

DOMAIN_KEYWORDS = {
    "authentication", "auth", "login", "oauth", "jwt", "session",
    "database", "sql", "postgres", "mysql", "sqlite", "mongodb",
    "api", "rest", "graphql", "endpoint", "route", "http",
    "hooks", "automation", "script", "cron",
    "rlm", "chunking", "context", "memory", "persistence",
    "skills", "skill", "learning", "pattern",
    "testing", "test", "jest", "pytest",
    "deployment", "deploy", "docker", "kubernetes",
    "error", "bug", "fix", "debug",
    "refactor", "optimize", "performance",
    "ui", "frontend", "react", "vue",
    "backend", "server", "node", "python", "deno", "bun",
}

def ensure_dirs(session_id):
    session_dir = os.path.join(SESSIONS_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)
    return session_dir

def load_segment_index(session_dir):
    index_path = os.path.join(session_dir, "segments.json")
    try:
        with open(index_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "version": 1, "session_id": None, "project": None,
            "jsonl_file": None, "last_indexed_line": 0,
            "segments": [], "active_segment": None
        }

def save_segment_index(session_dir, index):
    index_path = os.path.join(session_dir, "segments.json")
    index["last_updated"] = datetime.now().isoformat()
    with open(index_path, 'w') as f:
        json.dump(index, f, indent=2)

def find_current_session():
    if not os.path.exists(PROJECTS_DIR):
        return None
    best_match = None
    best_time = 0
    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir() or project_dir.name.startswith('.'):
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            if "subagents" in str(jsonl_file):
                continue
            mtime = jsonl_file.stat().st_mtime
            if mtime > best_time:
                best_time = mtime
                best_match = {
                    "path": str(jsonl_file),
                    "project": project_dir.name,
                    "session_id": jsonl_file.stem
                }
    return best_match

def extract_topics(content):
    topics = set()
    content_lower = content.lower() if content else ""
    for keyword in DOMAIN_KEYWORDS:
        if keyword in content_lower:
            topics.add(keyword)
    return topics

def is_segment_boundary(current_msg, prev_msg, line_count):
    if line_count >= MAX_SEGMENT_LINES:
        return True, "max_lines"
    if line_count < MIN_SEGMENT_LINES:
        return False, None

    if current_msg.get("type") == "assistant":
        content_list = current_msg.get("message", {}).get("content", [])
        if isinstance(content_list, list):
            for item in content_list:
                if isinstance(item, dict) and item.get("type") == "tool_use":
                    if item.get("name") == "TodoWrite":
                        tool_input = item.get("input", {})
                        todos = tool_input.get("todos", [])
                        for todo in todos:
                            if todo.get("status") == "completed":
                                return True, "task_completed"

    if current_msg.get("type") == "user" and prev_msg and prev_msg.get("type") == "assistant":
        curr_content = current_msg.get("message", {}).get("content", "")
        if isinstance(curr_content, str) and len(curr_content) > 50:
            return True, "new_topic"

    return False, None

def create_segment_summary(messages):
    topics = set()
    tools = {}
    for msg in messages:
        msg_type = msg.get("type")
        if msg_type == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str):
                topics.update(extract_topics(content))
        elif msg_type == "assistant":
            content_list = msg.get("message", {}).get("content", [])
            if isinstance(content_list, list):
                for item in content_list:
                    if isinstance(item, dict):
                        if item.get("type") == "text":
                            topics.update(extract_topics(item.get("text", "")))
                        elif item.get("type") == "tool_use":
                            tool_name = item.get("name", "unknown")
                            tools[tool_name] = tools.get(tool_name, 0) + 1

    summary_parts = []
    if topics:
        summary_parts.append(f"Topics: {', '.join(list(topics)[:5])}")
    if tools:
        top_tools = sorted(tools.items(), key=lambda x: x[1], reverse=True)[:3]
        summary_parts.append(f"Tools: {', '.join([t[0] for t in top_tools])}")

    return {
        "topics": list(topics)[:10],
        "tools_used": dict(sorted(tools.items(), key=lambda x: x[1], reverse=True)[:5]),
        "summary": " | ".join(summary_parts) if summary_parts else "General discussion"
    }

def index_session(session_info, existing_index):
    path = session_info["path"]
    session_id = session_info["session_id"]

    try:
        with open(path, 'r') as f:
            lines = f.readlines()
    except (FileNotFoundError, IOError):
        return existing_index

    start_line = existing_index.get("last_indexed_line", 0)
    if start_line >= len(lines):
        return existing_index

    existing_index["session_id"] = session_id
    existing_index["project"] = session_info["project"]
    existing_index["jsonl_file"] = path

    segments = existing_index.get("segments", [])
    active_segment = existing_index.get("active_segment")

    if active_segment is None:
        active_segment = {
            "segment_id": f"seg-{len(segments):03d}",
            "start_line": start_line,
            "messages": [],
            "line_count": 0
        }

    prev_msg = None
    for i in range(start_line, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        if msg.get("type") in ["file-history-snapshot", "summary"]:
            continue

        is_boundary, boundary_type = is_segment_boundary(msg, prev_msg, active_segment["line_count"])

        if is_boundary and active_segment["messages"]:
            segment_data = create_segment_summary(active_segment["messages"])
            segment_entry = {
                "segment_id": active_segment["segment_id"],
                "start_line": active_segment["start_line"],
                "end_line": i - 1,
                "line_count": active_segment["line_count"],
                "boundary_type": boundary_type,
                **segment_data
            }
            first_msg = active_segment["messages"][0]
            segment_entry["timestamp"] = first_msg.get("timestamp", datetime.now().isoformat())
            segments.append(segment_entry)

            active_segment = {
                "segment_id": f"seg-{len(segments):03d}",
                "start_line": i,
                "messages": [],
                "line_count": 0
            }

        active_segment["messages"].append(msg)
        active_segment["line_count"] += 1
        prev_msg = msg

    existing_index["segments"] = segments
    existing_index["active_segment"] = {
        "segment_id": active_segment["segment_id"],
        "start_line": active_segment["start_line"],
        "line_count": active_segment["line_count"]
    }
    existing_index["last_indexed_line"] = len(lines)
    existing_index["total_segments"] = len(segments)

    return existing_index

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    try:
        session_info = find_current_session()
        if not session_info:
            sys.exit(0)
    except Exception as e:
        logger.error(f"Error finding session: {e}", exc_info=True)
        sys.exit(0)

    session_id = session_info["session_id"]
    session_dir = ensure_dirs(session_id)
    existing_index = load_segment_index(session_dir)

    try:
        updated_index = index_session(session_info, existing_index)
        save_segment_index(session_dir, updated_index)
    except Exception as e:
        logger.error(f"Error indexing session: {e}", exc_info=True)

    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
LIVE_SESSION_EOF
}

write_session_recovery() {
    cat > "$HOOKS_DIR/session-recovery.py" << 'SESSION_RECOVERY_EOF'
#!/usr/bin/env python3
"""
Session Recovery Hook - SessionStart
RLM-based intelligent session recovery after context compaction.
"""

import json
import sys
import os
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("session-recovery")

PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

PERSISTENCE_FILES = [
    ("context.md", "Current Goal & Decisions"),
    ("todos.md", "Task Progress"),
    ("insights.md", "Accumulated Learnings"),
]

SEGMENT_CONTEXT_BUDGET = 8000

def read_file_safe(filepath):
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except (FileNotFoundError, IOError):
        return ""

def find_current_session():
    if not os.path.exists(PROJECTS_DIR):
        return None
    best_match = None
    best_time = 0
    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir() or project_dir.name.startswith('.'):
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            if "subagents" in str(jsonl_file):
                continue
            mtime = jsonl_file.stat().st_mtime
            if mtime > best_time:
                best_time = mtime
                best_match = {
                    "path": str(jsonl_file),
                    "project": project_dir.name,
                    "session_id": jsonl_file.stem
                }
    return best_match

def load_segment_index(session_id):
    index_path = os.path.join(SESSIONS_DIR, session_id, "segments.json")
    try:
        with open(index_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def extract_pending_todos(todos_content):
    pending = []
    in_pending = False
    for line in todos_content.split('\n'):
        if '## In Progress' in line or '## Pending' in line:
            in_pending = True
            continue
        if in_pending and line.startswith('## '):
            in_pending = False
        if in_pending and line.strip().startswith('- [ ]'):
            todo_text = line.replace('- [ ]', '').strip()
            if todo_text:
                pending.append(todo_text.lower())
    return pending

def score_segment(segment, pending_todos, now):
    score = 0
    try:
        ts_str = segment.get("timestamp", "")
        if ts_str:
            ts_str = ts_str.replace('Z', '').split('.')[0]
            segment_time = datetime.fromisoformat(ts_str)
            hours_ago = (now - segment_time).total_seconds() / 3600
            recency_score = max(0, 50 - (hours_ago * 5))
            score += recency_score
    except:
        pass

    topics = set(t.lower() for t in segment.get("topics", []))
    for todo in pending_todos:
        todo_words = set(todo.split())
        matching_topics = topics.intersection(todo_words)
        score += len(matching_topics) * 10

    if segment.get("decisions"):
        score += 10

    tools = segment.get("tools_used", {})
    if "Edit" in tools or "Write" in tools:
        score += 15
    if "TodoWrite" in tools:
        score += 5

    boundary = segment.get("boundary_type", "")
    if boundary == "task_completed":
        score += 10
    elif boundary == "new_topic":
        score += 5

    return score

def extract_segment_content(jsonl_path, start_line, end_line):
    content_parts = []
    try:
        with open(jsonl_path, 'r') as f:
            lines = f.readlines()
    except (FileNotFoundError, IOError):
        return ""

    for i in range(start_line, min(end_line + 1, len(lines))):
        line = lines[i].strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = msg.get("type")
        if msg_type == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str) and content.strip():
                content_parts.append(f"USER: {content[:500]}")
        elif msg_type == "assistant":
            content_list = msg.get("message", {}).get("content", [])
            if isinstance(content_list, list):
                for item in content_list:
                    if isinstance(item, dict):
                        if item.get("type") == "text":
                            text = item.get("text", "")
                            if text.strip():
                                content_parts.append(f"ASSISTANT: {text[:500]}")
                        elif item.get("type") == "tool_use":
                            tool_name = item.get("name", "")
                            tool_input = item.get("input", {})
                            if tool_name in ["Edit", "Write"]:
                                file_path = tool_input.get("file_path", "")
                                content_parts.append(f"[Modified: {os.path.basename(file_path)}]")
                            elif tool_name == "TodoWrite":
                                todos = tool_input.get("todos", [])
                                completed = [t.get("content", "") for t in todos if t.get("status") == "completed"]
                                in_progress = [t.get("content", "") for t in todos if t.get("status") == "in_progress"]
                                if completed:
                                    content_parts.append(f"[Completed: {', '.join(completed[:3])}]")
                                if in_progress:
                                    content_parts.append(f"[Working on: {', '.join(in_progress[:2])}]")

    return "\n".join(content_parts)

def select_best_segments(segments, pending_todos, jsonl_path, budget):
    if not segments:
        return []
    now = datetime.now()
    scored = [(score_segment(seg, pending_todos, now), seg) for seg in segments]
    scored.sort(key=lambda x: x[0], reverse=True)

    selected = []
    total_chars = 0

    for score, seg in scored:
        line_count = seg.get("line_count", 0)
        estimated_chars = line_count * 100
        if total_chars + estimated_chars > budget:
            continue
        content = extract_segment_content(jsonl_path, seg.get("start_line", 0), seg.get("end_line", 0))
        if content:
            total_chars += len(content)
            selected.append({
                "segment_id": seg.get("segment_id"),
                "score": score,
                "topics": seg.get("topics", []),
                "summary": seg.get("summary", ""),
                "content": content
            })
        if total_chars >= budget:
            break

    return selected

def build_recovery_context():
    sections = []
    sections.append("=" * 70)
    sections.append("SESSION RECOVERED - RLM-based intelligent context loading")
    sections.append("=" * 70)

    files_found = 0
    todos_content = ""

    for filename, description in PERSISTENCE_FILES:
        filepath = os.path.join(PROJECT_DIR, filename)
        content = read_file_safe(filepath)
        if content.strip():
            files_found += 1
            sections.append(f"\n### {description} ({filename})\n")
            if len(content) > 2500:
                content = content[:2500] + "\n... [truncated]"
            sections.append(content)
            if filename == "todos.md":
                todos_content = content

    session_info = find_current_session()
    if session_info:
        segment_index = load_segment_index(session_info["session_id"])
        if segment_index and segment_index.get("segments"):
            pending_todos = extract_pending_todos(todos_content)
            selected_segments = select_best_segments(
                segment_index["segments"],
                pending_todos,
                segment_index.get("jsonl_file", session_info["path"]),
                SEGMENT_CONTEXT_BUDGET
            )
            if selected_segments:
                sections.append("\n" + "=" * 70)
                sections.append("RELEVANT CONVERSATION CONTEXT (RLM-recovered)")
                sections.append("=" * 70)
                for seg in selected_segments:
                    sections.append(f"\n--- Segment {seg['segment_id']} (score: {seg['score']:.0f}) ---")
                    sections.append(f"Topics: {', '.join(seg['topics'][:5])}")
                    sections.append(f"Summary: {seg['summary']}")
                    sections.append("\nConversation excerpt:")
                    sections.append(seg['content'])
                sections.append(f"\n[Loaded {len(selected_segments)} relevant segments from session history]")

    if files_found > 0:
        sections.append("\n" + "=" * 70)
        sections.append("Continue where you left off. Context has been intelligently restored.")
        sections.append("Update persistence files (context.md, todos.md, insights.md) as you work.")
        sections.append("=" * 70)
    else:
        sections.append("\nNo persistence files found. This may be a fresh session.")

    return "\n".join(sections)

def main():
    global PROJECT_DIR
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
        if hook_input.get("cwd"):
            PROJECT_DIR = hook_input["cwd"]
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(0)

    try:
        recovery_context = build_recovery_context()
    except Exception as e:
        logger.error(f"Error building recovery context: {e}", exc_info=True)
        sys.exit(0)

    output = {"hookSpecificOutput": {"additionalContext": recovery_context}}
    print(json.dumps(output))
    logger.info("Hook completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
SESSION_RECOVERY_EOF
}

# ============================================================================
# EMBEDDED CONTENT: SETTINGS
# ============================================================================

write_settings() {
    cat > "$CLAUDE_DIR/settings.json" << 'SETTINGS_EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/skill-matcher.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/large-input-detector.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/history-search.py"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/skill-tracker.py"}
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/detect-learning.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/history-indexer.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/live-session-indexer.py"}
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/session-recovery.py"}
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/session-recovery.py"}
        ]
      }
    ]
  }
}
SETTINGS_EOF
}

# ============================================================================
# EMBEDDED CONTENT: SKILL INDEX
# ============================================================================

write_skill_index() {
    mkdir -p "$SKILLS_DIR/skill-index"
    cat > "$SKILLS_DIR/skill-index/index.json" << 'SKILL_INDEX_EOF'
{
  "skills": [
    {"name": "skill-creator", "category": "meta", "tags": ["learning", "skills", "automation"], "summary": "Auto-detect learning moments and create reusable skills", "useCount": 0},
    {"name": "skill-updater", "category": "meta", "tags": ["learning", "skills", "maintenance"], "summary": "Update skills when they fail and better solutions found", "useCount": 0},
    {"name": "web-research", "category": "meta", "tags": ["research", "web", "fallback"], "summary": "Fallback research when stuck after initial attempt fails", "useCount": 0},
    {"name": "llm-api-tool-use", "category": "api", "tags": ["anthropic", "llm", "tool-use", "python"], "summary": "Claude API tool use with Python SDK", "useCount": 0},
    {"name": "deno2-http-kv-server", "category": "setup", "tags": ["deno", "http", "kv", "database"], "summary": "Deno 2 HTTP server with KV database", "useCount": 0},
    {"name": "hono-bun-sqlite-api", "category": "setup", "tags": ["hono", "bun", "sqlite", "api", "rest"], "summary": "REST API with Hono, Bun and SQLite", "useCount": 0},
    {"name": "skill-index", "category": "meta", "tags": ["discovery", "search", "index"], "summary": "Index and discover available skills by category/tags", "useCount": 0},
    {"name": "skill-loader", "category": "meta", "tags": ["loading", "context", "efficiency"], "summary": "Lazy-load skills to minimize context usage", "useCount": 0},
    {"name": "skill-health", "category": "meta", "tags": ["tracking", "quality", "maintenance"], "summary": "Track skill usage and identify skills needing updates", "useCount": 0},
    {"name": "skill-improver", "category": "meta", "tags": ["improvement", "proactive", "suggestions"], "summary": "Proactively suggest skill improvements during usage", "useCount": 0},
    {"name": "skill-tracker", "category": "meta", "tags": ["tracking", "metrics", "analytics"], "summary": "Automatically track skill usage, success, and failure", "useCount": 0},
    {"name": "skill-validator", "category": "meta", "tags": ["validation", "testing", "quality"], "summary": "Validate skills still work by checking dependencies", "useCount": 0},
    {"name": "skill-matcher", "category": "meta", "tags": ["discovery", "matching", "search"], "summary": "Smart skill discovery with scoring and proactive suggestions", "useCount": 0},
    {"name": "udcp", "category": "meta", "tags": ["git", "commit", "push", "documentation"], "summary": "Update documentation, commit, and push in one command", "useCount": 0},
    {"name": "markdown-to-pdf", "category": "setup", "tags": ["markdown", "pdf", "documentation"], "summary": "Convert Markdown files to PDF on macOS without LaTeX", "useCount": 0},
    {"name": "history", "category": "utility", "tags": ["history", "search", "memory", "context"], "summary": "Search and retrieve past conversation history", "useCount": 0},
    {"name": "rlm", "category": "processing", "tags": ["rlm", "large-documents", "chunking", "subagents"], "summary": "Process documents/codebases larger than context window", "useCount": 0}
  ],
  "lastUpdated": "2026-01-19",
  "categories": ["meta", "setup", "api", "utility", "processing"]
}
SKILL_INDEX_EOF

    cat > "$SKILLS_DIR/skill-index/SKILL.md" << 'SKILL_INDEX_MD_EOF'
# Skill Index

Central index of all available skills. Use for discovering skills by category or tags.

## Usage

```bash
# View all skills
cat ~/.claude/skills/skill-index/index.json | jq '.skills[] | {name, summary}'

# Find skills by tag
cat ~/.claude/skills/skill-index/index.json | jq '.skills[] | select(.tags | contains(["api"]))'
```

## Categories

- **meta**: Skills about skills (creation, tracking, matching)
- **setup**: Project setup templates
- **api**: API integrations
- **utility**: General utilities
- **processing**: Data/document processing
SKILL_INDEX_MD_EOF

    cat > "$SKILLS_DIR/skill-index/metadata.json" << 'SKILL_INDEX_META_EOF'
{"useCount": 0, "successCount": 0, "failureCount": 0}
SKILL_INDEX_META_EOF
}

# ============================================================================
# EMBEDDED CONTENT: PERSISTENCE TEMPLATES
# ============================================================================

write_persistence_templates() {
    local today=$(date +%Y-%m-%d)

    cat > "$PROJECT_DIR/context.md" << EOF
# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Automatically injected by \`session-recovery.py\` hook.

## Current Goal

[Describe your current goal here]

## Key Decisions Made

*None yet*

## Important Files

| File | Purpose |
|------|---------|
| \`context.md\` | This file - current goal |
| \`todos.md\` | Task tracking |
| \`insights.md\` | Accumulated learnings |

---

**Last Updated**: $today
EOF

    cat > "$PROJECT_DIR/todos.md" << EOF
# Todos

> **Purpose**: Track task progress across session compaction. Automatically injected by \`session-recovery.py\` hook.

## In Progress

*No tasks currently in progress*

## Pending

*No pending tasks*

## Completed

*None yet*

---

**Last Updated**: $today
EOF

    cat > "$PROJECT_DIR/insights.md" << EOF
# Insights

> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. Automatically injected by \`session-recovery.py\` hook.

## Key Learnings

*None yet*

## Patterns Identified

*None yet*

## Gotchas & Pitfalls

*None yet*

---

**Last Updated**: $today
EOF
}

# ============================================================================
# EMBEDDED CONTENT: RLM TOOLS
# ============================================================================

write_rlm_tools() {
    mkdir -p "$PROJECT_DIR/rlm_tools"
    mkdir -p "$PROJECT_DIR/rlm_context/chunks"
    mkdir -p "$PROJECT_DIR/rlm_context/results"

    # __init__.py
    cat > "$PROJECT_DIR/rlm_tools/__init__.py" << 'RLM_INIT_EOF'
"""RLM (Recursive Language Model) Tools for processing large documents."""
RLM_INIT_EOF

    # probe.py
    cat > "$PROJECT_DIR/rlm_tools/probe.py" << 'RLM_PROBE_EOF'
#!/usr/bin/env python3
"""
RLM Probe Tool - Analyze input structure and recommend chunking strategy.

Usage:
    python probe.py <file> [--json]
"""

import argparse
import json
import os
import sys

def analyze_file(filepath):
    """Analyze a file and return its characteristics."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except Exception as e:
        return {"error": str(e)}

    lines = content.split('\n')
    words = content.split()
    chars = len(content)
    estimated_tokens = chars // 4

    # Detect structure
    has_headers = bool([l for l in lines if l.startswith('#')])
    has_code_blocks = '```' in content
    has_functions = 'def ' in content or 'function ' in content

    # Recommend chunk count
    target_chunk_size = 200000  # chars
    recommended_chunks = max(1, chars // target_chunk_size)

    return {
        "file": filepath,
        "size_chars": chars,
        "size_lines": len(lines),
        "size_words": len(words),
        "estimated_tokens": estimated_tokens,
        "recommended_chunks": recommended_chunks,
        "has_headers": has_headers,
        "has_code_blocks": has_code_blocks,
        "has_functions": has_functions,
        "suggested_strategy": "headers" if has_headers else ("code" if has_functions else "size")
    }

def main():
    parser = argparse.ArgumentParser(description="Analyze file structure for RLM chunking")
    parser.add_argument("files", nargs="+", help="Files to analyze")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    results = []
    for filepath in args.files:
        if not os.path.exists(filepath):
            results.append({"file": filepath, "error": "File not found"})
            continue
        results.append(analyze_file(filepath))

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            if "error" in r:
                print(f"Error: {r['file']} - {r['error']}")
                continue
            print(f"\n=== File Analysis ===")
            print(f"File: {r['file']}")
            print(f"Size: {r['size_chars']:,} characters ({r['size_lines']:,} lines)")
            print(f"Estimated tokens: ~{r['estimated_tokens']:,}")
            print(f"Recommended chunks: {r['recommended_chunks']}")
            print(f"Suggested strategy: {r['suggested_strategy']}")
            print(f"Structure: {'Headers' if r['has_headers'] else ''} {'Code' if r['has_code_blocks'] else ''} {'Functions' if r['has_functions'] else 'Plain text'}")

if __name__ == "__main__":
    main()
RLM_PROBE_EOF

    # chunk.py
    cat > "$PROJECT_DIR/rlm_tools/chunk.py" << 'RLM_CHUNK_EOF'
#!/usr/bin/env python3
"""
RLM Chunk Tool - Split large files into processable chunks.

Usage:
    python chunk.py <file> --output <dir> [--size 200000] [--strategy size|code|headers]
"""

import argparse
import json
import os
import re
import sys
from typing import List, Tuple

def chunk_by_size(text: str, chunk_size: int = 200000, overlap: int = 500) -> List[Tuple[str, dict]]:
    """Split text into fixed-size chunks with overlap."""
    chunks = []
    start = 0
    chunk_num = 1
    while start < len(text):
        end = start + chunk_size
        if end < len(text):
            # Try to find a good break point
            for sep in ['\n\n', '\n', '. ', ' ']:
                break_point = text.rfind(sep, start + chunk_size - 1000, end)
                if break_point > start:
                    end = break_point + len(sep)
                    break
        chunk_text = text[start:end]
        chunks.append((chunk_text, {"chunk_num": chunk_num, "start_char": start, "end_char": end}))
        start = end - overlap
        chunk_num += 1
    return chunks

def detect_language(text: str) -> str:
    """Detect programming language from text content."""
    if re.search(r'(use\s+std::|impl\s+\w+|fn\s+\w+|pub\s+fn)', text):
        return "rust"
    if re.search(r'(func\s+\w+|package\s+\w+|type\s+\w+\s+struct)', text):
        return "go"
    if re.search(r'(interface\s+\w+|type\s+\w+\s*=|:\s*(string|number|boolean))', text):
        return "typescript"
    if re.search(r'def\s+\w+|class\s+\w+.*:', text):
        return "python"
    if re.search(r'function\s+\w+|const\s+\w+\s*=|=>', text):
        return "javascript"
    return "unknown"

def chunk_by_code(text: str, max_chunk_size: int = 200000, language: str = None) -> List[Tuple[str, dict]]:
    """Split code at function/class boundaries."""
    if not language:
        language = detect_language(text)

    patterns = {
        "python": r'^(class\s+\w+|def\s+\w+|async\s+def\s+\w+)',
        "javascript": r'^(function\s+\w+|class\s+\w+|const\s+\w+\s*=\s*(?:async\s*)?\()',
        "typescript": r'^(function\s+\w+|class\s+\w+|interface\s+\w+|type\s+\w+|const\s+\w+)',
        "go": r'^(func\s+(?:\(\w+\s+\*?\w+\)\s+)?\w+|type\s+\w+\s+(?:struct|interface))',
        "rust": r'^(pub\s+)?(?:fn|struct|enum|impl|trait)\s+\w+',
    }

    pattern = patterns.get(language, patterns["python"])
    lines = text.split('\n')
    boundaries = [0]

    for i, line in enumerate(lines):
        if re.match(pattern, line.strip(), re.MULTILINE):
            boundaries.append(i)

    boundaries.append(len(lines))

    chunks = []
    current_chunk_lines = []
    current_start = 0
    chunk_num = 1

    for i in range(len(boundaries) - 1):
        start_line = boundaries[i]
        end_line = boundaries[i + 1]
        section_lines = lines[start_line:end_line]
        section_text = '\n'.join(section_lines)

        if len('\n'.join(current_chunk_lines)) + len(section_text) > max_chunk_size and current_chunk_lines:
            chunk_text = '\n'.join(current_chunk_lines)
            chunks.append((chunk_text, {"chunk_num": chunk_num, "language": language}))
            current_chunk_lines = []
            chunk_num += 1

        current_chunk_lines.extend(section_lines)

    if current_chunk_lines:
        chunk_text = '\n'.join(current_chunk_lines)
        chunks.append((chunk_text, {"chunk_num": chunk_num, "language": language}))

    return chunks

def main():
    parser = argparse.ArgumentParser(description="Split large files into chunks")
    parser.add_argument("file", help="File to chunk")
    parser.add_argument("--output", "-o", default="./chunks", help="Output directory")
    parser.add_argument("--size", "-s", type=int, default=200000, help="Chunk size in characters")
    parser.add_argument("--overlap", type=int, default=500, help="Overlap between chunks")
    parser.add_argument("--strategy", choices=["size", "code", "headers"], default="size")
    parser.add_argument("--language", help="Language for code strategy")
    parser.add_argument("--progress", action="store_true", help="Show progress")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"Error: File not found: {args.file}")
        sys.exit(1)

    with open(args.file, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    if args.strategy == "code":
        chunks = chunk_by_code(content, args.size, args.language)
    else:
        chunks = chunk_by_size(content, args.size, args.overlap)

    os.makedirs(args.output, exist_ok=True)

    manifest = {"source_file": args.file, "total_chunks": len(chunks), "chunks": []}

    for i, (chunk_text, metadata) in enumerate(chunks):
        chunk_file = os.path.join(args.output, f"chunk_{i+1:03d}.txt")
        with open(chunk_file, 'w') as f:
            f.write(chunk_text)
        manifest["chunks"].append({"file": chunk_file, "size": len(chunk_text), **metadata})
        if args.progress:
            print(f"  [{i+1}/{len(chunks)}] Written {chunk_file} ({len(chunk_text):,} chars)")

    manifest_file = os.path.join(args.output, "manifest.json")
    with open(manifest_file, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"\nCreated {len(chunks)} chunks in {args.output}/")
    print(f"Manifest: {manifest_file}")

if __name__ == "__main__":
    main()
RLM_CHUNK_EOF

    # aggregate.py
    cat > "$PROJECT_DIR/rlm_tools/aggregate.py" << 'RLM_AGGREGATE_EOF'
#!/usr/bin/env python3
"""
RLM Aggregate Tool - Combine chunk results into final output.

Usage:
    python aggregate.py <results_dir> [--format text|json] [--output file]
"""

import argparse
import json
import os
import sys
from pathlib import Path

def load_results(results_dir):
    """Load all result files from directory."""
    results = []
    results_path = Path(results_dir)

    for result_file in sorted(results_path.glob("*.json")):
        try:
            with open(result_file) as f:
                data = json.load(f)
                results.append({"file": str(result_file), "data": data})
        except json.JSONDecodeError:
            pass

    for result_file in sorted(results_path.glob("*.txt")):
        with open(result_file) as f:
            content = f.read()
            results.append({"file": str(result_file), "data": {"content": content}})

    return results

def aggregate_results(results, format_type="text"):
    """Combine results into final output."""
    if format_type == "json":
        return json.dumps(results, indent=2)

    output_lines = ["=" * 60, "AGGREGATED RESULTS", "=" * 60, ""]

    for i, result in enumerate(results, 1):
        output_lines.append(f"--- Result {i} ({os.path.basename(result['file'])}) ---")
        data = result["data"]
        if isinstance(data, dict):
            if "content" in data:
                output_lines.append(data["content"])
            else:
                output_lines.append(json.dumps(data, indent=2))
        else:
            output_lines.append(str(data))
        output_lines.append("")

    output_lines.extend(["=" * 60, f"Total: {len(results)} results aggregated", "=" * 60])
    return "\n".join(output_lines)

def main():
    parser = argparse.ArgumentParser(description="Aggregate RLM chunk results")
    parser.add_argument("results_dir", help="Directory containing result files")
    parser.add_argument("--format", "-f", choices=["text", "json"], default="text")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    parser.add_argument("--query", "-q", help="Original query for context")
    args = parser.parse_args()

    if not os.path.isdir(args.results_dir):
        print(f"Error: Directory not found: {args.results_dir}")
        sys.exit(1)

    results = load_results(args.results_dir)

    if not results:
        print(f"No results found in {args.results_dir}")
        sys.exit(0)

    output = aggregate_results(results, args.format)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"Aggregated {len(results)} results to {args.output}")
    else:
        print(output)

if __name__ == "__main__":
    main()
RLM_AGGREGATE_EOF

    chmod +x "$PROJECT_DIR/rlm_tools"/*.py
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

install_global() {
    print_section "Installing Global Components"

    # Create directories
    print_info "Creating directories..."
    mkdir -p "$HOOKS_DIR"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$SESSIONS_DIR"
    mkdir -p "$HISTORY_DIR"
    mkdir -p "$LOGS_DIR"
    print_success "Directories created"

    # Write hooks
    print_info "Installing hooks..."
    write_hook_logger
    write_skill_matcher
    write_large_input_detector
    write_history_search
    write_skill_tracker
    write_detect_learning
    write_history_indexer
    write_live_session_indexer
    write_session_recovery
    chmod +x "$HOOKS_DIR"/*.py
    print_success "9 hooks installed"

    # Write settings
    print_info "Installing settings..."
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        backup="$CLAUDE_DIR/settings.json.backup.$(date +%Y%m%d%H%M%S)"
        cp "$CLAUDE_DIR/settings.json" "$backup"
        print_warning "Backed up existing settings to $backup"
    fi
    write_settings
    print_success "Settings installed"

    # Write skill index
    print_info "Installing skill index..."
    write_skill_index
    print_success "Skill index installed (17 skills)"

    echo ""
    print_success "Global installation complete!"
    echo ""
    echo "Installed:"
    echo "  - 9 hooks in ~/.claude/hooks/"
    echo "  - 17 skills in ~/.claude/skills/"
    echo "  - Hook configuration in ~/.claude/settings.json"
    echo ""
    echo "Run '/hooks' in Claude Code to reload hooks."
}

install_project() {
    print_section "Installing Project Components"

    # Check if already initialized
    if [ -f "$PROJECT_DIR/context.md" ] && [ -f "$PROJECT_DIR/todos.md" ]; then
        if ! confirm "Persistence files already exist. Overwrite?"; then
            print_info "Skipping persistence files"
        else
            write_persistence_templates
            print_success "Persistence templates created"
        fi
    else
        write_persistence_templates
        print_success "Persistence templates created"
    fi

    # Install RLM tools
    if [ -d "$PROJECT_DIR/rlm_tools" ]; then
        if ! confirm "rlm_tools/ already exists. Overwrite?"; then
            print_info "Skipping RLM tools"
        else
            write_rlm_tools
            print_success "RLM tools installed"
        fi
    else
        write_rlm_tools
        print_success "RLM tools installed"
    fi

    # Git init
    if [ ! -d "$PROJECT_DIR/.git" ]; then
        if confirm "Initialize git repository?"; then
            git init -q
            print_success "Git repository initialized"
        fi
    fi

    echo ""
    print_success "Project installation complete!"
    echo ""
    echo "Created:"
    echo "  - context.md (current goal)"
    echo "  - todos.md (task tracking)"
    echo "  - insights.md (learnings)"
    echo "  - rlm_tools/ (RLM processing)"
    echo "  - rlm_context/ (RLM working directory)"
}

check_status() {
    print_section "Checking Installation Status"

    echo ""
    echo -e "${BOLD}Global Components:${NC}"

    # Check hooks
    local hooks_count=0
    for hook in hook_logger skill-matcher large-input-detector history-search skill-tracker detect-learning history-indexer live-session-indexer session-recovery; do
        if [ -f "$HOOKS_DIR/${hook}.py" ]; then
            ((hooks_count++))
        fi
    done
    if [ $hooks_count -eq 9 ]; then
        print_success "Hooks: $hooks_count/9 installed"
    else
        print_warning "Hooks: $hooks_count/9 installed"
    fi

    # Check settings
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        print_success "Settings: Installed"
    else
        print_error "Settings: Not found"
    fi

    # Check skill index
    if [ -f "$SKILLS_DIR/skill-index/index.json" ]; then
        local skill_count=$(python3 -c "import json; print(len(json.load(open('$SKILLS_DIR/skill-index/index.json'))['skills']))" 2>/dev/null || echo "0")
        print_success "Skill index: $skill_count skills"
    else
        print_error "Skill index: Not found"
    fi

    # Check directories
    [ -d "$SESSIONS_DIR" ] && print_success "Sessions dir: Created" || print_warning "Sessions dir: Not found"
    [ -d "$HISTORY_DIR" ] && print_success "History dir: Created" || print_warning "History dir: Not found"

    echo ""
    echo -e "${BOLD}Project Components (in $PROJECT_DIR):${NC}"

    [ -f "$PROJECT_DIR/context.md" ] && print_success "context.md: Found" || print_warning "context.md: Not found"
    [ -f "$PROJECT_DIR/todos.md" ] && print_success "todos.md: Found" || print_warning "todos.md: Not found"
    [ -f "$PROJECT_DIR/insights.md" ] && print_success "insights.md: Found" || print_warning "insights.md: Not found"
    [ -d "$PROJECT_DIR/rlm_tools" ] && print_success "rlm_tools/: Found" || print_warning "rlm_tools/: Not found"
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_menu() {
    print_header

    echo "What would you like to do?"
    echo ""
    echo "  1) Full install (global + project setup)"
    echo "  2) Global only (hooks, skills, settings)"
    echo "  3) Project only (persistence files, RLM tools)"
    echo "  4) Check installation status"
    echo "  5) Exit"
    echo ""
    read -p "Choose [1-5]: " choice

    case $choice in
        1)
            check_prerequisites
            install_global
            install_project
            ;;
        2)
            check_prerequisites
            install_global
            ;;
        3)
            check_prerequisites
            install_project
            ;;
        4)
            check_status
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

case "${1:-}" in
    --global)
        check_prerequisites
        install_global
        ;;
    --project)
        check_prerequisites
        install_project
        ;;
    --check)
        check_status
        ;;
    --help|-h)
        echo "Enhanced Claude Installer"
        echo ""
        echo "Usage:"
        echo "  ./enhanced-claude-install.sh              Interactive mode"
        echo "  ./enhanced-claude-install.sh --global     Install global components"
        echo "  ./enhanced-claude-install.sh --project    Install project components"
        echo "  ./enhanced-claude-install.sh --check      Check installation status"
        echo ""
        echo "For more information, visit:"
        echo "  https://github.com/RohanRamanna/ENHANCED-CLAUDE"
        ;;
    "")
        show_menu
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

echo ""
print_success "Done!"
