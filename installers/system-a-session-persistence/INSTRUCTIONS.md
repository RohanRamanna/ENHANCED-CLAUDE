# System A: Session Persistence & Searchable History

## Installation

### macOS/Linux
```bash
cd /path/to/your/project
/path/to/installers/system-a-session-persistence/install.sh
```

### Windows
```cmd
cd \path\to\your\project
\path\to\installers\system-a-session-persistence\install.bat
```

### After Installation
Run `/hooks` in Claude Code to reload hooks.

---

## CLAUDE.md Configuration

**Add the following to the project's `CLAUDE.md` file:**

```markdown
## Session Persistence

This project uses automatic session persistence via hooks. After context compaction or session resume, Claude automatically recovers context.

### Persistence Files

| File | Purpose | When to Update |
|------|---------|----------------|
| `context.md` | Current goal, key decisions, important files | At task start, after major decisions |
| `todos.md` | Task progress tracking | When starting/completing tasks |
| `insights.md` | Accumulated learnings & patterns | When discovering something reusable |

### How It Works

1. **During conversation**: `live-session-indexer.py` chunks the session into semantic segments
2. **After compaction**: `session-recovery.py` loads persistence files + relevant segments
3. **On user prompt**: `history-search.py` suggests relevant past sessions

### Commands

| Command | Description |
|---------|-------------|
| `/history search <query>` | Search past conversations |
| `/history load <session_id>` | Load a past session's content |
| `/compact` | Compact context (triggers recovery on next message) |

### What Claude Should Do

- **Read** `context.md`, `todos.md`, `insights.md` at session start if they exist
- **Update** these files as work progresses:
  - `context.md` when goals change or key decisions are made
  - `todos.md` when starting or completing tasks
  - `insights.md` when discovering reusable patterns
- After compaction, acknowledge recovered context and continue where you left off
```

---

## What Gets Installed

### Hooks (in `~/.claude/hooks/`)
| Hook | Event | Purpose |
|------|-------|---------|
| `hook_logger.py` | Shared | Logging utility for all hooks |
| `session-recovery.py` | SessionStart | Loads persistence files + relevant segments after compaction |
| `live-session-indexer.py` | Stop | Chunks session into semantic segments |
| `history-indexer.py` | Stop | Indexes conversation for searchable history |
| `history-search.py` | UserPromptSubmit | Suggests relevant past sessions |

### Skills (in `~/.claude/skills/`)
- `history/` - Search and retrieve past conversations

### Template Files (in project directory)
- `context.md` - Current goal and key decisions
- `todos.md` - Task progress tracking
- `insights.md` - Accumulated learnings

---

## Verification

```bash
# Check hooks exist
ls -la ~/.claude/hooks/session-recovery.py
ls -la ~/.claude/hooks/live-session-indexer.py
ls -la ~/.claude/hooks/history-indexer.py
ls -la ~/.claude/hooks/history-search.py

# Check skill exists
ls -la ~/.claude/skills/history/SKILL.md

# Check template files exist
ls -la context.md todos.md insights.md

# Check settings.json has hooks
grep -A2 "session-recovery" ~/.claude/settings.json
```
