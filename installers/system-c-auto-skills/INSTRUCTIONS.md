# System C: Auto Skills & Skills Library

## Installation

### macOS/Linux
```bash
cd /path/to/your/project
/path/to/installers/system-c-auto-skills/install.sh
```

### Windows
```cmd
cd \path\to\your\project
\path\to\installers\system-c-auto-skills\install.bat
```

### After Installation
Run `/hooks` in Claude Code to reload hooks.

---

## CLAUDE.md Configuration

**Add the following to the project's `CLAUDE.md` file:**

```markdown
## Auto Skills System

This project uses automatic skill matching, tracking, and learning detection.

### How It Works

| Hook | Trigger | Action |
|------|---------|--------|
| `skill-matcher.py` | Every user message | Scores skills, suggests matches (score >= 10) |
| `skill-tracker.py` | After reading SKILL.md | Updates useCount, lastUsed in metadata |
| `detect-learning.py` | Before Claude finishes | Detects 3+ failures followed by success |
| `learning-moment-pickup.py` | On user message | Picks up pending learning moments from previous session |

### Skill Matching

When you see `[SKILL MATCH]`, a relevant skill was found:
```
[SKILL MATCH] Relevant skills detected:
  - hono-bun-sqlite-api (score:39): REST API with Hono, Bun and SQLite
    Load with: cat ~/.claude/skills/hono-bun-sqlite-api/SKILL.md
```

### Available Skills (18)

| Category | Skills |
|----------|--------|
| **Meta** | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** | llm-api-tool-use |
| **Utility** | markdown-to-pdf, history, rlm |
| **Workflow** | udcp |
| **Development** | hook-development |
| **Fallback** | web-research |

### Invoking Skills

- **Automatic**: Just describe what you need - matching skills are suggested
- **Manual**: Use `/skill-name` or `cat ~/.claude/skills/skill-name/SKILL.md`

### Learning Detection

When Claude solves a problem through trial-and-error (3+ failures then success):
```
[LEARNING MOMENT DETECTED]
You solved a problem through trial-and-error. Consider saving this as a reusable skill.
```

### What Claude Should Do

- When `[SKILL MATCH]` appears, consider loading the suggested skill
- When `[LEARNING MOMENT]` appears, offer to create a new skill with `/skill-creator`
- Use skills to avoid repeating past problem-solving
- Skills are global (in `~/.claude/skills/`) and work across all projects
```

---

## What Gets Installed

### Hooks (in `~/.claude/hooks/`)
| Hook | Event | Purpose |
|------|-------|---------|
| `hook_logger.py` | Shared | Logging utility for all hooks |
| `skill-matcher.py` | UserPromptSubmit | Scores and suggests matching skills |
| `skill-tracker.py` | PostToolUse (Read) | Tracks skill usage in metadata.json |
| `detect-learning.py` | Stop | Detects learning moments (failures → success) |
| `learning-moment-pickup.py` | UserPromptSubmit | Picks up pending learning moments |

### Skills (18 in `~/.claude/skills/`)

**Meta Skills:**
- `skill-index` - Index and discover skills
- `skill-matcher` - Smart skill discovery
- `skill-loader` - Lazy-load skills
- `skill-tracker` - Track skill usage
- `skill-creator` - Create new skills from learning moments
- `skill-updater` - Update existing skills
- `skill-improver` - Suggest skill improvements
- `skill-validator` - Validate skill health
- `skill-health` - Track skill effectiveness

**Setup Skills:**
- `deno2-http-kv-server` - Deno 2 HTTP server with KV
- `hono-bun-sqlite-api` - Hono + Bun + SQLite REST API

**API Skills:**
- `llm-api-tool-use` - Claude API tool use with Python

**Utility Skills:**
- `markdown-to-pdf` - Convert Markdown to PDF
- `history` - Search past conversations
- `rlm` - RLM workflow documentation

**Workflow Skills:**
- `udcp` - Update docs, commit, push

**Development Skills:**
- `hook-development` - Claude Code hooks development

**Fallback Skills:**
- `web-research` - Fallback research when stuck

---

## Verification

```bash
# Check hooks exist
ls -la ~/.claude/hooks/skill-matcher.py
ls -la ~/.claude/hooks/skill-tracker.py
ls -la ~/.claude/hooks/detect-learning.py
ls -la ~/.claude/hooks/learning-moment-pickup.py

# Count skills (should be 18)
ls -d ~/.claude/skills/*/ | wc -l

# Check skill index
cat ~/.claude/skills/skill-index/index.json | head -20

# Check settings.json has hooks
grep -A2 "skill-matcher" ~/.claude/settings.json
grep -A2 "skill-tracker" ~/.claude/settings.json
grep -A2 "detect-learning" ~/.claude/settings.json

# Test skill matcher
echo '{"prompt": "help me build a bun api"}' | python3 ~/.claude/hooks/skill-matcher.py
```
