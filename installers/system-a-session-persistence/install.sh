#!/bin/bash
#
# Enhanced Claude - System A: Session Persistence & Searchable History
#
# This installer sets up:
# - Session recovery after context compaction (RLM-based)
# - Live session indexing for intelligent recovery
# - Searchable conversation history
# - History search suggestions
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# Uninstall:
#   ./uninstall.sh
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
echo "  Enhanced Claude - System A Installer"
echo "  Session Persistence & Searchable History"
echo "=============================================="
echo -e "${NC}"

# Detect home directory
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$HOOKS_DIR/logs"
SKILLS_DIR="$CLAUDE_DIR/skills"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
HISTORY_DIR="$CLAUDE_DIR/history"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups/system-a-$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$HOOKS_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$SKILLS_DIR/history"
mkdir -p "$SESSIONS_DIR"
mkdir -p "$HISTORY_DIR"
mkdir -p "$BACKUP_DIR"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Backing up existing settings to $BACKUP_DIR...${NC}"
    cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.backup"
fi

echo -e "${YELLOW}Installing hooks...${NC}"

# ============================================
# hook_logger.py (shared utility)
# ============================================
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
            # Rotate existing logs
            for i in range(MAX_LOG_FILES - 1, 0, -1):
                old_file = self.log_dir / f"{self.hook_name}.{i}.log"
                new_file = self.log_dir / f"{self.hook_name}.{i + 1}.log"
                if old_file.exists():
                    if i + 1 >= MAX_LOG_FILES:
                        old_file.unlink()  # Delete oldest
                    else:
                        old_file.rename(new_file)

            # Rotate current to .1
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

        # Add any extra data
        if kwargs.get("exc_info"):
            entry["traceback"] = traceback.format_exc()

        if kwargs.get("data"):
            entry["data"] = kwargs["data"]

        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass  # Don't let logging errors break the hook

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

# ============================================
# session-recovery.py
# ============================================
cat > "$HOOKS_DIR/session-recovery.py" << 'SESSION_RECOVERY_EOF'
#!/usr/bin/env python3
"""
Session Recovery Hook - SessionStart
RLM-based intelligent session recovery after context compaction.

Trigger: After /compact, auto-compaction, /resume, --continue
Action:
  1. Load persistence files (context.md, todos.md, insights.md)
  2. Load segment index for current session
  3. Score segments by relevance (recency, task match, uncommitted work)
  4. Extract actual content from JSONL for top segments
  5. Inject relevant context for zero data loss recovery
"""

import json
import sys
import os
import re
from datetime import datetime, timedelta
from pathlib import Path

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("session-recovery")

# Project directory with persistence files (auto-detect from cwd)
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

# Directories
SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

# Persistence files
PERSISTENCE_FILES = [
    ("context.md", "Current Goal & Decisions"),
    ("todos.md", "Task Progress"),
    ("insights.md", "Accumulated Learnings"),
]

# Context budget for segments (characters)
SEGMENT_CONTEXT_BUDGET = 8000  # ~2000 tokens worth of actual conversation


def read_file_safe(filepath):
    """Read file contents, return empty string if not found."""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except (FileNotFoundError, IOError):
        return ""


