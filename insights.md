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

### Stop Hook Schema Difference

**Important**: Stop hooks use a DIFFERENT output schema than other hooks:
- **UserPromptSubmit**: `hookSpecificOutput.additionalContext`
- **Stop**: `systemMessage` (NOT `hookSpecificOutput`)

```python
# Wrong for Stop hooks:
output = {"hookSpecificOutput": {"additionalContext": "..."}}

# Correct for Stop hooks:
output = {"continue": True, "systemMessage": "..."}
```

### Hook Logging Pattern

All hooks now use a shared logging utility (`hook_logger.py`) for consistent debugging:
```python
from hook_logger import HookLogger
logger = HookLogger("hook-name")
logger.info("Hook started")
logger.debug("Processing details")
logger.error("Something went wrong", exc_info=True)
```

Logs are stored in `~/.claude/logs/hooks/{hook-name}.log` with automatic 5MB rotation.

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

### Parallel Subagent Batching

- 4 chunks per subagent works well
- 3-6 parallel subagents is efficient
- More subagents = faster but higher cost
- Use `rlm_tools/parallel_process.py` to generate batch configurations
- Spawn ALL batches in a single response for true parallelism (up to 10x speedup)

## Gotchas & Pitfalls

### Hook Debugging

- Test hooks manually: `echo '{"prompt": "test"}' | python3 hook.py`
- Hooks must exit with code 0 for success
- JSON output must be valid
- Hooks have 60-second timeout

### Project Directory Detection

Hooks use dynamic project detection:
- Uses `CLAUDE_PROJECT_DIR` environment variable if set
- Falls back to `os.getcwd()` (current working directory)
- No hardcoded paths needed

### Skills Location

Skills are in `~/.claude/skills/` (global), not project-specific. This means:
- Skills work across all projects
- skill-matcher.py uses this path
- skill-tracker.py updates metadata here

### Chunk Overlap Matters

- Default 500 chars might miss context at boundaries
- For technical/legal docs, consider 1000-2000 char overlap

## The Complete Automation Stack

```
~/.claude/
├── settings.json           # Hook configuration (8 hooks)
├── logs/hooks/             # Hook debug logs (auto-rotated)
├── hooks/
│   ├── hook_logger.py      # Shared logging utility
│   ├── skill-matcher.py    # UserPromptSubmit: match skills
│   ├── large-input-detector.py  # UserPromptSubmit: detect large inputs
│   ├── history-search.py   # UserPromptSubmit: suggest past sessions
│   ├── skill-tracker.py    # PostToolUse: track usage
│   ├── detect-learning.py  # Stop: detect learning moments
│   ├── history-indexer.py  # Stop: index conversation history
│   ├── live-session-indexer.py  # Stop: chunk live session into segments
│   └── session-recovery.py # SessionStart: RLM-based intelligent recovery
├── sessions/
│   └── <session-id>/
│       └── segments.json   # Live session segment index
├── history/
│   └── index.json          # Searchable history index
└── skills/
    ├── skill-index/
    │   └── index.json      # Central skill index
    └── */
        ├── SKILL.md        # Skill content
        └── metadata.json   # Usage tracking
```

## Open Questions (Resolved)

- ~~How does RLM perform on code?~~ → **Works excellently** (FastAPI test)
- ~~How to make skills self-improving?~~ → **Auto-skills hooks** (matcher, tracker, learning detection)
- ~~Can we detect when RLM is needed automatically?~~ → **Yes, via large-input-detector.py hook**
- ~~How to make session persistence automatic?~~ → **Yes, via session-recovery.py hook**
- ~~How to search past conversations without loading everything?~~ → **Searchable history with index pointers**

### Semantic Code Chunking Works Well

The `--strategy code` option intelligently splits code at function/class boundaries:
- Auto-detects language from code patterns (Python colons, TS types, etc.)
- Keeps related code together (class with methods in same chunk)
- Entities metadata helps understand what each chunk contains

**Language detection patterns**:
| Language | Key Indicators |
|----------|---------------|
| Python | `def `, `class `, trailing `:` |
| TypeScript | `interface`, `type =`, `: string/number` |
| JavaScript | `function`, `const =`, `=>` |
| Go | `func`, `package`, `type struct` |
| Rust | `fn`, `impl`, `struct`, `enum` |

## Remaining Questions

- What's the optimal chunk size for different document types?
- How to handle cross-chunk references more elegantly?

---

**Last Updated**: 2026-01-19
