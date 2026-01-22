# Insights

> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. Automatically injected by `session-recovery.py` hook.

## Key Learnings

### Modular Installers Are Better for Testing (Phase 16)

Instead of one monolithic installer, create separate installers for each system:

| Approach | Pros | Cons |
|----------|------|------|
| Monolithic | One command installs everything | Hard to test individual systems, hard to debug |
| Modular | Test each system independently, easy uninstall | User needs to run multiple commands |

**Decision**: Modular installers for now, can add "install all" option later after testing.

### Embedding Code in Installers (Phase 16)

For self-contained installers that don't require network access:

**Bash (heredoc)**:
```bash
cat > "$HOOKS_DIR/hook.py" << 'HOOK_EOF'
# Full Python code here
HOOK_EOF
```

**Windows Batch (PowerShell)**:
```batch
powershell -ExecutionPolicy Bypass -Command ^"^
$code = @' ^
# PowerShell code here ^
'@ ^
$code | Out-File -FilePath 'file.py' -Encoding utf8 ^
^"
```

### Settings.json Auto-Merge Pattern (Phase 16)

Don't overwrite existing settings - merge new hooks with existing:

```python
settings = load_existing_settings()
if "hooks" not in settings:
    settings["hooks"] = {}

# Add new hooks only if not already present
for event, event_hooks in new_hooks.items():
    if event not in settings["hooks"]:
        settings["hooks"][event] = []
    # Check if hook already exists before adding
    for hook in event_hooks:
        if not hook_exists(settings["hooks"][event], hook):
            settings["hooks"][event].append(hook)
```

### Claude Code Hooks Are Powerful

Hooks enable truly automatic behavior - not just documentation Claude should follow, but actual code that runs on events.

| Hook Event | When | Use For |
|------------|------|---------|
| `UserPromptSubmit` | Every message | Context injection, validation |
| `PostToolUse` | After any tool | Tracking, logging |
| `Stop` | Before Claude finishes | Analysis, blocking |
| `SessionStart` | On start/resume/compact | State recovery |

**Key insight**: Hooks output JSON with `additionalContext` to inject content into Claude's context.

### Hook Input/Output Pattern

All hooks receive JSON via stdin:
```python
import json
import sys

hook_input = json.load(sys.stdin)  # Contains event-specific data
# ... process ...
output = {"hookSpecificOutput": {"additionalContext": "..."}}
print(json.dumps(output))
sys.exit(0)
```

### Stop Hook Schema Difference

**Important**: Stop hooks use a DIFFERENT output schema than other hooks:
- **UserPromptSubmit**: `hookSpecificOutput.additionalContext`
- **Stop**: `systemMessage` (NOT `hookSpecificOutput`)

```python
# Wrong for Stop hooks:
output = {"hookSpecificOutput": {"additionalContext": "..."}}

# Correct for Stop hooks:
output = {"continue": True, "systemMessage": "..."}
```

### Hook Logging Pattern

All hooks now use a shared logging utility (`hook_logger.py`) for consistent debugging:
```python
from hook_logger import HookLogger
logger = HookLogger("hook-name")
logger.info("Hook started")
logger.debug("Processing details")
logger.error("Something went wrong", exc_info=True)
```

Logs are stored in `~/.claude/hooks/logs/{hook-name}.log` with automatic 1MB rotation.

### User vs Project Settings

- **Project settings** (`.claude/settings.json`): Per-project hooks
- **User settings** (`~/.claude/settings.json`): Global hooks, higher priority

For global automation (skills, session recovery), use user settings.

### RLM Architecture Mapping

| Paper Component | Claude Code Equivalent |
|-----------------|----------------------|
| Root LM | Main conversation |
| Sub-LM (llm_query) | Task tool with subagents |
| REPL Environment | Bash tool + filesystem |
| context variable | Files on disk |
| FINAL() output | Return to main conversation |

**Key insight**: No external API key needed - Claude Code IS the RLM.

### When to Use Each System

| Scenario | System | Why |
|----------|--------|-----|
| Context compacted | Session Persistence | Auto-loaded via hook |
| Large input (>50K chars) | RLM | Auto-detected via hook |
| Need a specific skill | Auto-Skills | Auto-matched via hook |
| Trial-and-error solved | Learning Detection | Auto-detected via hook |
| Ask about past work | Searchable History | Auto-suggested via hook |

### Searchable History: Zero Data Duplication

The key insight: **index WHERE data is, not WHAT it contains**.