def find_current_session():
    """Find the most recently modified session for current project."""
    if not os.path.exists(PROJECTS_DIR):
        return None

    best_match = None
    best_time = 0

    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir():
            continue
        if project_dir.name.startswith('.'):
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
    """Load segment index for a session."""
    index_path = os.path.join(SESSIONS_DIR, session_id, "segments.json")
    try:
        with open(index_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def extract_pending_todos(todos_content):
    """Extract pending todos from todos.md content."""
    pending = []
    in_pending = False

    for line in todos_content.split('\n'):
        if '## In Progress' in line or '## Pending' in line:
            in_pending = True
            continue
        if in_pending and line.startswith('## '):
            in_pending = False
        if in_pending and line.strip().startswith('- [ ]'):
            # Extract todo text
            todo_text = line.replace('- [ ]', '').strip()
            if todo_text:
                pending.append(todo_text.lower())

    return pending


def score_segment(segment, pending_todos, now):
    """Score a segment for relevance."""
    score = 0

    # Recency score (exponential decay, max 50 points)
    try:
        ts_str = segment.get("timestamp", "")
        if ts_str:
            ts_str = ts_str.replace('Z', '').split('.')[0]
            segment_time = datetime.fromisoformat(ts_str)
            hours_ago = (now - segment_time).total_seconds() / 3600
            recency_score = max(0, 50 - (hours_ago * 5))  # Lose 5 points per hour
            score += recency_score
    except:
        pass

    # Topic match with pending todos (max 30 points)
    topics = set(t.lower() for t in segment.get("topics", []))
    for todo in pending_todos:
        todo_words = set(todo.split())
        matching_topics = topics.intersection(todo_words)
        score += len(matching_topics) * 10

    # Has uncommitted decisions (10 points)
    if segment.get("decisions"):
        score += 10

    # Tools used (prefer segments with Edit/Write = active work)
    tools = segment.get("tools_used", {})
    if "Edit" in tools or "Write" in tools:
        score += 15
    if "TodoWrite" in tools:
        score += 5

    # Boundary type bonus
    boundary = segment.get("boundary_type", "")
    if boundary == "task_completed":
        score += 10
    elif boundary == "new_topic":
        score += 5

    return score


def extract_segment_content(jsonl_path, start_line, end_line):
    """Extract actual conversation content from JSONL for a segment."""
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
                            # Extract key info from tool use
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
    """Select the most relevant segments within context budget."""
    if not segments:
        return []

    now = datetime.now()

    # Score all segments
    scored = []
    for seg in segments:
        score = score_segment(seg, pending_todos, now)
        scored.append((score, seg))

    # Sort by score (highest first)
    scored.sort(key=lambda x: x[0], reverse=True)

    # Select segments within budget
    selected = []
    total_chars = 0

    for score, seg in scored:
        # Estimate content size
        line_count = seg.get("line_count", 0)
        estimated_chars = line_count * 100  # Rough estimate

        if total_chars + estimated_chars > budget:
            continue

        # Extract actual content
        content = extract_segment_content(
            jsonl_path,
            seg.get("start_line", 0),
            seg.get("end_line", 0)
        )

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
    """Build the complete recovery context."""
    sections = []
    sections.append("=" * 70)
    sections.append("SESSION RECOVERED - RLM-based intelligent context loading")
    sections.append("=" * 70)

    # Part 1: Load persistence files
    files_found = 0
    todos_content = ""

    for filename, description in PERSISTENCE_FILES:
        filepath = os.path.join(PROJECT_DIR, filename)
        content = read_file_safe(filepath)

        if content.strip():
            files_found += 1
            sections.append(f"\n### {description} ({filename})\n")
            # Keep full content for small files, truncate large ones
            if len(content) > 2500:
                content = content[:2500] + "\n... [truncated]"
            sections.append(content)

            if filename == "todos.md":
                todos_content = content

    # Part 2: Load relevant segments from current session
    session_info = find_current_session()

    if session_info:
        segment_index = load_segment_index(session_info["session_id"])

        if segment_index and segment_index.get("segments"):
            # Extract pending todos for relevance scoring
            pending_todos = extract_pending_todos(todos_content)

            # Select best segments
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

    # Final instructions
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

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
        logger.debug(f"Session trigger: {hook_input.get('session_trigger', 'unknown')}")

        # Use cwd from hook input if available
        if hook_input.get("cwd"):
            PROJECT_DIR = hook_input["cwd"]
            logger.debug(f"Using PROJECT_DIR from cwd: {PROJECT_DIR}")
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        sys.exit(0)

    # Build recovery context
    try:
        recovery_context = build_recovery_context()
        logger.debug(f"Built recovery context ({len(recovery_context)} chars)")
    except Exception as e:
        logger.error(f"Error building recovery context: {e}", exc_info=True)
        sys.exit(0)

    # Output as additionalContext
    output = {
        "hookSpecificOutput": {
            "additionalContext": recovery_context
        }
    }
    print(json.dumps(output))
    logger.info("Hook completed successfully")
    sys.exit(0)


if __name__ == "__main__":
    main()
SESSION_RECOVERY_EOF

# ============================================
# live-session-indexer.py
# ============================================
cat > "$HOOKS_DIR/live-session-indexer.py" << 'LIVE_SESSION_INDEXER_EOF'
#!/usr/bin/env python3
"""
Live Session Indexer Hook - Stop
Chunks the current session into semantic segments for intelligent recovery.

Trigger: Stop event (end of each conversation turn)
Action: Identifies segment boundaries and builds segment index for current session
Output: ~/.claude/sessions/<session-id>/segments.json
"""

import json
import sys
import os
import re
from datetime import datetime
from pathlib import Path

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("live-session-indexer")

# Directories
SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

# Segment detection thresholds
MIN_SEGMENT_LINES = 10      # Minimum lines for a segment
MAX_SEGMENT_LINES = 100     # Maximum lines before forcing a new segment
TIME_GAP_MINUTES = 5        # Time gap that triggers new segment

# Topics to detect
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
    """Create session directory if needed."""
    session_dir = os.path.join(SESSIONS_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)
    return session_dir


def load_segment_index(session_dir):
    """Load existing segment index or create empty one."""
    index_path = os.path.join(session_dir, "segments.json")
    try:
        with open(index_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "version": 1,
            "session_id": None,
            "project": None,
            "jsonl_file": None,
            "last_indexed_line": 0,
            "segments": [],
            "active_segment": None
        }


def save_segment_index(session_dir, index):
    """Save segment index to disk."""
    index_path = os.path.join(session_dir, "segments.json")
    index["last_updated"] = datetime.now().isoformat()
    with open(index_path, 'w') as f:
        json.dump(index, f, indent=2)


def find_current_session():
    """Find the most recently modified session file for current project."""
    if not os.path.exists(PROJECTS_DIR):
        return None, None

    # Get current working directory to match project
    cwd = os.getcwd()
    project_name = cwd.replace("/", "-").replace(" ", "-")

    # Find project directories that might match
    best_match = None
    best_time = 0

    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir():
            continue
        if project_dir.name.startswith('.'):
            continue

        # Find most recent JSONL file
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


def parse_timestamp(ts_str):
    """Parse ISO timestamp string to datetime."""
    if not ts_str:
        return None
    try:
        # Handle various ISO formats
        ts_str = ts_str.replace('Z', '+00:00')
        if '.' in ts_str:
            ts_str = ts_str[:ts_str.index('.')] + ts_str[ts_str.index('+'):] if '+' in ts_str else ts_str[:ts_str.index('.')]
        return datetime.fromisoformat(ts_str.replace('+00:00', ''))
    except:
        return None


def extract_topics(content):
    """Extract topics from content."""
    topics = set()
    content_lower = content.lower() if content else ""

    for keyword in DOMAIN_KEYWORDS:
        if keyword in content_lower:
            topics.add(keyword)

    return topics


def extract_files(content):
    """Extract file paths from content."""
    files = set()
    if not content:
        return files

    patterns = [
        r'["\']([^"\']+\.(py|ts|js|md|json|tsx|jsx))["\']',
        r'`([^`]+\.(py|ts|js|md|json|tsx|jsx))`',
    ]

    for pattern in patterns:
        matches = re.findall(pattern, content)
        for match in matches:
            if isinstance(match, tuple):
                files.add(match[0])
            else:
                files.add(match)

    return files


def extract_decisions(content):
    """Extract key decisions from content."""
    decisions = []
    if not content:
        return decisions

    # Look for decision indicators
    decision_patterns = [
        r"(?:I'll|Let's|We should|I've decided|decided to|going to)\s+([^.!?\n]+)",
        r"(?:approach|strategy|solution):\s*([^.!?\n]+)",
    ]

    for pattern in decision_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            if len(match) > 10 and len(match) < 200:
                decisions.append(match.strip())

    return decisions[:5]  # Limit to top 5


def is_segment_boundary(current_msg, prev_msg, line_count):
    """Determine if this is a segment boundary."""
    # Force boundary if segment too large
    if line_count >= MAX_SEGMENT_LINES:
        return True, "max_lines"

    # Not enough lines for a segment yet
    if line_count < MIN_SEGMENT_LINES:
        return False, None

    # Check for time gap
    curr_ts = parse_timestamp(current_msg.get("timestamp"))
    prev_ts = parse_timestamp(prev_msg.get("timestamp")) if prev_msg else None

    if curr_ts and prev_ts:
        gap = (curr_ts - prev_ts).total_seconds() / 60
        if gap > TIME_GAP_MINUTES:
            return True, "time_gap"

    # Check for TodoWrite with completed tasks (task completion boundary)
    if current_msg.get("type") == "assistant":
        content_list = current_msg.get("message", {}).get("content", [])
        if isinstance(content_list, list):
            for item in content_list:
                if isinstance(item, dict) and item.get("type") == "tool_use":
                    if item.get("name") == "TodoWrite":
                        tool_input = item.get("input", {})
                        todos = tool_input.get("todos", [])
                        # Check if any todos are being marked completed
                        for todo in todos:
                            if todo.get("status") == "completed":
                                return True, "task_completed"

    # Check for new user message after assistant (natural turn boundary)
    if current_msg.get("type") == "user" and prev_msg and prev_msg.get("type") == "assistant":
        # Check if topic changed significantly
        curr_content = current_msg.get("message", {}).get("content", "")
        if isinstance(curr_content, str) and len(curr_content) > 50:
            return True, "new_topic"

    return False, None


def create_segment_summary(messages):
    """Create a brief summary of the segment."""
    topics = set()
    files = set()
    tools = {}
    decisions = []

    for msg in messages:
        msg_type = msg.get("type")

        if msg_type == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str):
                topics.update(extract_topics(content))
                files.update(extract_files(content))

        elif msg_type == "assistant":
            content_list = msg.get("message", {}).get("content", [])
            if isinstance(content_list, list):
                for item in content_list:
                    if isinstance(item, dict):
                        if item.get("type") == "text":
                            text = item.get("text", "")
                            topics.update(extract_topics(text))
                            decisions.extend(extract_decisions(text))
                        elif item.get("type") == "tool_use":
                            tool_name = item.get("name", "unknown")
                            tools[tool_name] = tools.get(tool_name, 0) + 1
                            tool_input = item.get("input", {})
                            if isinstance(tool_input, dict):
                                for val in tool_input.values():
                                    if isinstance(val, str):
                                        files.update(extract_files(val))

    # Build summary string
    summary_parts = []
    if topics:
        summary_parts.append(f"Topics: {', '.join(list(topics)[:5])}")
    if files:
        summary_parts.append(f"Files: {len(files)}")
    if tools:
        top_tools = sorted(tools.items(), key=lambda x: x[1], reverse=True)[:3]
        summary_parts.append(f"Tools: {', '.join([t[0] for t in top_tools])}")

    return {
        "topics": list(topics)[:10],
        "files_touched": list(files)[:10],
        "tools_used": dict(sorted(tools.items(), key=lambda x: x[1], reverse=True)[:5]),
        "decisions": decisions[:3],
        "summary": " | ".join(summary_parts) if summary_parts else "General discussion"
    }


