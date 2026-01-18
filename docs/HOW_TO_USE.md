# How to Use Enhanced Claude

This repository provides **five integrated systems** for Claude Code, all powered by **automatic hooks**. Just start Claude Code in this directory and everything works automatically.

---

## Table of Contents

1. [Quick Start](#quick-start) - Get running in 30 seconds
2. [The Hooks System](#the-hooks-system) - How automation works
3. [System 1: Session Persistence](#system-1-session-persistence) - RLM-based memory across context compaction
4. [System 2: RLM for Large Documents](#system-2-rlm-for-large-documents) - Processing oversized inputs
5. [System 3: Auto-Skills](#system-3-auto-skills) - Self-improving skill system
6. [System 4: Searchable History](#system-4-searchable-history) - Find past solutions without filling context
7. [System 5: Skills Library](#system-5-skills-library) - On-demand skill loading
8. [Installation](#installation)
9. [RLM Detailed Workflow](#rlm-detailed-workflow)
10. [Tool Reference](#tool-reference)
11. [Examples](#examples)
12. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Step 1: Install Hooks (One-Time Setup)

The hooks are already configured in `~/.claude/settings.json`. If you're setting up fresh:

```bash
# Copy hooks to your Claude config
cp -r hooks/* ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.py
```

### Step 2: Just Use Claude Code

That's it! All 5 systems work automatically:

| What Happens | Automatic Behavior |
|--------------|-------------------|
| You send a message | Skills are matched and suggested |
| You send a message | Relevant past work is suggested |
| You paste large text (>50K chars) | RLM workflow is suggested |
| Context compacts | Persistence files + relevant segments auto-loaded (RLM-based) |
| Claude finishes responding | Live session is chunked into segments |
| Claude finishes responding | History index is updated |
| You solve via trial-and-error | Skill creation is offered |
| You read a SKILL.md | Usage is tracked |

**No manual intervention needed.**

---

## The Hooks System

Enhanced Claude is powered by **8 Python hooks** that run automatically:

```
~/.claude/hooks/
├── skill-matcher.py        # Suggests matching skills (UserPromptSubmit)
├── large-input-detector.py # Detects large inputs, suggests RLM (UserPromptSubmit)
├── history-search.py       # Suggests relevant past sessions (UserPromptSubmit)
├── skill-tracker.py        # Tracks skill usage (PostToolUse)
├── detect-learning.py      # Detects trial-and-error moments (Stop)
├── history-indexer.py      # Indexes conversation history (Stop)
├── live-session-indexer.py # Chunks live session into segments (Stop)
└── session-recovery.py     # RLM-based intelligent recovery (SessionStart)
```

### Hook Configuration

All hooks are configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "python3 ~/.claude/hooks/skill-matcher.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/large-input-detector.py"},
          {"type": "command", "command": "python3 ~/.claude/hooks/history-search.py"}
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

### Hook Events Explained

| Event | When It Fires | Hook | Action |
|-------|--------------|------|--------|
| `UserPromptSubmit` | Every user message | `skill-matcher.py` | Scores and suggests matching skills |
| `UserPromptSubmit` | Every user message | `large-input-detector.py` | Detects large inputs, suggests RLM |
| `UserPromptSubmit` | Every user message | `history-search.py` | Suggests relevant past sessions |
| `PostToolUse` | After Read tool | `skill-tracker.py` | Updates skill metadata on SKILL.md reads |
| `Stop` | Before Claude finishes | `detect-learning.py` | Detects trial-and-error, offers skill creation |
| `Stop` | Before Claude finishes | `history-indexer.py` | Updates searchable history index |
| `Stop` | Before Claude finishes | `live-session-indexer.py` | Chunks conversation into segments |
| `SessionStart` | After /compact or /resume | `session-recovery.py` | RLM-based intelligent context recovery |

---

## System 1: Session Persistence (RLM-Based)

**Problem**: When Claude's context window fills up, it compacts and loses memory. Manual summaries miss details.

**Solution**: Two hooks work together for intelligent, zero-loss recovery:
1. **live-session-indexer.py** (Stop) - Chunks the live session into semantic segments
2. **session-recovery.py** (SessionStart) - Intelligently loads most relevant segments after compaction

### How It Works (Fully Automatic)

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

### What You See After Compaction

After `/compact` or automatic compaction, Claude receives:

```
======================================================================
SESSION RECOVERED - RLM-based intelligent context loading
======================================================================

### Current Goal & Decisions (context.md)
[Full contents of context.md]

### Task Progress (todos.md)
[Full contents of todos.md]

### Accumulated Learnings (insights.md)
[Full contents of insights.md]

======================================================================
RELEVANT CONVERSATION CONTEXT (RLM-recovered)
======================================================================

--- Segment seg-002 (score: 61) ---
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

**Zero data loss** - Claude sees actual conversation excerpts, not just summaries.

---

## System 2: RLM for Large Documents

**Problem**: Documents larger than ~200K tokens cannot fit in Claude's context window.

**Solution**: Automatic detection + suggested workflow for chunking and processing.

### How It Works (Automatic Detection)

```
┌─────────────────────────────────────────────────────────────────┐
│                  RLM DETECTION (AUTOMATIC)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  USER PASTES LARGE TEXT                                         │
│       ↓                                                         │
│  UserPromptSubmit hook fires                                    │
│       ↓                                                         │
│  large-input-detector.py analyzes input size                    │
│       ↓                                                         │
│  IF input > 50K chars:                                          │
│    → Soft suggestion: "Consider using RLM workflow"             │
│                                                                 │
│  IF input > 150K chars:                                         │
│    → Strong recommendation with full RLM workflow               │
│       ↓                                                         │
│  Claude receives suggestion and guides user through RLM         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What You See for Large Inputs

**For inputs 50K-150K characters:**
```
[LARGE INPUT NOTICE]
Input size: 60,000 characters (~15,000 tokens)

Consider using RLM workflow if you need comprehensive analysis:
- RLM tools available in: /path/to/rlm_tools/
- Run: python rlm_tools/probe.py <file> to analyze structure
```

**For inputs >150K characters:**
```
[LARGE INPUT DETECTED - RLM RECOMMENDED]
Input size: 200,000 characters (~50,000 tokens)
This exceeds comfortable context limits.

RECOMMENDED: Use RLM (Recursive Language Model) workflow:
1. Save input to file: rlm_context/input.txt
2. Probe structure: python rlm_tools/probe.py rlm_context/input.txt
3. Chunk: python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
4. Process chunks with parallel Task subagents
5. Aggregate: python rlm_tools/aggregate.py rlm_context/results/

This ensures accurate processing of the full document.
```

---

## System 3: Auto-Skills

**Problem**: Claude solves the same problems repeatedly without remembering solutions.

**Solution**: Three hooks that automatically match, track, and learn skills.

### How It Works (Fully Automatic)

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTO-SKILLS (AUTOMATIC)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SKILL MATCHING (skill-matcher.py)                           │
│     Trigger: Every user message                                 │
│     Action: Scores skills, suggests matches (score ≥10)         │
│                                                                 │
│  2. SKILL TRACKING (skill-tracker.py)                           │
│     Trigger: After reading any SKILL.md file                    │
│     Action: Updates useCount, lastUsed in metadata.json         │
│                                                                 │
│  3. LEARNING DETECTION (detect-learning.py)                     │
│     Trigger: Before Claude finishes responding                  │
│     Action: Detects 3+ failures → success pattern               │
│             Suggests creating a new skill                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Skill Matching Example

**User says**: "help me build a bun sqlite api with hono"

**Hook automatically injects**:
```
[SKILL MATCH] Relevant skills detected:
  - hono-bun-sqlite-api (score:39): REST API with Hono, Bun and SQLite
    Load with: cat ~/.claude/skills/hono-bun-sqlite-api/SKILL.md
```

### Learning Detection Example

After Claude solves something with multiple failed attempts:

```
[LEARNING MOMENT DETECTED]
Detected 3 failures followed by success

You solved a problem through trial-and-error. Consider saving this as a reusable skill:
1. Run /skill-creator to document the solution
2. Or add to insights.md for future reference

This helps avoid re-discovering the same solution later.
```

### Skill Matching Algorithm

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 per tag |
| Skill name word match | +3 per word |
| Summary keyword match | +2 per word |
| Tag word match | +2 per tag |
| Recent use (< 7 days) | +1 |

**Thresholds**: ≥10 = strong match (suggest), 5-9 = possible match, <5 = no match

---

## System 4: Searchable History

**Problem**: Past solutions are lost when you need them. Searching means loading entire conversations into context.

**Solution**: Smart index points to WHERE information is, without loading it. Only retrieve what's needed.

### How It Works (Fully Automatic)

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

### History Commands

| Command | Description |
|---------|-------------|
| `/history search <query>` | Search current project |
| `/history search --all <query>` | Search all projects |
| `/history load <session_id>` | Load session content |
| `/history topics` | List indexed topics |
| `/history recent` | Show recent sessions |
| `/history rebuild` | Force reindex |

---

## System 5: Skills Library

**Problem**: Useful patterns and workflows are forgotten between sessions.

**Solution**: 16 reusable skills loaded on-demand.

### Available Skills

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (3) | markdown-to-pdf, history, rlm |
| **Workflow** (1) | udcp |
| **Fallback** (1) | web-research |

### How to Use Skills

**Automatic** (via skill-matcher hook):
```
Just describe what you want. Matching skills are suggested automatically.
```

**Manual**:
```bash
# Invoke a skill directly
/skill-name

# Or read the skill file
cat ~/.claude/skills/skill-name/SKILL.md
```

---

## Installation

### Prerequisites

- **Claude Code** (CLI) - The system uses Claude Code's native tools
- **Python 3.8+** - For running hooks and RLM tools

### One-Time Setup

```bash
# 1. Clone or download this repository
cd "/path/to/PERSISTANT MEMORY"

# 2. Create hooks directory
mkdir -p ~/.claude/hooks

# 3. Copy hook scripts (if not already done)
# The hooks are in this repo and should be copied to ~/.claude/hooks/
# They are:
#   - skill-matcher.py
#   - large-input-detector.py
#   - skill-tracker.py
#   - detect-learning.py
#   - session-recovery.py

# 4. Make hooks executable
chmod +x ~/.claude/hooks/*.py

# 5. Verify settings.json has hook configuration
cat ~/.claude/settings.json

# 6. Reload hooks in Claude Code
# Run: /hooks
# Or restart Claude Code
```

### Optional Dependencies

```bash
# For PDF processing
pip install pdfplumber

# For safe code execution (sandbox.py)
pip install RestrictedPython

# Or install all
pip install -r requirements.txt
```

---

## RLM Detailed Workflow

When the large-input-detector suggests RLM, follow this workflow:

### Step 1: Prepare Your Input

```bash
# For text files
cp /path/to/large_document.txt rlm_context/input.txt

# For PDFs
python -c "
import pdfplumber
with pdfplumber.open('document.pdf') as pdf:
    text = '\n'.join(p.extract_text() or '' for p in pdf.pages)
open('rlm_context/input.txt', 'w').write(text)
"
```

### Step 2: Probe the Structure

```bash
python rlm_tools/probe.py rlm_context/input.txt
```

**Output**:
```
=== File Analysis ===
File: rlm_context/input.txt
Size: 500,000 characters
Estimated tokens: ~125,000
Recommended chunks: 25 (at 200,000 chars each)
```

### Step 3: Chunk the Input

```bash
python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
```

### Step 4: Process with Task Subagents

Tell Claude Code:
```
Process these chunks with Task subagents. For each chunk, extract [YOUR QUERY]
and save results to rlm_context/results/
```

Claude Code spawns parallel subagents automatically.

### Step 5: Aggregate Results

```bash
python rlm_tools/aggregate.py rlm_context/results/ --query "Your original query"
```

### Step 6: Get Final Answer

Read the aggregated results or ask Claude to summarize them.

---

## Tool Reference

### Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `skill-matcher.py` | UserPromptSubmit | Match skills to user prompts |
| `large-input-detector.py` | UserPromptSubmit | Detect large inputs, suggest RLM |
| `history-search.py` | UserPromptSubmit | Suggest relevant past sessions |
| `skill-tracker.py` | PostToolUse (Read) | Track SKILL.md reads |
| `detect-learning.py` | Stop | Detect trial-and-error moments |
| `history-indexer.py` | Stop | Index conversation history |
| `live-session-indexer.py` | Stop | Chunk live session into segments |
| `session-recovery.py` | SessionStart | RLM-based intelligent recovery |

### RLM Tools

| Tool | Purpose |
|------|---------|
| `probe.py` | Analyze input structure and size |
| `chunk.py` | Split large files (supports semantic code chunking and progress tracking) |
| `aggregate.py` | Combine chunk results into final answer |
| `parallel_process.py` | Coordinate parallel chunk processing (up to 10x speedup) |
| `sandbox.py` | Safe Python code execution |

### probe.py Options

| Flag | Description | Default |
|------|-------------|---------|
| `<file>` | File(s) to analyze | Required |
| `--json` | Output in JSON format | False |

### chunk.py Options

| Flag | Description | Default |
|------|-------------|---------|
| `<file>` | File to chunk | Required |
| `--size` | Chunk size in characters | 200,000 |
| `--strategy` | `size`, `lines`, `headers`, `paragraphs`, `code` | `size` |
| `--output` | Output directory | `./chunks/` |
| `--overlap` | Character overlap between chunks | 500 |
| `--progress` | Show progress bar with ETA | False |
| `--language` | Force language for code strategy | Auto-detect |

**Semantic Code Chunking** (`--strategy code`):
- Splits at function/class boundaries
- Auto-detects Python, JavaScript, TypeScript, Go, Rust, Java
- Keeps related code together (classes with their methods)

### aggregate.py Options

| Flag | Description | Default |
|------|-------------|---------|
| `<dir>` | Results directory | Required |
| `--query` | Original query for context | None |
| `--format` | `text`, `json`, `summary` | `text` |
| `--output` | Output file path | `aggregated_results.txt` |

---

## Examples

### Example 1: Normal Usage (Auto-Skills)

**You say**: "help me set up a REST API with Bun"

**What happens automatically**:
1. `skill-matcher.py` runs, finds `hono-bun-sqlite-api` (score: 35+)
2. Claude sees: `[SKILL MATCH] hono-bun-sqlite-api - Load with: cat ~/.claude/skills/...`
3. Claude loads the skill and follows its instructions
4. `skill-tracker.py` updates the skill's usage count

### Example 2: Large Document Analysis

**You paste**: A 200,000 character document

**What happens automatically**:
1. `large-input-detector.py` runs, detects large input
2. Claude sees: `[LARGE INPUT DETECTED - RLM RECOMMENDED]` with full workflow
3. Claude guides you through the RLM process

### Example 3: Context Compaction Recovery (RLM-Based)

**Context compacts** during a long session

**What happens automatically**:
1. `live-session-indexer.py` has been chunking conversation into segments during the session
2. `session-recovery.py` runs after compaction
3. Claude receives full contents of context.md, todos.md, insights.md
4. Claude also receives **actual conversation excerpts** from the most relevant segments
5. Claude continues with both high-level context AND specific conversation details

### Example 4: Learning Moment

**You solve a problem** after 3 failed attempts

**What happens automatically**:
1. `detect-learning.py` analyzes the conversation
2. Claude sees: `[LEARNING MOMENT DETECTED]`
3. Claude offers to create a skill for the solution

---

## Troubleshooting

### Hooks not running?

```bash
# 1. Check hooks are executable
ls -la ~/.claude/hooks/

# 2. Reload hooks in Claude Code
# Type: /hooks

# 3. Or restart Claude Code
```

### Skill matching not working?

```bash
# Test the hook manually
echo '{"prompt": "help me with bun sqlite"}' | python3 ~/.claude/hooks/skill-matcher.py
```

### Session recovery not loading files?

1. Check persistence files exist in the project directory
2. Check `session-recovery.py` has correct PROJECT_DIR path
3. Test manually: `echo '{}' | python3 ~/.claude/hooks/session-recovery.py`

### Large input detection not triggering?

The threshold is 50K characters. For smaller inputs, RLM isn't needed.

---

## Summary: What's Automatic

| Feature | Automatic? | Hook |
|---------|------------|------|
| Skill matching | ✅ | skill-matcher.py |
| Skill usage tracking | ✅ | skill-tracker.py |
| Learning detection | ✅ | detect-learning.py |
| Session recovery (RLM-based) | ✅ | session-recovery.py |
| Live session chunking | ✅ | live-session-indexer.py |
| Large input detection | ✅ | large-input-detector.py |
| History indexing | ✅ | history-indexer.py |
| History search suggestions | ✅ | history-search.py |
| Skills library | Manual | /skill-name |
| RLM processing | Guided | (suggested by hook) |

**Everything is automatic except manual skill invocation and actual RLM processing (which is guided).**

---

## Need Help?

- Check `CLAUDE.md` for Claude Code-specific guidance
- Read `docs/rlm_paper_notes.md` for RLM theoretical background
- Original RLM paper: [arXiv:2512.24601](https://arxiv.org/abs/2512.24601)
