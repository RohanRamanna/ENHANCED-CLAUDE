# Enhanced Claude - Modular Installers

Install Enhanced Claude systems independently for testing and evaluation.

## Available Systems

| System | Directory | Purpose |
|--------|-----------|---------|
| **A: Session Persistence** | `system-a-session-persistence/` | Context recovery after compaction + searchable history |
| **B: RLM Detection** | `system-b-rlm/` | Large document detection + RLM processing tools |
| **C: Auto Skills** | `system-c-auto-skills/` | Skill matching, learning detection, 18-skill library |

## Quick Start

### macOS/Linux

```bash
# Install a system
./system-a-session-persistence/install.sh

# Uninstall (preserves data)
./system-a-session-persistence/uninstall.sh
```

### Windows

```cmd
:: Install a system
system-a-session-persistence\install.bat

:: Uninstall
system-a-session-persistence\uninstall.bat
```

## What Each System Installs

### System A: Session Persistence & Searchable History

**Hooks:**
- `hook_logger.py` - Shared logging utility
- `session-recovery.py` - RLM-based context recovery (SessionStart)
- `live-session-indexer.py` - Chunks session into segments (Stop)
- `history-indexer.py` - Indexes conversation history (Stop)
- `history-search.py` - Suggests relevant past sessions (UserPromptSubmit)

**Skills:**
- `history` - Search and retrieve past conversations

**Template Files (created in project directory):**
- `context.md` - Current goal and key decisions (includes instructions for Claude to update CLAUDE.md)
- `todos.md` - Task progress tracking
- `insights.md` - Accumulated learnings and patterns

**Features:**
- Automatic context recovery after compaction
- Searchable history index
- Zero data duplication
- Ready-to-use persistence templates

### System B: RLM Detection & Processing

**Hooks:**
- `hook_logger.py` - Shared logging utility
- `large-input-detector.py` - Detects large inputs (UserPromptSubmit)

**Skills:**
- `rlm` - RLM workflow documentation

**Tools (in project directory):**
- `rlm_tools/probe.py` - Analyze input structure
- `rlm_tools/chunk.py` - Split large files (with semantic code chunking)
- `rlm_tools/aggregate.py` - Combine chunk results
- `rlm_tools/parallel_process.py` - Coordinate parallel processing
- `rlm_tools/sandbox.py` - Safe Python execution

### System C: Auto Skills & Skills Library

**Hooks:**
- `hook_logger.py` - Shared logging utility
- `skill-matcher.py` - Suggests matching skills (UserPromptSubmit)
- `skill-tracker.py` - Tracks skill usage (PostToolUse)
- `detect-learning.py` - Detects learning moments (Stop)
- `learning-moment-pickup.py` - Picks up pending learning moments (UserPromptSubmit)

**Skills (18):**
- Meta: skill-index, skill-creator, skill-updater, skill-loader, skill-health, skill-improver, skill-tracker, skill-validator, skill-matcher
- Setup: deno2-http-kv-server, hono-bun-sqlite-api
- API: llm-api-tool-use
- Utility: markdown-to-pdf, history, rlm
- Workflow: udcp
- Development: hook-development
- Fallback: web-research

## Installer Features

- **Auto-merge settings.json** - Existing hooks are preserved
- **Timestamped backups** - Created in `~/.claude/backups/`
- **Shared components** - `hook_logger.py` is shared across systems
- **Safe uninstall** - Only removes hooks/skills, preserves:
  - Session data (`~/.claude/sessions/`)
  - History index (`~/.claude/history/`)
  - RLM tools (`rlm_tools/`)
  - Project files (`context.md`, `todos.md`, `insights.md`)

## Post-Installation

After installing any system:

```bash
# Reload hooks in Claude Code
/hooks
```

## Installing All Systems

For full functionality, install all three systems:

```bash
# macOS/Linux
./system-a-session-persistence/install.sh
./system-b-rlm/install.sh
./system-c-auto-skills/install.sh

# Or use the standalone installer for everything at once
../enhanced-claude-install.sh
```

## Requirements

- Python 3.8+
- Claude Code CLI

## Troubleshooting

### Hooks not running?

```bash
# Check hook permissions
chmod +x ~/.claude/hooks/*.py

# Reload hooks
# In Claude Code, type: /hooks
```

### Check hook logs

```bash
tail -20 ~/.claude/hooks/logs/skill-matcher.log
```