def index_session(session_info, existing_index):
    """Index new content in the session file."""
    path = session_info["path"]
    session_id = session_info["session_id"]

    try:
        with open(path, 'r') as f:
            lines = f.readlines()
    except (FileNotFoundError, IOError):
        return existing_index

    # Start from where we left off
    start_line = existing_index.get("last_indexed_line", 0)
    if start_line >= len(lines):
        return existing_index  # Already up to date

    # Update index metadata
    existing_index["session_id"] = session_id
    existing_index["project"] = session_info["project"]
    existing_index["jsonl_file"] = path

    # Get existing segments and active segment
    segments = existing_index.get("segments", [])
    active_segment = existing_index.get("active_segment")

    if active_segment is None:
        active_segment = {
            "segment_id": f"seg-{len(segments):03d}",
            "start_line": start_line,
            "messages": [],
            "line_count": 0
        }
    else:
        # Ensure messages key exists (not saved to disk to avoid bloat)
        if "messages" not in active_segment:
            active_segment["messages"] = []

    # Process new lines
    prev_msg = None
    for i in range(start_line, len(lines)):
        line = lines[i].strip()
        if not line:
            continue

        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Skip file snapshots and summaries
        if msg.get("type") in ["file-history-snapshot", "summary"]:
            continue

        # Check for segment boundary
        is_boundary, boundary_type = is_segment_boundary(msg, prev_msg, active_segment["line_count"])

        if is_boundary and active_segment["messages"]:
            # Finalize current segment
            segment_data = create_segment_summary(active_segment["messages"])
            segment_entry = {
                "segment_id": active_segment["segment_id"],
                "start_line": active_segment["start_line"],
                "end_line": i - 1,
                "line_count": active_segment["line_count"],
                "boundary_type": boundary_type,
                **segment_data
            }

            # Get timestamp from first message
            first_msg = active_segment["messages"][0]
            segment_entry["timestamp"] = first_msg.get("timestamp", datetime.now().isoformat())

            segments.append(segment_entry)

            # Start new segment
            active_segment = {
                "segment_id": f"seg-{len(segments):03d}",
                "start_line": i,
                "messages": [],
                "line_count": 0
            }

        # Add message to active segment
        active_segment["messages"].append(msg)
        active_segment["line_count"] += 1
        prev_msg = msg

    # Update index
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

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)

    # Find current session
    try:
        session_info = find_current_session()
        if not session_info:
            logger.debug("No current session found, exiting")
            print('{"continue": true}')
            sys.exit(0)
    except Exception as e:
        logger.error(f"Error finding current session: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)

    session_id = session_info["session_id"]
    logger.debug(f"Processing session: {session_id}")

    # Ensure session directory exists
    session_dir = ensure_dirs(session_id)

    # Load existing index
    existing_index = load_segment_index(session_dir)
    existing_segments = len(existing_index.get("segments", []))
    logger.debug(f"Loaded existing index with {existing_segments} segments")

    # Index new content
    try:
        updated_index = index_session(session_info, existing_index)
        new_segments = len(updated_index.get("segments", []))
        logger.debug(f"Updated index has {new_segments} segments")
    except Exception as e:
        logger.error(f"Error indexing session: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)

    # Save updated index
    try:
        save_segment_index(session_dir, updated_index)
        if new_segments > existing_segments:
            logger.info(f"Added {new_segments - existing_segments} new segments")
    except Exception as e:
        logger.error(f"Error saving segment index: {e}", exc_info=True)

    logger.info("Hook completed successfully")
    print('{"continue": true}')
    sys.exit(0)


if __name__ == "__main__":
    main()
LIVE_SESSION_INDEXER_EOF

# ============================================
# history-indexer.py
# ============================================
cat > "$HOOKS_DIR/history-indexer.py" << 'HISTORY_INDEXER_EOF'
#!/usr/bin/env python3
"""
History Indexer Hook - Stop
Builds searchable index of conversation history without duplicating data.

Trigger: Stop event (end of each conversation turn)
Logic: Index session JSONL files, extract topics and segments
Output: Updates ~/.claude/history/index.json
"""

import json
import sys
import os
import re
from datetime import datetime
from pathlib import Path

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("history-indexer")

# Index location
HISTORY_DIR = os.path.expanduser("~/.claude/history")
INDEX_PATH = os.path.join(HISTORY_DIR, "index.json")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

# Topics to extract (domain keywords)
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
    """Create history directory if it doesn't exist."""
    os.makedirs(HISTORY_DIR, exist_ok=True)


def load_index():
    """Load existing index or create empty one."""
    try:
        with open(INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "version": 1,
            "last_indexed": None,
            "sessions": {},
            "topics": {}
        }


def save_index(index):
    """Save index to disk."""
    ensure_history_dir()
    index["last_indexed"] = datetime.now().isoformat()
    with open(INDEX_PATH, 'w') as f:
        json.dump(index, f, indent=2)


def find_session_files():
    """Find all session JSONL files across all projects."""
    sessions = []
    if not os.path.exists(PROJECTS_DIR):
        return sessions

    for project_dir in Path(PROJECTS_DIR).iterdir():
        if not project_dir.is_dir():
            continue
        # Skip hidden directories and subagents
        if project_dir.name.startswith('.'):
            continue

        for jsonl_file in project_dir.glob("*.jsonl"):
            # Skip subagent files
            if "subagents" in str(jsonl_file):
                continue
            sessions.append({
                "path": str(jsonl_file),
                "project": project_dir.name,
                "session_id": jsonl_file.stem
            })

    return sessions


def extract_topics_from_content(content):
    """Extract topics from message content."""
    topics = set()
    content_lower = content.lower()

    # Domain keywords
    for keyword in DOMAIN_KEYWORDS:
        if keyword in content_lower:
            topics.add(keyword)

    # File paths (extract base names)
    files = re.findall(r'["\']([^"\']+\.(py|ts|js|md|json|tsx|jsx|css|html))["\']', content)
    for file_path, _ in files:
        base = os.path.basename(file_path).split('.')[0]
        if len(base) > 2:
            topics.add(base.lower())

    return topics


def extract_files_from_content(content):
    """Extract file paths mentioned in content."""
    files = set()

    # Match file paths in various formats
    patterns = [
        r'["\']([^"\']+\.(py|ts|js|md|json|tsx|jsx|css|html|yml|yaml))["\']',
        r'`([^`]+\.(py|ts|js|md|json|tsx|jsx|css|html|yml|yaml))`',
    ]

    for pattern in patterns:
        matches = re.findall(pattern, content)
        for match in matches:
            if isinstance(match, tuple):
                files.add(match[0])
            else:
                files.add(match)

    return list(files)[:20]  # Limit to avoid bloat


def index_session(session_info):
    """Index a single session file."""
    path = session_info["path"]

    try:
        with open(path, 'r') as f:
            lines = f.readlines()
    except (FileNotFoundError, IOError):
        return None

    all_topics = set()
    all_files = set()
    tools_used = {}
    date = None

    # Process each line
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue

        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Get date from first message
        if not date and msg.get("timestamp"):
            ts = msg.get("timestamp", "")
            if isinstance(ts, str) and "T" in ts:
                date = ts.split("T")[0]

        # Extract from user messages
        if msg.get("type") == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str):
                all_topics.update(extract_topics_from_content(content))
                all_files.update(extract_files_from_content(content))

        # Extract from assistant messages (tool usage)
        if msg.get("type") == "assistant":
            message = msg.get("message", {})
            content_list = message.get("content", [])
            if isinstance(content_list, list):
                for item in content_list:
                    if isinstance(item, dict) and item.get("type") == "tool_use":
                        tool_name = item.get("name", "unknown")
                        tools_used[tool_name] = tools_used.get(tool_name, 0) + 1

                        # Extract from tool input
                        tool_input = item.get("input", {})
                        if isinstance(tool_input, dict):
                            for val in tool_input.values():
                                if isinstance(val, str):
                                    all_topics.update(extract_topics_from_content(val))
                                    all_files.update(extract_files_from_content(val))

    # Build session index entry
    return {
        "id": session_info["session_id"],
        "project": session_info["project"],
        "file": path,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "line_count": len(lines),
        "topics": list(all_topics)[:30],  # Limit topics
        "files_touched": list(all_files)[:20],
        "tools_used": dict(sorted(tools_used.items(), key=lambda x: x[1], reverse=True)[:10])
    }


def build_topic_index(sessions_dict):
    """Build inverted topic index from sessions."""
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

    # Sort entries by date (newest first)
    for topic in topics:
        topics[topic].sort(key=lambda x: x.get("date", ""), reverse=True)

    return topics


def main():
    logger.info("Hook started")

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)

    # Load existing index
    try:
        index = load_index()
        existing_sessions = set(index.get("sessions", {}).keys())
        logger.debug(f"Loaded index with {len(existing_sessions)} existing sessions")
    except Exception as e:
        logger.error(f"Error loading index: {e}", exc_info=True)
        print('{"continue": true}')
        sys.exit(0)

    # Find all session files
    session_files = find_session_files()
    logger.debug(f"Found {len(session_files)} session files")

    # Index new or updated sessions
    new_sessions = 0
    for session_info in session_files:
        session_id = session_info["session_id"]
        path = session_info["path"]

        # Check if already indexed and file hasn't grown
        if session_id in existing_sessions:
            existing = index["sessions"].get(session_id, {})
            try:
                current_lines = sum(1 for _ in open(path))
                if current_lines <= existing.get("line_count", 0):
                    continue  # Already indexed, no new content
            except:
                continue

        # Index the session
        session_entry = index_session(session_info)
        if session_entry:
            index["sessions"][session_id] = session_entry
            new_sessions += 1

    # Rebuild topic index if any changes
    if new_sessions > 0:
        index["topics"] = build_topic_index(index["sessions"])
        save_index(index)
        logger.info(f"Indexed {new_sessions} new sessions")
    else:
        logger.debug("No new sessions to index")

    logger.info("Hook completed successfully")
    print('{"continue": true}')
    sys.exit(0)


