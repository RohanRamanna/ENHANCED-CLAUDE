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

### RLM Architecture Mapping

| Paper Component | Claude Code Equivalent |
|-----------------|----------------------|
| Root LM | Main conversation |
| Sub-LM (llm_query) | Task tool with subagents |
| REPL Environment | Bash tool + filesystem |
| context variable | Files on disk |
| FINAL() output | Return to main conversation |

**Key insight**: No external API key needed - Claude Code IS the RLM.

### When to Use Each System

| Scenario | System | Why |
|----------|--------|-----|
| Context compacted | Session Persistence | Auto-loaded via hook |
| Large input (>50K chars) | RLM | Auto-detected via hook |
| Need a specific skill | Auto-Skills | Auto-matched via hook |
| Trial-and-error solved | Learning Detection | Auto-detected via hook |

## Patterns Identified

### Conservative Learning Detection

Only trigger skill creation offers when:
- 3+ tool failures followed by success
- OR 5+ "let me try" phrases in conversation

This prevents false positives and annoying prompts.

### Skill Matching Algorithm (Implemented)

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 per tag |
| Skill name word match | +3 per word |
| Summary keyword match | +2 per word |
| Tag word match | +2 per tag |
| Recent use (< 7 days) | +1 |

**Threshold**: ≥10 = suggest skill

### Effective RLM Query Design

- Be specific: "Find all character deaths" > "Analyze the books"
- Request structured output: "List with book name, character, cause"
- Include verification hooks: "Include line numbers or quotes"

### Parallel Subagent Batching

- 4 chunks per subagent works well
- 3-6 parallel subagents is efficient
- More subagents = faster but higher cost

## Gotchas & Pitfalls

### Hook Debugging

- Test hooks manually: `echo '{"prompt": "test"}' | python3 hook.py`
- Hooks must exit with code 0 for success
- JSON output must be valid
- Hooks have 60-second timeout

### Session Recovery Hook Path

The `session-recovery.py` hook has a hardcoded PROJECT_DIR. For other projects, either:
1. Create project-specific hooks, or
2. Use `$CLAUDE_PROJECT_DIR` environment variable

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
├── settings.json           # Hook configuration
├── hooks/
│   ├── skill-matcher.py    # UserPromptSubmit: match skills
│   ├── large-input-detector.py  # UserPromptSubmit: detect large inputs
│   ├── skill-tracker.py    # PostToolUse: track usage
│   ├── detect-learning.py  # Stop: detect learning moments
│   └── session-recovery.py # SessionStart: load persistence files
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

## Remaining Questions

- What's the optimal chunk size for different document types?
- How to handle cross-chunk references more elegantly?
- How does performance vary across programming languages?
- Should skills be project-specific or always global?

---

**Last Updated**: 2026-01-18