- Claude Code already stores full conversation history in JSONL files
- We just build a lightweight index with pointers (session ID, line ranges, topics)
- On search, only load the relevant segment, not the whole history
- No summarization = no data loss

### RLM-based Live Session Persistence

Apply RLM principles to the CURRENT session for zero data loss after compaction:

1. **Segment Detection** - Natural boundaries:
   - Task completion (TodoWrite with completed items)
   - Topic change (new user question)
   - Time gaps (> 5 minutes)
   - Max segment size (100 lines)

2. **Segment Scoring** - Select most relevant after compaction:
   - Recency: 50 points max, -5 per hour
   - Task match: +10 per topic matching pending todos
   - Active work: +15 for segments with Edit/Write
   - Decisions: +10 if segment contains key decisions

3. **Content Extraction** - Load actual JSONL content, not just metadata:
   - Extract user messages, assistant responses
   - Highlight file modifications
   - Show completed/in-progress tasks
   - Stay within ~2000 token budget

## Patterns Identified

### Conservative Learning Detection

Only trigger skill creation offers when:
- 3+ tool failures followed by success
- OR 5+ "let me try" phrases in conversation

This prevents false positives and annoying prompts.

### Skill Matching Algorithm (Implemented)

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 per tag |
| Skill name word match | +3 per word |
| Summary keyword match | +2 per word |
| Tag word match | +2 per tag |
| Recent use (< 7 days) | +1 |

**Threshold**: ≥10 = suggest skill

### Effective RLM Query Design

- Be specific: "Find all character deaths" > "Analyze the books"
- Request structured output: "List with book name, character, cause"
- Include verification hooks: "Include line numbers or quotes"

### Parallel Subagent Batching

- 4 chunks per subagent works well
- 3-6 parallel subagents is efficient
- More subagents = faster but higher cost
- Use `rlm_tools/parallel_process.py` to generate batch configurations
- Spawn ALL batches in a single response for true parallelism (up to 10x speedup)

### Installer Structure Pattern (Phase 16)

```
installers/
├── README.md                 # Overview documentation
├── system-a-{name}/
│   ├── install.sh           # macOS/Linux (bash + heredocs)
│   ├── install.bat          # Windows (batch + PowerShell)
│   ├── uninstall.sh
│   └── uninstall.bat
├── system-b-{name}/
│   └── ...
└── system-c-{name}/
    └── ...
```

Each installer:
1. Creates backup directory with timestamp
2. Creates required directories
3. Writes hook files
4. Writes skill files (if applicable)
5. Merges settings.json
6. Reports what was installed

## Gotchas & Pitfalls

### Hook Debugging

- Test hooks manually: `echo '{"prompt": "test"}' | python3 hook.py`
- Hooks must exit with code 0 for success
- JSON output must be valid
- Hooks have 60-second timeout

### Session Recovery Hook Path

The `session-recovery.py` hook now uses dynamic project detection:
- Uses `CLAUDE_PROJECT_DIR` environment variable if set
- Falls back to current working directory
- No more hardcoded paths needed

### Skills Location

Skills are in `~/.claude/skills/` (global), not project-specific. This means:
- Skills work across all projects
- skill-matcher.py uses this path
- skill-tracker.py updates metadata here

### Chunk Overlap Matters

- Default 500 chars might miss context at boundaries
- For technical/legal docs, consider 1000-2000 char overlap

### Semantic Code Chunking Works Well

The `--strategy code` option intelligently splits code at function/class boundaries:
- Auto-detects language from code patterns (Python colons, TS types, etc.)
- Keeps related code together (class with methods in same chunk)
- Entities metadata helps understand what each chunk contains

**Language detection patterns**:
| Language | Key Indicators |
|----------|---------------|
| Python | `def `, `class `, trailing `:` |
| TypeScript | `interface`, `type =`, `: string/number` |
| JavaScript | `function`, `const =`, `=>` |
| Go | `func`, `package`, `type struct` |
| Rust | `fn`, `impl`, `struct`, `enum` |

### UserPromptSubmit Hook Output Bug (Critical)