if __name__ == "__main__":
    main()
HISTORY_INDEXER_EOF

# ============================================
# history-search.py
# ============================================
cat > "$HOOKS_DIR/history-search.py" << 'HISTORY_SEARCH_EOF'
#!/usr/bin/env python3
"""
History Search Hook - UserPromptSubmit
Suggests relevant past conversation segments based on user prompts.

Trigger: Every user message (before Claude processes it)
Logic: Score topics in index against prompt, suggest matches
Output: Matching history segments injected as additionalContext
"""

import json
import sys
import os
from datetime import datetime

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("history-search")

# Index location
INDEX_PATH = os.path.expanduser("~/.claude/history/index.json")

# Minimum score to suggest history
MIN_SCORE_THRESHOLD = 8

# Common words to ignore when scoring
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
    """Load the history index from disk."""
    try:
        with open(INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"sessions": {}, "topics": {}}


def normalize_project_path(cwd):
    """Convert cwd to the project key format used in index."""
    if not cwd:
        return None
    # Convert /Users/foo/bar to -Users-foo-bar format
    # Keep leading dash to match how Claude Code stores project keys
    normalized = cwd.replace("/", "-").replace(" ", "-")
    # Ensure it starts with a dash (Claude Code format)
    if not normalized.startswith("-"):
        normalized = "-" + normalized
    return normalized


