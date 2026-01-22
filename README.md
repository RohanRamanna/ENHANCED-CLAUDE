# Enhanced Claude

**Self-Improving AI with Infinite Context and Auto-Learning Skills - Powered by Automatic Hooks**

[![Status](https://img.shields.io/badge/status-fully_automatic-brightgreen)]()
[![Systems](https://img.shields.io/badge/systems-5-blue)]()
[![Hooks](https://img.shields.io/badge/hooks-9-purple)]()
[![Skills](https://img.shields.io/badge/skills-18-orange)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

## Overview

This repository transforms Claude Code into **Enhanced Claude** - a self-improving AI that:

1. **Never forgets** - RLM-based session persistence with intelligent segment recovery
2. **No limits** - Large inputs automatically detected, RLM workflow suggested
3. **Self-improves** - Skills automatically matched, tracked, and learning moments detected
4. **Searchable history** - Find past solutions without filling context

**Everything is automatic via 9 Claude Code hooks.**

## Quick Start

Install the systems you need:

```bash
# Clone the repo
git clone https://github.com/RohanRamanna/ENHANCED-CLAUDE.git
cd ENHANCED-CLAUDE/installers

# Install all systems (recommended)
./system-a-session-persistence/install.sh
./system-b-rlm/install.sh
./system-c-auto-skills/install.sh

# Or install just what you need
./system-a-session-persistence/install.sh  # Session persistence only
```

After installation:
1. Run `/hooks` in Claude Code to reload hooks
2. Read the `INSTRUCTIONS.md` in each installer for CLAUDE.md configuration

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
| **Skills Library** | Manual | 18 skills invoked via `/skill-name` |

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

## Skills Library (18 Skills)

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (3) | markdown-to-pdf, history, rlm |
| **Workflow** (1) | udcp |
| **Development** (1) | hook-development |
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
├── skills/                # Skills library (18 skills)
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

### Modular Installers

Install systems independently:

```
installers/
├── system-a-session-persistence/   # Session Persistence & Searchable History
│   ├── install.sh / install.bat    # Installers
│   ├── uninstall.sh / uninstall.bat
│   └── INSTRUCTIONS.md             # Claude instructions for setup
├── system-b-rlm/                   # RLM Detection & Processing
│   └── ...
└── system-c-auto-skills/           # Auto Skills & Skills Library
    └── ...
```

**macOS/Linux:**
```bash
cd /path/to/your/project
/path/to/installers/system-a-session-persistence/install.sh
```

**Windows:**
```cmd
cd \path\to\your\project
\path\to\installers\system-a-session-persistence\install.bat
```

### What Each System Installs

| System | Hooks | Skills | Template Files | Features |
|--------|-------|--------|----------------|----------|
| **A: Session Persistence** | 5 | 1 (history) | context.md, todos.md, insights.md | Context recovery, searchable history |
| **B: RLM Detection** | 2 | 1 (rlm) | - | Large input detection, RLM tools |
| **C: Auto Skills** | 5 | 18 | - | Skill matching, learning detection |

Each installer includes an `INSTRUCTIONS.md` with:
- Installation commands for macOS/Linux and Windows
- CLAUDE.md configuration (copy-paste ready)
- Verification steps

### Install All Systems

```bash
# macOS/Linux
./installers/system-a-session-persistence/install.sh
./installers/system-b-rlm/install.sh
./installers/system-c-auto-skills/install.sh
```

```cmd
:: Windows
installers\system-a-session-persistence\install.bat
installers\system-b-rlm\install.bat
installers\system-c-auto-skills\install.bat
```

### After Installation

1. Run `/hooks` in Claude Code to reload hooks
2. Read each system's `INSTRUCTIONS.md` for CLAUDE.md configuration
3. See `installers/TESTING.md` for verification steps

---

## Reference

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
