# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Automatically injected by `session-recovery.py` hook.

## Current Goal

**Enhanced Claude** - A self-improving AI with five integrated systems:

| System | Hook | Status |
|--------|------|--------|
| Session Persistence | `session-recovery.py`, `live-session-indexer.py` | Active |
| RLM Detection | `large-input-detector.py` | Active |
| Auto-Skills | `skill-matcher.py`, `skill-tracker.py`, `detect-learning.py` | Active |
| Searchable History | `history-indexer.py`, `history-search.py` | Active |
| Skills Library | Manual `/skill-name` | Active |

## Key Decisions Made

1. **Hooks for automation** - All 5 systems are automatic via Claude Code hooks
2. **9 Python hooks** in `~/.claude/hooks/`:
   - `skill-matcher.py` - Matches skills on every message
   - `large-input-detector.py` - Detects large inputs, suggests RLM
   - `history-search.py` - Suggests relevant past sessions
   - `skill-tracker.py` - Tracks SKILL.md reads
   - `detect-learning.py` - Detects trial-and-error moments
   - `history-indexer.py` - Indexes conversation history
   - `live-session-indexer.py` - Chunks live session into segments
   - `session-recovery.py` - RLM-based intelligent recovery with segments
   - `learning-moment-pickup.py` - Picks up pending learning moments
3. **Conservative learning detection** - Only triggers on 3+ failures followed by success
4. **Global skills** - Skills in `~/.claude/skills/` (not project-specific), now **18 skills** (added hook-development)
5. **History indexing** - Zero data duplication, index points to existing JSONL files
6. **Hook logging** - All hooks use shared `hook_logger.py` for debugging
7. **Semantic code chunking** - `--strategy code` for 6 languages (Python, JS, TS, Go, Rust, Java)
8. **Parallel processing** - `parallel_process.py` for up to 10x RLM speedup
9. **Hook output bug workaround** - UserPromptSubmit hooks must output NOTHING when nothing to report (known Claude Code bug)

## Important Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Hook configuration |
| `~/.claude/hooks/*.py` | The 9 automation hooks (+ hook_logger.py shared utility) |
| `~/.claude/history/index.json` | Searchable history index |
| `~/.claude/sessions/<id>/segments.json` | Live session segment index |
| `CLAUDE.md` | Main guidance with hooks documentation |
| `docs/HOW_TO_USE.md` | Complete usage guide |

## Notes for Future Self

- All automation is in `~/.claude/hooks/` (user-level, works across projects)
- Hook configuration is in `~/.claude/settings.json` - **use absolute paths, not `~`**
- Hooks can be reloaded with `/hooks` command
- History index at `~/.claude/history/index.json`
- Search history with `/history search <query>`
- Test hooks manually: `echo '{"prompt": "test"}' | python3 ~/.claude/hooks/skill-matcher.py`
- **Known bug**: UserPromptSubmit hooks with output show "hook error" - cosmetic only, context IS injected
- See `~/.claude/skills/hook-development/SKILL.md` for hook development guidance

---

**Last Updated**: 2026-01-19
