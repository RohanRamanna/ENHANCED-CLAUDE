# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Enhanced Claude: Self-Improving AI

This repository transforms Claude into an **Enhanced Claude** with four integrated systems, **all powered by automatic hooks**:

| System | Problem Solved | Hook | Automatic? |
|--------|---------------|------|------------|
| **Session Persistence** | Memory loss during context compaction | `session-recovery.py` | ✅ YES |
| **RLM (Large Documents)** | Documents too large for context window | `large-input-detector.py` | ✅ YES |
| **Auto-Skills** | Repetitive problem-solving | `skill-matcher.py`, `skill-tracker.py`, `detect-learning.py` | ✅ YES |
| **Skills Library** | Reusable patterns and workflows | N/A | Manual |

---

## The Hooks System

All automation is powered by **5 Python hooks** in `~/.claude/hooks/`:

```
~/.claude/hooks/
├── skill-matcher.py        # UserPromptSubmit: suggests matching skills
├── large-input-detector.py # UserPromptSubmit: detects large inputs
├── skill-tracker.py        # PostToolUse: tracks skill usage
├── detect-learning.py      # Stop: detects trial-and-error moments
└── session-recovery.py     # SessionStart: loads persistence files
```

### Hook Configuration (`~/.claude/settings.json`)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/skill-matcher.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/large-input-detector.py"}
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
          {"type": "command", "command": "python3 ~/.claude/hooks/detect-learning.py"}
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
```

---

## System 1: Session Persistence (Automatic)

**Problem**: When context compacts during long sessions, Claude loses memory.

**Solution**: Hook automatically injects persistence files after compaction.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│              SESSION PERSISTENCE (FULLY AUTOMATIC)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CONTEXT COMPACTS (manual /compact or auto)                     │
│       ↓                                                         │
│  SessionStart hook fires                                        │
│       ↓                                                         │
│  session-recovery.py INJECTS into Claude's context:             │
│    • context.md  → Current goal & decisions                     │
│    • todos.md    → Task progress                                │
│    • insights.md → Accumulated learnings                        │
│       ↓                                                         │
│  Claude continues with full context - NO MANUAL ACTION          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### The Three Persistence Files

| File | Purpose | When to Update |
|------|---------|----------------|
| `context.md` | Current goal, key decisions, important files | At task start, after major decisions |
| `todos.md` | Task progress tracking with phases | When starting/completing tasks |
| `insights.md` | Accumulated learnings & patterns | When discovering something reusable |

### What Claude Sees After Compaction

```
============================================================
SESSION RECOVERED - Persistence files loaded automatically
============================================================

### Current Goal & Decisions (context.md)
[Contents injected]

### Task Progress (todos.md)
[Contents injected]

### Accumulated Learnings (insights.md)
[Contents injected]

