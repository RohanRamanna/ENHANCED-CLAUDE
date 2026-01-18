# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Claude should read this file when resuming work.

## Current Goal

Implemented **Enhanced Claude** - a self-improving AI with four integrated systems:

1. **Session Persistence** - 3 markdown files (this one, todos.md, insights.md) to maintain continuity across context compaction
2. **RLM for Large Documents** - Python tools to process documents exceeding context window
3. **Auto-Skills** - Self-improving skill system that automatically matches, tracks, learns, and improves
4. **Skills Library** - 15 reusable skills loaded on-demand

## Key Decisions Made

1. **No external API key required** - RLM uses Claude Code's native Task subagents
2. **Four complementary systems** - Each solves a different problem
3. **Auto-behavior protocol** - Skills are matched automatically on every request
4. **Self-improvement loop** - skill-creator, skill-updater, skill-improver work together
5. **Skill tracking** - useCount, successCount, failureCount for health monitoring

## Important Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main guidance with Enhanced Claude Protocol |
| `skills/skill-index/index.json` | Central skill index for matching |
| `skills/*/metadata.json` | Tracking data for each skill |
| `rlm_tools/*` | RLM processing tools |
| `docs/VERIFIED_TEST_RESULTS.md` | RLM verification proof |

## Enhanced Claude Protocol

On every user request:
1. **Skill Matching** - Score skills against request, load if score ≥10
2. **Skill Tracking** - Update useCount, successCount, failureCount
3. **Auto-Learning** - Offer to save trial-and-error solutions as new skills
4. **Auto-Improvement** - Update skills that fail or need workarounds

## Notes for Future Self

- The auto-skills system is documented in CLAUDE.md under "CRITICAL: Enhanced Claude Protocol"
- Skills are in `skills/` with index at `skills/skill-index/index.json`
- Each skill has SKILL.md (content) and metadata.json (tracking)
- RLM tested on 1.2M token corpus (8 books) and 920K token codebase (FastAPI)

---

**Last Updated**: 2026-01-18
