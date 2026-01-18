# Insights

> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. Automatically injected by `session-recovery.py` hook.

## Key Learnings

### Claude Code Hooks Are Powerful

Hooks enable truly automatic behavior - not just documentation Claude should follow, but actual code that runs on events.

| Hook Event | When | Use For |
|------------|------|---------|
| `UserPromptSubmit` | Every message | Context injection, validation |
| `PostToolUse` | After any tool | Tracking, logging |
| `Stop` | Before Claude finishes | Analysis, blocking |
| `SessionStart` | On start/resume/compact | State recovery |

**Key insight**: Hooks output JSON with `additionalContext` to inject content into Claude's context.

### Hook Input/Output Pattern

All hooks receive JSON via stdin:
```python
import json
import sys

hook_input = json.load(sys.stdin)  # Contains event-specific data
# ... process ...
output = {"hookSpecificOutput": {"additionalContext": "..."}}
print(json.dumps(output))
sys.exit(0)
```

### User vs Project Settings

- **Project settings** (`.claude/settings.json`): Per-project hooks
- **User settings** (`~/.claude/settings.json`): Global hooks, higher priority

For global automation (skills, session recovery), use user settings.

### Searchable History: Zero Data Duplication

The key insight: **index WHERE data is, not WHAT it contains**.

- Claude Code already stores full conversation history in JSONL files
- We just build a lightweight index with pointers (session ID, line ranges, topics)
- On search, only load the relevant segment, not the whole history
- No summarization = no data loss

### RLM-based Live Session Persistence

Apply RLM principles to the CURRENT session for zero data loss after compaction:

1. **Segment Detection** - Natural boundaries (task completion, topic change, time gaps)
2. **Segment Scoring** - Recency + task relevance + active work indicators
3. **Content Extraction** - Load actual JSONL content, not just metadata

## Patterns Identified

### Skill Matching Algorithm

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 per tag |
| Skill name word match | +3 per word |
| Summary keyword match | +2 per word |
| Tag word match | +2 per tag |
| Recent use (< 7 days) | +1 |

**Threshold**: >= 10 = suggest skill

### Conservative Learning Detection

Only trigger skill creation offers when:
- 3+ tool failures followed by success
- OR 5+ "let me try" phrases in conversation

This prevents false positives and annoying prompts.

## Gotchas & Pitfalls

### Hook Debugging

- Test hooks manually: `echo '{"prompt": "test"}' | python3 hook.py`
- Hooks must exit with code 0 for success
- JSON output must be valid
- Hooks have 60-second timeout

### Project Directory Detection

Hooks use `os.getcwd()` to detect the project directory. If you run Claude Code from a different directory, ensure you're in the project root.

Alternatively, set `CLAUDE_PROJECT_DIR` environment variable.

---

**Last Updated**: 2026-01-18
