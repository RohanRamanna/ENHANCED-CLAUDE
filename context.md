# Context

> **Purpose**: This file preserves the current goal/context across session compaction. Automatically injected by `session-recovery.py` hook.

## Current Goal

**Enhanced Claude is COMPLETE** - a self-improving AI with five systems, all powered by automatic hooks:

| System | Hook | Status |
|--------|------|--------|
| Session Persistence | `session-recovery.py`, `live-session-indexer.py` | ✅ RLM-based |
| RLM Detection | `large-input-detector.py` | ✅ Automatic |
| Auto-Skills | `skill-matcher.py`, `skill-tracker.py`, `detect-learning.py` | ✅ Automatic |
| Searchable History | `history-indexer.py`, `history-search.py` | ✅ Automatic |
| Skills Library | Manual `/skill-name` | ✅ Working |

## Latest Work: Modular System Installers (Phase 16)

Created 3 separate installer systems for independent testing:

| System | Directory | Contents |
|--------|-----------|----------|
| **A: Session Persistence** | `installers/system-a-session-persistence/` | 5 hooks, 1 skill (history) |
| **B: RLM Detection** | `installers/system-b-rlm/` | 2 hooks, 1 skill (rlm), RLM tools |
| **C: Auto Skills** | `installers/system-c-auto-skills/` | 5 hooks, 18 skills |

Each system has:
- `install.sh` / `install.bat` - macOS/Linux and Windows installers
- `uninstall.sh` / `uninstall.bat` - Uninstallers that preserve data

## Key Decisions Made

1. **Hooks for automation** - All 5 systems are now automatic via Claude Code hooks
2. **8 Python hooks** in `~/.claude/hooks/`:
   - `skill-matcher.py` - Matches skills on every message
   - `large-input-detector.py` - Detects large inputs, suggests RLM
   - `history-search.py` - Suggests relevant past sessions
   - `skill-tracker.py` - Tracks SKILL.md reads
   - `detect-learning.py` - Detects trial-and-error moments
   - `history-indexer.py` - Indexes conversation history
   - `live-session-indexer.py` - Chunks live session into segments (NEW)
   - `session-recovery.py` - RLM-based intelligent recovery with segments (ENHANCED)
3. **Conservative learning detection** - Only triggers on 3+ failures followed by success
4. **Global skills** - Skills in `~/.claude/skills/` (not project-specific), now **18 skills** (added hook-development)
5. **History indexing** - Zero data duplication, index points to existing JSONL files
6. **Hook logging** - All 9 hooks use shared `hook_logger.py` for debugging
7. **Semantic code chunking** - `--strategy code` for 6 languages (Python, JS, TS, Go, Rust, Java)
8. **Parallel processing** - `parallel_process.py` for up to 10x RLM speedup
9. **Hook output bug workaround** - UserPromptSubmit hooks must output NOTHING when nothing to report (known Claude Code bug)
10. **Modular installers** - Each system can be installed independently for testing (Phase 16)
11. **Self-contained scripts** - All code embedded in installers (no GitHub downloads needed)
12. **Auto-merge settings.json** - Installers merge with existing hooks, don't overwrite
13. **Shared hook_logger.py** - Not removed by any uninstaller (shared dependency)

## Important Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Hook configuration |
| `~/.claude/hooks/*.py` | The 8 automation hooks (+ hook_logger.py shared utility) |
| `~/.claude/history/index.json` | Searchable history index |
| `~/.claude/sessions/<id>/segments.json` | Live session segment index |
| `~/.claude/skills/skill-index/index.json` | Skill index for matching |
| `installers/README.md` | Installer documentation |
| `installers/system-*/install.sh` | macOS/Linux installers |
| `installers/system-*/install.bat` | Windows installers |
| `CLAUDE.md` | Main guidance with hooks documentation |
| `docs/HOW_TO_USE.md` | Complete usage guide |

## How Automation Works

```
Every message:
  → skill-matcher.py scores skills, suggests matches
  → large-input-detector.py checks for large inputs
  → history-search.py suggests relevant past sessions

After reading SKILL.md:
  → skill-tracker.py updates useCount, lastUsed

Before Claude finishes:
  → detect-learning.py checks for trial-and-error
  → history-indexer.py updates the history index

After /compact:
  → session-recovery.py injects this file + todos.md + insights.md
```

## Notes for Future Self

- All automation is in `~/.claude/hooks/` (user-level, works across projects)
- Hook configuration is in `~/.claude/settings.json` - **use absolute paths, not `~`**
- Hooks can be reloaded with `/hooks` command
- History index at `~/.claude/history/index.json`
- Search history with `/history search <query>`
- Test hooks manually: `echo '{"prompt": "test"}' | python3 ~/.claude/hooks/skill-matcher.py`
- **Known bug**: UserPromptSubmit hooks with output show "hook error" - cosmetic only, context IS injected
- See `~/.claude/skills/hook-development/SKILL.md` for hook development guidance
- Install systems independently: `./installers/system-a-session-persistence/install.sh`
- Uninstall preserves data (sessions, history, rlm_tools)
- Run `/hooks` after installation to reload hooks

## Latest Work: Template Files & Testing Guide (Phase 16 cont.)

Added to System A installer:
- **Template file creation** - `context.md`, `todos.md`, `insights.md` created automatically in project directory
- **Self-bootstrapping** - `context.md` template includes instructions for Claude to update project's `CLAUDE.md` with session persistence guidance
- **Testing documentation** - Created `installers/TESTING.md` with manual verification steps for all 3 systems

### What's Fully Automatic Per System

| System | Automatic | Manual |
|--------|-----------|--------|
| **A: Session Persistence** | Everything (hooks + templates) | Nothing |
| **B: RLM Detection** | Detection of large inputs | RLM processing workflow |
| **C: Auto Skills** | Skill matching suggestions | Loading suggested skills |

## Git Status (Phase 16)

- Commit: `4dde5d9` - Add template files to System A installer and testing guide
- Pushed to: `origin/main` (private repo)
- Pushed to: `public/main` (public repo via public-release branch)

---

**Last Updated**: 2026-01-21