def score_session(session, prompt_words, topics_index):
    """
    Score a session against the user prompt.

    Scoring:
    - Exact topic match: +4 per topic
    - Partial topic match: +2 per topic word
    - Recent session (< 7 days): +2
    - File match: +3 per file
    """
    score = 0
    matching_topics = []

    session_topics = set(session.get("topics", []))
    session_files = set(session.get("files_touched", []))

    # Check topic matches
    for topic in session_topics:
        topic_lower = topic.lower()
        # Exact match
        if topic_lower in prompt_words:
            score += 4
            matching_topics.append(topic)
        else:
            # Partial match (word in topic matches word in prompt)
            topic_words = set(topic_lower.replace("-", " ").replace("_", " ").split())
            matches = topic_words & prompt_words
            meaningful_matches = matches - COMMON_WORDS
            if meaningful_matches:
                score += len(meaningful_matches) * 2
                matching_topics.append(topic)

    # Check file matches
    for file_path in session_files:
        file_name = os.path.basename(file_path).lower()
        file_base = file_name.split('.')[0]
        if file_base in prompt_words and len(file_base) > 2:
            score += 3

    # Recency bonus
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

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        # No output needed - just exit 0
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        # No output needed - just exit 0
        sys.exit(0)

    # Get the user prompt and current working directory
    prompt = hook_input.get("prompt", "")
    cwd = hook_input.get("cwd", "")

    if not prompt or len(prompt) < 10:
        logger.debug("Prompt too short, exiting")
        # No output needed - just exit 0
        sys.exit(0)

    # Prepare prompt for matching
    prompt_lower = prompt.lower()
    prompt_words = set(prompt_lower.replace("-", " ").replace("_", " ").split())
    meaningful_words = prompt_words - COMMON_WORDS

    if len(meaningful_words) < 2:
        # No output needed - just exit 0
        sys.exit(0)  # Not enough meaningful words to search

    # Load history index
    index = load_index()
    sessions = index.get("sessions", {})

    if not sessions:
        # No output needed - just exit 0
        sys.exit(0)

    # Get current project key for filtering
    current_project = normalize_project_path(cwd)

    # Score all sessions (filter to current project by default)
    scored_sessions = []
    for session_id, session in sessions.items():
        # Filter to current project
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
                "file": session.get("file", "")
            })

    # Sort by score descending
    scored_sessions.sort(key=lambda x: x["score"], reverse=True)

    # Build output for top matches
    if scored_sessions:
        top_matches = scored_sessions[:3]
        logger.info(f"Found {len(scored_sessions)} matches, showing top {len(top_matches)}")

        lines = ["[HISTORY MATCH] Found relevant past work in this project:"]
        for match in top_matches:
            session_id_short = match["session_id"][:8]
            topics_str = ", ".join(match["topics"][:3]) if match["topics"] else "various"
            lines.append(f"  - {match['date']}: {topics_str} (score:{match['score']}, {match['line_count']} lines)")
            lines.append(f"    Load: /history load {session_id_short}")

        lines.append("")
        lines.append("Use /history search <query> for more options, or /history search --all for cross-project search.")

        output = {
            "hookSpecificOutput": {
                "additionalContext": "\n".join(lines)
            }
        }
        logger.log_output(output)
        print(json.dumps(output), flush=True)
    else:
        logger.debug("No matches found")
        # No output needed - just exit 0

    logger.info("Hook completed successfully")
    sys.exit(0)


