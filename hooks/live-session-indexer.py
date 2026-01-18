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
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        sys.exit(0)

    # Find current session
    try:
        session_info = find_current_session()
        if not session_info:
            logger.debug("No current session found, exiting")
            sys.exit(0)
    except Exception as e:
        logger.error(f"Error finding current session: {e}", exc_info=True)
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
        sys.exit(0)

    # Save updated index
    try:
        save_segment_index(session_dir, updated_index)
        if new_segments > existing_segments:
            logger.info(f"Added {new_segments - existing_segments} new segments")
    except Exception as e:
        logger.error(f"Error saving segment index: {e}", exc_info=True)

    logger.info("Hook completed successfully")
    sys.exit(0)


if __name__ == "__main__":
    main()
