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
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Get the user prompt and current working directory
    prompt = hook_input.get("prompt", "")
    cwd = hook_input.get("cwd", "")

    if not prompt or len(prompt) < 10:
        sys.exit(0)

    # Prepare prompt for matching
    prompt_lower = prompt.lower()
    prompt_words = set(prompt_lower.replace("-", " ").replace("_", " ").split())
    meaningful_words = prompt_words - COMMON_WORDS

    if len(meaningful_words) < 2:
        sys.exit(0)  # Not enough meaningful words to search

    # Load history index
    index = load_index()
    sessions = index.get("sessions", {})

    if not sessions:
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
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