if __name__ == "__main__":
    main()
HISTORY_SEARCH_EOF

echo -e "${YELLOW}Installing history skill...${NC}"

# ============================================
# history/SKILL.md
# ============================================
mkdir -p "$SKILLS_DIR/history"
cat > "$SKILLS_DIR/history/SKILL.md" << 'HISTORY_SKILL_EOF'
# History Skill

Search and retrieve past conversation history without filling up context.

## Core Principle

**The full history exists on disk. We don't load it all - we search the index and load only what's needed.**

## Commands

### `/history search <query>`
Search past sessions in the **current project**.

### `/history search --all <query>`
Search across **ALL projects**.

### `/history load <session_id>`
Load specific session content.

### `/history topics`
List all topics in the current project.

### `/history recent [n]`
Show last N sessions (default 5).

### `/history rebuild`
Force rebuild the index from all session files.

## How It Works

1. **Index exists at**: `~/.claude/history/index.json`
2. **Sessions stored at**: `~/.claude/projects/<project>/<session>.jsonl`
3. **Index contains**:
   - Session metadata (date, line count, project)
   - Topics extracted from content
   - Files touched
   - Tools used
4. **No data duplication**: Index only has pointers, not content

## Automatic Suggestions

The `history-search.py` hook automatically suggests relevant history when you:
- Ask about something you've worked on before
- Reference tools or files from past sessions
- Use keywords that match past topics

