# Enhanced Claude

**Self-Improving AI with Infinite Context and Auto-Learning Skills - Powered by Automatic Hooks**

[![Status](https://img.shields.io/badge/status-fully_automatic-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

## Overview

This repository transforms Claude Code into **Enhanced Claude** - a self-improving AI that:

1. **Never forgets** - Session persistence automatically loaded after compaction
2. **No limits** - Large inputs automatically detected, RLM workflow suggested
3. **Self-improves** - Skills automatically matched, tracked, and learning moments detected

**Everything is automatic via Claude Code hooks.**

## Quick Start

```bash
# 1. Hooks are already in ~/.claude/hooks/
# 2. Just use Claude Code normally
# 3. All 4 systems work automatically
```

That's it. No manual setup needed.

---

## The Four Systems (All Automatic)

| System | Hook | What It Does |
|--------|------|-------------|
| **Session Persistence** | `session-recovery.py` | Auto-loads context.md, todos.md, insights.md after compaction |
| **RLM Detection** | `large-input-detector.py` | Auto-detects large inputs (>50K chars), suggests RLM workflow |
| **Auto-Skills** | `skill-matcher.py` | Auto-matches skills to every user message |
| | `skill-tracker.py` | Auto-tracks usage when SKILL.md files are read |
| | `detect-learning.py` | Auto-detects trial-and-error, offers skill creation |
| **Skills Library** | Manual | 15 skills invoked via `/skill-name` |

---

## The Hooks System

All automation is powered by **5 Python hooks** in `~/.claude/hooks/`:

```
~/.claude/hooks/
├── skill-matcher.py        # Every message: suggests matching skills
├── large-input-detector.py # Every message: detects large inputs
├── skill-tracker.py        # After Read: tracks skill usage
├── detect-learning.py      # Before stop: detects learning moments
└── session-recovery.py     # After compact: loads persistence files
```

### Hook Events

| Event | When | Hook | Action |
|-------|------|------|--------|
| `UserPromptSubmit` | Every message | `skill-matcher.py` | Match skills, suggest if score ≥10 |
| `UserPromptSubmit` | Every message | `large-input-detector.py` | Detect >50K chars, suggest RLM |
| `PostToolUse` | After Read | `skill-tracker.py` | Track SKILL.md reads |
| `Stop` | Before finish | `detect-learning.py` | Detect 3+ failures, offer skill creation |
| `SessionStart` | After /compact | `session-recovery.py` | Inject persistence files |

---

## What Happens Automatically

| You Do This | Claude Gets This |
|-------------|------------------|
| Send any message | `[SKILL MATCH]` if relevant skill exists |
| Paste >50K chars | `[LARGE INPUT DETECTED - RLM RECOMMENDED]` |
| Context compacts | Full contents of persistence files injected |
| Solve via trial-and-error | `[LEARNING MOMENT DETECTED]` with skill creation offer |
| Read a SKILL.md | Usage count and lastUsed updated |

---

## Skills Library (15 Skills)

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (1) | markdown-to-pdf |
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

---

## Session Persistence

Three files that persist across context compaction:

| File | Purpose |
|------|---------|
| `context.md` | Current goal, key decisions |
| `todos.md` | Task progress tracking |
| `insights.md` | Accumulated learnings |

**After compaction**: `session-recovery.py` automatically injects all three files into Claude's context.

---

## Repository Structure

```
PERSISTANT MEMORY/
├── CLAUDE.md              # Main guidance (hooks, systems, reference)
├── context.md             # Session persistence: current goal
├── todos.md               # Session persistence: task tracking
├── insights.md            # Session persistence: learnings
├── skills/                # Skills library (15 skills)
│   └── */SKILL.md
├── rlm_tools/             # RLM processing tools
│   ├── probe.py           # Analyze structure
│   ├── chunk.py           # Split files
│   ├── aggregate.py       # Combine results
│   └── sandbox.py         # Safe execution
├── rlm_context/           # RLM working directory
├── docs/
│   ├── HOW_TO_USE.md      # Complete guide
│   └── VERIFIED_TEST_RESULTS.md
└── requirements.txt
```

---

## Installation (If Starting Fresh)

```bash
# 1. Create hooks directory
mkdir -p ~/.claude/hooks

# 2. Copy hook scripts
cp hooks/*.py ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.py

# 3. Copy settings.json (or merge with existing)
cp .claude/settings.json ~/.claude/settings.json

# 4. Reload hooks
# In Claude Code, run: /hooks
```

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
