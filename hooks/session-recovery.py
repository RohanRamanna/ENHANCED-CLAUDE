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