You'll see:
```
[HISTORY MATCH] Found relevant past work in this project:
  - 2026-01-15: hooks, automation (score:12, 800 lines)
    Load: /history load 23a35a50
```
HISTORY_SKILL_EOF

# ============================================
# history/metadata.json
# ============================================
cat > "$SKILLS_DIR/history/metadata.json" << 'HISTORY_META_EOF'
{
  "name": "history",
  "summary": "Search and retrieve past conversation history",
  "category": "utility",
  "tags": [
    "history",
    "search",
    "memory",
    "context",
    "sessions"
  ],
  "useCount": 0,
  "lastUsed": null,
  "successCount": 0,
  "failureCount": 0
}
HISTORY_META_EOF

echo -e "${YELLOW}Configuring Claude Code settings...${NC}"

# ============================================
# Update settings.json with hooks
# ============================================

# Create settings file if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Use Python to merge settings (more reliable than jq)
python3 << SETTINGS_SCRIPT
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")
hooks_dir = os.path.expanduser("~/.claude/hooks")

# Load existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Ensure hooks structure exists
if "hooks" not in settings:
    settings["hooks"] = {}

# System A hooks configuration
system_a_hooks = {
    "UserPromptSubmit": [
        {
            "hooks": [
                {"type": "command", "command": f"python3 {hooks_dir}/history-search.py"}
            ]
        }
    ],
    "Stop": [
        {
            "hooks": [
                {"type": "command", "command": f"python3 {hooks_dir}/history-indexer.py"},
                {"type": "command", "command": f"python3 {hooks_dir}/live-session-indexer.py"}
            ]
        }
    ],
    "SessionStart": [
        {
            "matcher": "compact",
            "hooks": [
                {"type": "command", "command": f"python3 {hooks_dir}/session-recovery.py"}
            ]
        },
        {
            "matcher": "resume",
            "hooks": [
                {"type": "command", "command": f"python3 {hooks_dir}/session-recovery.py"}
            ]
        }
    ]
}