**Bug**: Claude Code shows "UserPromptSubmit hook error" for ANY stdout, even valid JSON ([Issue #13912](https://github.com/anthropics/claude-code/issues/13912)).

**Discovery process**:
1. All hooks were outputting `{}` when nothing to report
2. This caused "hook error" on every prompt
3. Changing to `{"hookSpecificOutput": {}}` made it worse (all 4 hooks failed)
4. Solution: **Output NOTHING** when nothing to report

**Working pattern**:
```python
# When nothing to report - NO OUTPUT
if no_matches:
    sys.exit(0)  # Just exit

# When you have context - output JSON
if matches:
    print(json.dumps({"hookSpecificOutput": {"additionalContext": "..."}}, flush=True))
    sys.exit(0)
```

**Note**: Hooks that DO output context will show an error but **the context IS injected correctly** - it's a cosmetic display bug.

### Absolute Paths in Hook Config

Using `~` in hook commands may cause issues. Use absolute paths:
```json
// May not work
"command": "python3 ~/.claude/hooks/my-hook.py"

// Works reliably
"command": "python3 /Users/username/.claude/hooks/my-hook.py"
```

### Hook Development Skill Created

Created `~/.claude/skills/hook-development/SKILL.md` documenting:
- All hook events and their input/output schemas
- Known bugs and workarounds
- Python template for new hooks
- Debugging techniques

## The Complete Automation Stack

```
~/.claude/
├── settings.json           # Hook configuration (8 hooks)
├── hooks/logs/             # Hook debug logs (auto-rotated)
├── hooks/
│   ├── hook_logger.py      # Shared logging utility
│   ├── skill-matcher.py    # UserPromptSubmit: match skills
│   ├── large-input-detector.py  # UserPromptSubmit: detect large inputs
│   ├── history-search.py   # UserPromptSubmit: suggest past sessions
│   ├── skill-tracker.py    # PostToolUse: track usage
│   ├── detect-learning.py  # Stop: detect learning moments
│   ├── history-indexer.py  # Stop: index conversation history
│   ├── live-session-indexer.py  # Stop: chunk live session into segments
│   └── session-recovery.py # SessionStart: RLM-based intelligent recovery
├── sessions/
│   └── <session-id>/
│       └── segments.json   # Live session segment index
├── history/
│   └── index.json          # Searchable history index
└── skills/
    ├── skill-index/
    │   └── index.json      # Central skill index (18 skills)
    └── */
        ├── SKILL.md        # Skill content
        └── metadata.json   # Usage tracking
```

## Open Questions (Resolved)

- ~~How does RLM perform on code?~~ → **Works excellently** (FastAPI test)
- ~~How to make skills self-improving?~~ → **Auto-skills hooks** (matcher, tracker, learning detection)
- ~~Can we detect when RLM is needed automatically?~~ → **Yes, via large-input-detector.py hook**
- ~~How to make session persistence automatic?~~ → **Yes, via session-recovery.py hook**
- ~~How to search past conversations without loading everything?~~ → **Searchable history with index pointers**

### Self-Bootstrapping Installers (Phase 17)

For truly automatic systems, installers should create template files that instruct the AI to complete setup:

**Pattern**:
1. Installer creates template files (e.g., `context.md`, `todos.md`, `insights.md`)
2. Template includes instructions for AI to update project configuration (e.g., CLAUDE.md)
3. On first use, AI reads template → updates config → system becomes fully automatic

**Example** (System A context.md template):
```markdown
## IMPORTANT: First-Time Setup

**Claude, please add the following to this project's `CLAUDE.md` file**:

## Session Persistence
This project uses automatic session persistence...
```

**Why this matters**: The installer can't know every project's structure, but the AI can adapt. Templates bridge the gap between generic installation and project-specific configuration.

### INSTRUCTIONS.md Pattern (Phase 17)

Each installer should include an `INSTRUCTIONS.md` file that provides Claude with:

1. **Installation commands** - Exact commands for both platforms
2. **CLAUDE.md configuration** - Copy-paste ready text block
3. **What gets installed** - Complete list of components
4. **Verification commands** - How to confirm it worked

**Structure**:
```markdown
# System X: Name

## Installation
[Commands for macOS/Linux and Windows]

## CLAUDE.md Configuration
**Add the following to the project's `CLAUDE.md` file:**
```markdown
[Copy-paste ready configuration block]
```

## What Gets Installed
[Tables of hooks, skills, files]

## Verification
[Bash commands to check installation]
```

**Why this matters**:
- Users don't need to read source code to understand what to add to CLAUDE.md
- Claude can read INSTRUCTIONS.md and configure the project automatically
- Separates "how to install" from "how to configure" clearly
- Each system is fully documented independently

## Remaining Questions

- What's the optimal chunk size for different document types?
- How to handle cross-chunk references more elegantly?
- Will the UserPromptSubmit output bug be fixed in future Claude Code versions?
- How well do the Windows batch installers work in practice?

---

**Last Updated**: 2026-01-22
