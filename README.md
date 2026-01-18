# Enhanced Claude

**Self-Improving AI with Infinite Context and Auto-Learning Skills - Powered by Automatic Hooks**

[![Status](https://img.shields.io/badge/status-fully_automatic-brightgreen)]()
[![Systems](https://img.shields.io/badge/systems-5-blue)]()
[![Hooks](https://img.shields.io/badge/hooks-8-purple)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

## Overview

This repository transforms Claude Code into **Enhanced Claude** - a self-improving AI that:

1. **Never forgets** - RLM-based session persistence with intelligent segment recovery
2. **No limits** - Large inputs automatically detected, RLM workflow suggested
3. **Self-improves** - Skills automatically matched, tracked, and learning moments detected
4. **Searchable history** - Find past solutions without filling context

**Everything is automatic via 8 Claude Code hooks.**

## Quick Start

```bash
# Download and run the installer
curl -O https://raw.githubusercontent.com/RohanRamanna/ENHANCED-CLAUDE/main/enhanced-claude-install.sh
chmod +x enhanced-claude-install.sh
./enhanced-claude-install.sh
```

The installer offers:
1. **Full install** - Global hooks/skills + project setup
2. **Global only** - Just hooks and skills (works for all projects)
3. **Project only** - Just persistence files and RLM tools
4. **Check status** - Verify installation

---

## The Five Systems (All Automatic)

| System | Hook | What It Does |
|--------|------|-------------|
| **Session Persistence** | `live-session-indexer.py` | Chunks live conversation into semantic segments |
| | `session-recovery.py` | RLM-based intelligent recovery with segment scoring |
| **RLM Detection** | `large-input-detector.py` | Auto-detects large inputs (>50K chars), suggests RLM workflow |
| **Auto-Skills** | `skill-matcher.py` | Auto-matches skills to every user message |
| | `skill-tracker.py` | Auto-tracks usage when SKILL.md files are read |
| | `detect-learning.py` | Auto-detects trial-and-error, offers skill creation |
| **Searchable History** | `history-indexer.py` | Indexes conversations on session end |
| | `history-search.py` | Suggests relevant past sessions |
| **Skills Library** | Manual | 17 skills invoked via `/skill-name` |

---

## The Hooks System

All automation is powered by **9 Python hooks** in `~/.claude/hooks/`:

```
~/.claude/hooks/
├── skill-matcher.py          # Every message: suggests matching skills
├── large-input-detector.py   # Every message: detects large inputs
├── history-search.py         # Every message: suggests relevant past work
├── learning-moment-pickup.py # Every message: picks up pending learning moments
├── skill-tracker.py          # After Read: tracks skill usage
├── detect-learning.py        # Before stop: detects learning moments, saves to file
├── history-indexer.py        # Before stop: indexes conversation history
├── live-session-indexer.py   # Before stop: chunks session into segments
└── session-recovery.py       # After compact: RLM-based intelligent recovery
```

### Hook Events

| Event | When | Hook | Action |
|-------|------|------|--------|
| `UserPromptSubmit` | Every message | `skill-matcher.py` | Match skills, suggest if score ≥10 |
| `UserPromptSubmit` | Every message | `large-input-detector.py` | Detect >50K chars, suggest RLM |
| `UserPromptSubmit` | Every message | `history-search.py` | Suggest relevant past sessions |
| `UserPromptSubmit` | Every message | `learning-moment-pickup.py` | Pick up pending learning moments |
| `PostToolUse` | After Read | `skill-tracker.py` | Track SKILL.md reads |
| `Stop` | Before finish | `detect-learning.py` | Detect 3+ failures, save for pickup |
| `Stop` | Before finish | `history-indexer.py` | Update searchable history index |
| `Stop` | Before finish | `live-session-indexer.py` | Chunk conversation into segments |
| `SessionStart` | After /compact | `session-recovery.py` | RLM-based intelligent context recovery |

---

## What Happens Automatically

| You Do This | Claude Gets This |
|-------------|------------------|
| Send any message | `[SKILL MATCH]` if relevant skill exists |
| Send any message | `[HISTORY MATCH]` if relevant past work exists |
| Paste >50K chars | `[LARGE INPUT DETECTED - RLM RECOMMENDED]` |
| Context compacts | Persistence files + relevant conversation segments (RLM-based) |
| Claude finishes responding | Live session chunked into semantic segments |
| Claude finishes responding | History index updated |
| Solve via trial-and-error | `[LEARNING MOMENT DETECTED]` with skill creation offer |
| Read a SKILL.md | Usage count and lastUsed updated |

---

## Skills Library (17 Skills)

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (3) | markdown-to-pdf, history, rlm |
| **Workflow** (1) | udcp |
| **Fallback** (1) | web-research |

**Usage**: Skills are auto-suggested, or invoke manually with `/skill-name`

---

## RLM: Infinite Context

Based on MIT CSAIL's paper [arXiv:2512.24601v1](https://arxiv.org/abs/2512.24601).

When `large-input-detector.py` suggests RLM:

```bash
# 1. Probe structure
python rlm_tools/probe.py input.txt

# 2. Chunk
python rlm_tools/chunk.py input.txt --output rlm_context/chunks/

# 3. Process with Task subagents (Claude does this)

# 4. Aggregate
python rlm_tools/aggregate.py rlm_context/results/
```

### Verified Results

| Test | Size | Result |
|------|------|--------|
| 8-Book Corpus | 4.86M chars (~1.2M tokens) | ✅ Verified via grep |
| FastAPI Codebase | 3.68M chars (~920K tokens) | ✅ Verified via grep |
| Session Recovery | 3 segments, ~2K tokens | ✅ Verified via /compact |

---

## Session Persistence (RLM-Based)

Three files that persist across context compaction, plus intelligent segment recovery:

| Component | Purpose |
|-----------|---------|
| `context.md` | Current goal, key decisions |
| `todos.md` | Task progress tracking |
| `insights.md` | Accumulated learnings |
| `segments.json` | Live session chunks with scoring |

**After compaction**:
1. `live-session-indexer.py` has already chunked conversation into semantic segments
2. `session-recovery.py` loads persistence files + scores and retrieves the most relevant segments
3. Claude sees actual conversation excerpts, not just summaries - **zero data loss**

---

## Repository Structure

```
PERSISTANT MEMORY/
├── CLAUDE.md              # Main guidance (hooks, systems, reference)
├── context.md             # Session persistence: current goal
├── todos.md               # Session persistence: task tracking
├── insights.md            # Session persistence: learnings
├── skills/                # Skills library (17 skills)
│   └── */SKILL.md
├── rlm_tools/             # RLM processing tools
│   ├── probe.py           # Analyze structure
│   ├── chunk.py           # Split files (semantic code chunking, progress tracking)
│   ├── aggregate.py       # Combine results
│   ├── parallel_process.py # Parallel processing coordination
│   └── sandbox.py         # Safe execution
├── rlm_context/           # RLM working directory
├── docs/
│   ├── HOW_TO_USE.md      # Complete guide
│   └── VERIFIED_TEST_RESULTS.md
└── requirements.txt

~/.claude/                 # User-level Claude Code config
├── settings.json          # Hook configuration (9 hooks)
├── hooks/                 # The 8 automation hooks + shared utilities
│   ├── hook_logger.py     # Shared logging utility
│   ├── skill-matcher.py
│   ├── large-input-detector.py
│   ├── history-search.py
│   ├── skill-tracker.py
│   ├── detect-learning.py
│   ├── history-indexer.py
│   ├── live-session-indexer.py
│   └── session-recovery.py
├── sessions/              # Live session segment indexes
│   └── <session-id>/segments.json
├── history/               # Searchable history index
│   └── index.json
└── skills/                # Skills library
```

---

## Installation

### One-Command Install (Recommended)

```bash
# Download and run the standalone installer
curl -O https://raw.githubusercontent.com/RohanRamanna/ENHANCED-CLAUDE/main/enhanced-claude-install.sh
chmod +x enhanced-claude-install.sh
./enhanced-claude-install.sh
```

### What the Installer Does

| Option | Installs |
|--------|----------|
| **Full install** | Global (hooks, skills, settings) + Project (persistence files, RLM tools) |
| **Global only** | 10 hooks, 17 skills, settings.json in `~/.claude/` |
| **Project only** | context.md, todos.md, insights.md, rlm_tools/ in current directory |

### CLI Flags

```bash
./enhanced-claude-install.sh --global    # Non-interactive global install
./enhanced-claude-install.sh --project   # Non-interactive project install
./enhanced-claude-install.sh --check     # Verify installation status
./enhanced-claude-install.sh --help      # Show help
```

After installation, reload hooks in Claude Code with `/hooks`.

---

## Inspiration & References

### Original Idea: Dylan Davis

The 3-file persistence system (`context.md`, `todos.md`, `insights.md`) was inspired by [Dylan Davis's video on Claude Code persistent memory](https://youtu.be/H-uwnpmziGA?si=VGerxvUFGksgMtBX).

We extended this idea by applying RLM (Recursive Language Model) principles to conversation history, enabling intelligent segment-based recovery after context compaction.

### RLM Research Paper

```bibtex
@article{zhang2025rlm,
  title={Recursive Language Models},
  author={Zhang, Alex L. and Kraska, Tim and Khattab, Omar},
  journal={arXiv preprint arXiv:2512.24601},
  year={2025}
}
```

## License

MIT