# Merge hooks (add System A hooks)
for event, event_hooks in system_a_hooks.items():
    if event not in settings["hooks"]:
        settings["hooks"][event] = []

    # Add new hooks, avoiding duplicates
    existing_commands = set()
    for hook_group in settings["hooks"][event]:
        for hook in hook_group.get("hooks", []):
            existing_commands.add(hook.get("command", ""))

    for new_hook_group in event_hooks:
        new_commands = [h.get("command", "") for h in new_hook_group.get("hooks", [])]
        if not any(cmd in existing_commands for cmd in new_commands):
            settings["hooks"][event].append(new_hook_group)

# Save updated settings
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings updated successfully")
SETTINGS_SCRIPT

# Save installation manifest for uninstall
cat > "$BACKUP_DIR/install-manifest.json" << MANIFEST_EOF
{
  "system": "A",
  "name": "Session Persistence & Searchable History",
  "installed": "$(date -Iseconds)",
  "hooks": [
    "$HOOKS_DIR/hook_logger.py",
    "$HOOKS_DIR/session-recovery.py",
    "$HOOKS_DIR/live-session-indexer.py",
    "$HOOKS_DIR/history-indexer.py",
    "$HOOKS_DIR/history-search.py"
  ],
  "skills": [
    "$SKILLS_DIR/history"
  ],
  "directories": [
    "$SESSIONS_DIR",
    "$HISTORY_DIR"
  ]
}
MANIFEST_EOF

echo -e "${GREEN}"
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Installed components:"
echo "  - 5 hooks (session-recovery, live-session-indexer, history-indexer, history-search, hook_logger)"
echo "  - 1 skill (history)"
echo ""
echo "Features enabled:"
echo "  - Automatic session recovery after context compaction"
echo "  - Live session indexing for intelligent recovery"
echo "  - Searchable conversation history"
echo "  - History search suggestions on every prompt"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo -e "${YELLOW}To uninstall, run: ./uninstall.sh${NC}"
echo ""
echo "Restart Claude Code or run /hooks to reload hooks."
