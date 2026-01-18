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

1. **Hooks for automation** - All systems are automatic via Claude Code hooks
2. **8 Python hooks** in `~/.claude/hooks/`
3. **Auto-detect project directory** - Hooks use `os.getcwd()` instead of hardcoded paths
4. **Global skills** - Skills in `~/.claude/skills/` work across all projects
5. **Zero data duplication** - History index points to JSONL files, doesn't copy content

## Important Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Hook configuration |
| `~/.claude/hooks/*.py` | The 8 automation hooks |
| `~/.claude/history/index.json` | Searchable history index |
| `~/.claude/sessions/<id>/segments.json` | Live session segment index |
| `CLAUDE.md` | Main guidance with hooks documentation |
| `docs/HOW_TO_USE.md` | Complete usage guide |

## Notes for Future Self

- All automation is in `~/.claude/hooks/` (user-level, works across projects)
- Test hooks manually: `echo '{}' | python3 ~/.claude/hooks/skill-matcher.py`
- Reload hooks with `/hooks` command

---

**Last Updated**: 2026-01-18
