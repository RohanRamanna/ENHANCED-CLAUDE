# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Automatically injected by `session-recovery.py` hook.

## Current Goal

**Enhanced Claude is COMPLETE** - a self-improving AI with four systems, all powered by automatic hooks:

| System | Hook | Status |
|--------|------|--------|
| Session Persistence | `session-recovery.py` | ✅ Automatic |
| RLM Detection | `large-input-detector.py` | ✅ Automatic |
| Auto-Skills | `skill-matcher.py`, `skill-tracker.py`, `detect-learning.py` | ✅ Automatic |
| Skills Library | Manual `/skill-name` | ✅ Working |

## Key Decisions Made

1. **Hooks for automation** - All 4 systems are now automatic via Claude Code hooks
2. **5 Python hooks** in `~/.claude/hooks/`:
   - `skill-matcher.py` - Matches skills on every message
   - `large-input-detector.py` - Detects large inputs, suggests RLM
   - `skill-tracker.py` - Tracks SKILL.md reads
   - `detect-learning.py` - Detects trial-and-error moments
   - `session-recovery.py` - Injects persistence files after compaction
3. **Conservative learning detection** - Only triggers on 3+ failures followed by success
4. **Global skills** - Skills in `~/.claude/skills/` (not project-specific)

## Important Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Hook configuration |
| `~/.claude/hooks/*.py` | The 5 automation hooks |
| `~/.claude/skills/skill-index/index.json` | Skill index for matching |
| `CLAUDE.md` | Main guidance with hooks documentation |
| `docs/HOW_TO_USE.md` | Complete usage guide |

## How Automation Works

```
Every message:
  → skill-matcher.py scores skills, suggests matches
  → large-input-detector.py checks for large inputs

After reading SKILL.md:
  → skill-tracker.py updates useCount, lastUsed

Before Claude finishes:
  → detect-learning.py checks for trial-and-error

After /compact:
  → session-recovery.py injects this file + todos.md + insights.md
```

## Notes for Future Self

- All automation is in `~/.claude/hooks/` (user-level, works across projects)
- Hook configuration is in `~/.claude/settings.json`
- Hooks can be reloaded with `/hooks` command
- Test hooks manually: `echo '{"prompt": "test"}' | python3 ~/.claude/hooks/skill-matcher.py`

---

**Last Updated**: 2026-01-18
