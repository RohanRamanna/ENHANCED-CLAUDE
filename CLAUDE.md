# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository Structure (Dual Repo Setup)

This project uses two GitHub repositories:

| Remote | Repository | Visibility | Purpose |
|--------|------------|------------|---------|
| `origin` | [persistent-memory-rlm](https://github.com/RohanRamanna/persistent-memory-rlm) | **Private** | Working copy with full history, experiments, personal data |
| `public` | [ENHANCED-CLAUDE](https://github.com/RohanRamanna/ENHANCED-CLAUDE) | **Public** | Cleaned version for sharing |

### Workflow

```bash
# Push to private (daily work)
git push origin main

# Push to public (when ready to share updates)
git checkout public-release
git merge main
# Clean up any personal paths if needed
git push public public-release:main
```

### Branch Mapping

- `main` → private repo (`origin`)
- `public-release` → public repo's `main` (`public`)

---

## Installation

Enhanced Claude can be installed as three separate systems or all together. Each system is self-contained and can be tested independently.

### System Installers

```
installers/
├── system-a-session-persistence/   # Session Persistence & Searchable History
├── system-b-rlm/                   # RLM Detection & Processing
└── system-c-auto-skills/           # Auto Skills & Skills Library
```

### What Each System Installs

| System | Hooks | Skills | Features |
|--------|-------|--------|----------|
| **A: Session Persistence** | 5 hooks | 1 (history) | Context recovery after compaction, searchable history |
| **B: RLM Detection** | 2 hooks | 1 (rlm) | Large document detection, RLM tools |
| **C: Auto Skills** | 5 hooks | 18 skills | Skill matching, learning detection, full skills library |

### Quick Install

**macOS/Linux:**
```bash
# Install a specific system
./installers/system-a-session-persistence/install.sh
./installers/system-b-rlm/install.sh
./installers/system-c-auto-skills/install.sh

# Uninstall
./installers/system-a-session-persistence/uninstall.sh
```

**Windows:**
```cmd
installers\system-a-session-persistence\install.bat
installers\system-b-rlm\install.bat
installers\system-c-auto-skills\install.bat
```

### Notes

- All installers auto-merge with existing `settings.json` (no overwrites)
- Timestamped backups are created before installation
- Uninstallers preserve data (sessions, history, tools)
- `hook_logger.py` is shared across systems (not removed by uninstallers)
- Run `/hooks` after installation to reload hooks

---

## Enhanced Claude: Self-Improving AI

This repository transforms Claude into an **Enhanced Claude** with five integrated systems, **all powered by automatic hooks**:

| System | Problem Solved | Hook | Automatic? |
|--------|---------------|------|------------|
| **Session Persistence** | Memory loss during context compaction | `session-recovery.py`, `live-session-indexer.py` | ✅ YES (RLM-based) |
| **RLM (Large Documents)** | Documents too large for context window | `large-input-detector.py` | ✅ YES |
| **Auto-Skills** | Repetitive problem-solving | `skill-matcher.py`, `skill-tracker.py`, `detect-learning.py` | ✅ YES |
| **Searchable History** | Finding past solutions without filling context | `history-indexer.py`, `history-search.py` | ✅ YES |
| **Skills Library** | Reusable patterns and workflows | N/A | Manual |

---

## The Hooks System

All automation is powered by **9 Python hooks** in `~/.claude/hooks/`:

```
~/.claude/hooks/
├── hook_logger.py            # Shared logging utility for all hooks
├── skill-matcher.py          # UserPromptSubmit: suggests matching skills
├── large-input-detector.py   # UserPromptSubmit: detects large inputs
├── history-search.py         # UserPromptSubmit: suggests relevant history
├── learning-moment-pickup.py # UserPromptSubmit: picks up pending learning moments
├── skill-tracker.py          # PostToolUse: tracks skill usage
├── detect-learning.py        # Stop: detects learning moments, saves to file
├── history-indexer.py        # Stop: indexes conversation history
├── live-session-indexer.py   # Stop: chunks live session for RLM recovery
└── session-recovery.py       # SessionStart: RLM-based intelligent recovery
```

### Hook Configuration (`~/.claude/settings.json`)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/skill-matcher.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/large-input-detector.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/history-search.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/learning-moment-pickup.py"}
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
```

### Known Hook Bugs & Workarounds

**IMPORTANT**: Claude Code has a known bug ([Issue #13912](https://github.com/anthropics/claude-code/issues/13912)) where UserPromptSubmit hooks show "hook error" even when working correctly.

| Issue | Workaround |
|-------|------------|
| Any stdout causes "hook error" | Output **nothing** when hook has nothing to report (just `sys.exit(0)`) |
| Paths with `~` may not work | Use absolute paths: `/Users/username/.claude/hooks/...` |
| Hooks with output show error | **Cosmetic only** - context IS injected correctly, ignore the error |

**Output Rules for UserPromptSubmit Hooks:**
```python
# CORRECT - no output when nothing to report
if no_matches:
    sys.exit(0)  # Just exit, no output

# CORRECT - output only when you have context to add
if matches:
    print(json.dumps({"hookSpecificOutput": {"additionalContext": "..."}}), flush=True)
    sys.exit(0)
```

**Stop Hooks use different schema:**
```python
# Stop hooks output:
print('{"continue": true}')  # or {"continue": true, "systemMessage": "..."}
```

---

## System 1: Session Persistence (RLM-based, Automatic)

**Problem**: When context compacts during long sessions, Claude loses memory. Manual summaries miss details.

**Solution**: Two hooks work together for intelligent, zero-loss recovery:
1. **live-session-indexer.py** (Stop) - Chunks the live session into semantic segments
2. **session-recovery.py** (SessionStart) - Intelligently loads most relevant segments after compaction

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│         RLM-BASED SESSION PERSISTENCE (FULLY AUTOMATIC)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DURING CONVERSATION (Stop hook after each turn):               │
│  live-session-indexer.py chunks conversation into segments:     │
│    • Segment boundaries: task completion, topic change, time    │
│    • Each segment: topics, files, tools, decisions, summary     │
│       ↓                                                         │
│  ~/.claude/sessions/<session-id>/segments.json                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AFTER COMPACTION (SessionStart hook):                          │
│  session-recovery.py intelligently loads context:               │
│    1. Load persistence files (context.md, todos.md, insights.md)│
│    2. Load segment index for current session                    │
│    3. Score segments: recency + task relevance + active work    │
│    4. Extract ACTUAL content from JSONL for top segments        │
│    5. Inject relevant context (~2000 tokens of conversation)    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Segment Scoring Algorithm

| Factor | Points | Description |
|--------|--------|-------------|
| Recency | 0-50 | Newer segments score higher (5 pts lost per hour) |
| Task match | 10/topic | Segments related to pending todos |
| Active work | +15 | Segments with Edit/Write tool usage |
| Decisions | +10 | Segments containing key decisions |
| Task completed | +10 | Segments ending with completed tasks |

### The Three Persistence Files (Still Updated)

| File | Purpose | When to Update |
|------|---------|----------------|
| `context.md` | Current goal, key decisions, important files | At task start, after major decisions |
| `todos.md` | Task progress tracking with phases | When starting/completing tasks |
| `insights.md` | Accumulated learnings & patterns | When discovering something reusable |

### What Claude Sees After Compaction

```
======================================================================
SESSION RECOVERED - RLM-based intelligent context loading
======================================================================

### Current Goal & Decisions (context.md)
[Contents injected]

### Task Progress (todos.md)
[Contents injected]

### Accumulated Learnings (insights.md)
[Contents injected]

======================================================================
RELEVANT CONVERSATION CONTEXT (RLM-recovered)
======================================================================

--- Segment seg-002 (score: 91) ---
Topics: context, session, hooks, persistence
Summary: Topics: context, session | Files: 7 | Tools: TodoWrite, Write, Edit

Conversation excerpt:
USER: work on the priority pending item
ASSISTANT: I'll work on RLM-based live session persistence...
[Modified: live-session-indexer.py]
[Completed: Create live-session-indexer.py hook]

[Loaded 3 relevant segments from session history]

======================================================================
Continue where you left off. Context has been intelligently restored.
======================================================================
```

### Storage Location

```
~/.claude/sessions/<session-id>/segments.json
```

Contains segment index with pointers to JSONL content (zero data duplication).

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
| `rlm_tools/chunk.py` | Split large files (supports `--strategy code` for semantic chunking, `--progress` for ETA) |
| `rlm_tools/aggregate.py` | Combine chunk results into final answer |
| `rlm_tools/parallel_process.py` | Coordinate parallel chunk processing (up to 10x speedup) |
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

## System 4: Searchable History (Automatic)

**Problem**: Past solutions are lost when you need them. Searching means loading entire conversations into context.

**Solution**: Smart index points to WHERE information is, without loading it. Only retrieve what's needed.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│              SEARCHABLE HISTORY (FULLY AUTOMATIC)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EXISTING DATA (already stored by Claude Code)                  │
│  ~/.claude/projects/*/*.jsonl  → Full session transcripts       │
│       ↓                                                         │
│  history-indexer.py (Stop hook)                                 │
│  Extracts: topics, files, tools → Builds index                  │
│       ↓                                                         │
│  ~/.claude/history/index.json  → Searchable index               │
│       ↓                                                         │
│  history-search.py (UserPromptSubmit hook)                      │
│  Matches query → Suggests relevant past sessions                │
│       ↓                                                         │
│  /history load <session>  → Retrieve only what's needed         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Core Principle

**Zero data duplication**: The index only contains pointers (session ID, line ranges, topics), not content. Full history already exists in JSONL files.

### What You See

When you ask about something you've worked on before:
```
[HISTORY MATCH] Found relevant past work in this project:
  - 2026-01-15: hooks, automation (score:14, 1440 lines)
    Load: /history load 23a35a50
```

### Commands

| Command | Description |
|---------|-------------|
| `/history search <query>` | Search current project |
| `/history search --all <query>` | Search all projects |
| `/history load <session_id>` | Load session content |
| `/history topics` | List indexed topics |
| `/history recent` | Show recent sessions |
| `/history rebuild` | Force reindex |

---

## System 5: Skills Library (Manual)

**Purpose**: Reusable patterns, workflows, and specialized capabilities.

### Available Skills (17)

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (3) | markdown-to-pdf, history, rlm |
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
├── installers/               # System installers
│   ├── system-a-session-persistence/
│   │   ├── install.sh        # macOS/Linux installer
│   │   ├── install.bat       # Windows installer
│   │   ├── uninstall.sh      # macOS/Linux uninstaller
│   │   └── uninstall.bat     # Windows uninstaller
│   ├── system-b-rlm/
│   │   └── ...               # Same structure
│   └── system-c-auto-skills/
│       └── ...               # Same structure
├── skills/                   # Skills library (18 skills)
│   └── */SKILL.md            # Individual skill files
├── rlm_tools/                # RLM processing tools
│   ├── probe.py              # Analyze input structure
│   ├── chunk.py              # Split large files (semantic code chunking, progress tracking)
│   ├── aggregate.py          # Combine results
│   ├── parallel_process.py   # Coordinate parallel processing
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
| You send any message | Relevant history is suggested |
| You paste large text | RLM workflow is suggested |
| Context compacts | Persistence files + relevant segments are auto-loaded |
| Claude finishes responding | Live session is chunked into segments |
| You solve via trial-and-error | Skill creation is offered |
| You read a SKILL.md | Usage is tracked |
| Claude finishes responding | History index is updated |

### Commands

| Action | Command |
|--------|---------|
| Reload hooks | `/hooks` |
| Invoke a skill | `/skill-name` |
| Compact context | `/compact` |
| Search history | `/history search <query>` |
| Load past session | `/history load <session_id>` |
| View skill index | `cat ~/.claude/skills/skill-index/index.json` |

---

## Verified Results

| Test | Size | Result |
|------|------|--------|
| 8-Book Corpus | 4.86M chars (~1.2M tokens) | ✅ Deaths verified via grep |
| FastAPI Codebase | 3.68M chars (~920K tokens) | ✅ Security classes verified |

See `docs/VERIFIED_TEST_RESULTS.md` for full verification.
