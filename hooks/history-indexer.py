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
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Load existing index
    index = load_index()
    existing_sessions = set(index.get("sessions", {}).keys())

    # Find all session files
    session_files = find_session_files()

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

    sys.exit(0)


if __name__ == "__main__":
    main()