============================================================
Continue where you left off. Update these files as you work.
============================================================
```

---

## System 2: RLM for Large Documents (Automatic Detection)

**Problem**: Documents larger than ~200K tokens cannot fit in context.

**Solution**: Hook automatically detects large inputs and suggests RLM workflow.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│              RLM DETECTION (FULLY AUTOMATIC)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  USER SENDS MESSAGE                                             │
│       ↓                                                         │
│  large-input-detector.py analyzes input size                    │
│       ↓                                                         │
│  IF > 50K chars: Soft suggestion                                │
│  IF > 150K chars: Strong recommendation with workflow           │
│       ↓                                                         │
│  Claude guides user through RLM process                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### RLM Workflow (When Suggested)

1. **Probe**: `python rlm_tools/probe.py input.txt`
2. **Chunk**: `python rlm_tools/chunk.py input.txt --output rlm_context/chunks/`
3. **Process**: Spawn Task subagents for each chunk
4. **Aggregate**: `python rlm_tools/aggregate.py rlm_context/results/`

### RLM Tools

| Tool | Purpose |
|------|---------|
| `rlm_tools/probe.py` | Analyze input structure and size |
| `rlm_tools/chunk.py` | Split large files into processable pieces |
| `rlm_tools/aggregate.py` | Combine chunk results into final answer |
| `rlm_tools/sandbox.py` | Safe Python code execution |

---

## System 3: Auto-Skills (Fully Automatic)

**Problem**: Claude solves the same problems repeatedly.

**Solution**: Three hooks that automatically match, track, and learn skills.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                AUTO-SKILLS (FULLY AUTOMATIC)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SKILL MATCHING (skill-matcher.py)                           │
│     Trigger: Every user message                                 │
│     Action: Scores skills, suggests if score ≥ 10               │
│                                                                 │
│  2. SKILL TRACKING (skill-tracker.py)                           │
│     Trigger: After reading any SKILL.md                         │
│     Action: Updates useCount, lastUsed in metadata.json         │
│                                                                 │
│  3. LEARNING DETECTION (detect-learning.py)                     │
│     Trigger: Before Claude finishes responding                  │
│     Action: Detects 3+ failures → success, offers skill creation│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Skill Matching Algorithm

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 per tag |
| Skill name word match | +3 per word |
| Summary keyword match | +2 per word |
| Tag word match | +2 per tag |
| Recent use (< 7 days) | +1 |

**Thresholds**: ≥10 = suggest skill, <10 = no suggestion

### Example: Skill Match

**User**: "help me build a bun sqlite api with hono"

**Hook injects**:
```
[SKILL MATCH] Relevant skills detected:
  - hono-bun-sqlite-api (score:39): REST API with Hono, Bun and SQLite
    Load with: cat ~/.claude/skills/hono-bun-sqlite-api/SKILL.md
```

### Example: Learning Detection

**After solving with multiple failures**:
```
[LEARNING MOMENT DETECTED]
Detected 3 failures followed by success

You solved a problem through trial-and-error. Consider saving this as a reusable skill:
1. Run /skill-creator to document the solution
2. Or add to insights.md for future reference
```

---

## System 4: Skills Library (Manual)

**Purpose**: Reusable patterns, workflows, and specialized capabilities.

### Available Skills (15)

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (1) | markdown-to-pdf |
| **Workflow** (1) | udcp |
| **Fallback** (1) | web-research |

### How to Use

**Automatic** (via skill-matcher hook): Just describe what you need. Matching skills are suggested.

**Manual**: `/skill-name` or `cat ~/.claude/skills/skill-name/SKILL.md`

---

## Project Structure

```
PERSISTANT MEMORY/
├── CLAUDE.md                 # This file
├── context.md                # Session persistence: current goal
├── todos.md                  # Session persistence: task tracking
├── insights.md               # Session persistence: accumulated learnings
├── RESUME.md                 # Recovery instructions (legacy)
├── skills/                   # Skills library (15 skills)
│   └── */SKILL.md            # Individual skill files
├── rlm_tools/                # RLM processing tools
│   ├── probe.py              # Analyze input structure
│   ├── chunk.py              # Split large files
│   ├── aggregate.py          # Combine results
│   └── sandbox.py            # Safe code execution
├── rlm_context/              # RLM working directory
├── docs/
│   ├── HOW_TO_USE.md         # Complete usage guide
│   ├── rlm_paper_notes.md    # RLM theory
│   └── VERIFIED_TEST_RESULTS.md
└── requirements.txt
```

---

## Quick Reference

### What's Automatic

| Event | What Happens |
|-------|-------------|
| You send any message | Skills are matched and suggested |
| You paste large text | RLM workflow is suggested |
| Context compacts | Persistence files are auto-loaded |
| You solve via trial-and-error | Skill creation is offered |
| You read a SKILL.md | Usage is tracked |

### Commands

| Action | Command |
|--------|---------|
| Reload hooks | `/hooks` |
| Invoke a skill | `/skill-name` |
| Compact context | `/compact` |
| View skill index | `cat ~/.claude/skills/skill-index/index.json` |

---

## Verified Results

| Test | Size | Result |
|------|------|--------|
| 8-Book Corpus | 4.86M chars (~1.2M tokens) | ✅ Deaths verified via grep |
| FastAPI Codebase | 3.68M chars (~920K tokens) | ✅ Security classes verified |

See `docs/VERIFIED_TEST_RESULTS.md` for full verification.
