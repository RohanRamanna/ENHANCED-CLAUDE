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
2. **8 Python hooks** in `~/.claude/hooks/`:
   - `skill-matcher.py` - Matches skills on every message
   - `large-input-detector.py` - Detects large inputs, suggests RLM
   - `history-search.py` - Suggests relevant past sessions
   - `skill-tracker.py` - Tracks SKILL.md reads
   - `detect-learning.py` - Detects trial-and-error moments
   - `history-indexer.py` - Indexes conversation history
   - `live-session-indexer.py` - Chunks live session into segments
   - `session-recovery.py` - RLM-based intelligent recovery with segments
3. **Auto-detect project directory** - Hooks use `os.getcwd()` instead of hardcoded paths
4. **Global skills** - Skills in `~/.claude/skills/` (not project-specific), now 17 skills
5. **Zero data duplication** - History index points to existing JSONL files
6. **Hook logging** - All 8 hooks use shared `hook_logger.py` for debugging
7. **Semantic code chunking** - `--strategy code` for 6 languages (Python, JS, TS, Go, Rust, Java)
8. **Parallel processing** - `parallel_process.py` for up to 10x RLM speedup

## Important Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Hook configuration |
| `~/.claude/hooks/*.py` | The 8 automation hooks (+ hook_logger.py shared utility) |
| `~/.claude/history/index.json` | Searchable history index |
| `~/.claude/sessions/<id>/segments.json` | Live session segment index |
| `CLAUDE.md` | Main guidance with hooks documentation |
| `docs/HOW_TO_USE.md` | Complete usage guide |

## Notes for Future Self

- All automation is in `~/.claude/hooks/` (user-level, works across projects)
- Test hooks manually: `echo '{}' | python3 ~/.claude/hooks/skill-matcher.py`
- Reload hooks with `/hooks` command

---

**Last Updated**: 2026-01-19
