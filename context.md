# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Claude should read this file when resuming work.

## Current Goal

Implemented a **dual persistent memory system** for Claude Code:
1. **Session Persistence** - 3 markdown files (this one, todos.md, insights.md) to maintain continuity across context compaction
2. **RLM for Large Documents** - Python tools to process documents exceeding context window

## Key Decisions Made

1. **No external API key required** - RLM uses Claude Code's native Task subagents instead of Anthropic API calls
2. **Two complementary systems** - Session persistence solves memory loss; RLM solves oversized inputs (different problems)
3. **Chunk size**: 200K characters per chunk with 500 char overlap
4. **Parallel processing**: 3-6 Task subagents at a time for efficiency
5. **Verification approach**: Use grep on original corpus to verify RLM findings at exact line numbers

## Important Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main guidance - read first when resuming |
| `rlm_tools/probe.py` | Analyze document structure |
| `rlm_tools/chunk.py` | Split large documents |
| `rlm_tools/aggregate.py` | Combine subagent results |
| `docs/VERIFIED_TEST_RESULTS.md` | Proof that RLM works on 1.2M token corpus |

## Notes for Future Self

- The RLM system was tested on an 8-book literary corpus (4.86M chars, ~1.2M tokens)
- This corpus is **6x larger** than the context window - proving RLM handles impossible inputs
- Deaths were verified by grep at exact line numbers (Sydney Carton line 82107, etc.)
- Session persistence files are templates - update them as you work on new tasks

---

**Last Updated**: 2026-01-18
