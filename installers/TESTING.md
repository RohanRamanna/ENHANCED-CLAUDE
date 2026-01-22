# Installer Testing Guide

Manual verification steps to confirm each system installer worked correctly.

---

## System A: Session Persistence & Searchable History

### Check Hooks Exist

```bash
ls -la ~/.claude/hooks/hook_logger.py
ls -la ~/.claude/hooks/session-recovery.py
ls -la ~/.claude/hooks/live-session-indexer.py
ls -la ~/.claude/hooks/history-indexer.py
ls -la ~/.claude/hooks/history-search.py
```

**Expected**: All 5 files should exist and be executable.

### Check Template Files Created (in project directory)

```bash
ls -la context.md
ls -la todos.md
ls -la insights.md
```

**Expected**: All 3 template files should exist in the directory where you ran the installer.

**Important**: The `context.md` template includes instructions for Claude to add session persistence guidance to the project's `CLAUDE.md` file. On first use, Claude should:
1. Read the `context.md` template
2. Create or update `CLAUDE.md` with the session persistence instructions
3. Start using the persistence files

### Check Skill Exists

```bash
ls -la ~/.claude/skills/history/SKILL.md
ls -la ~/.claude/skills/history/metadata.json
```

**Expected**: Both files should exist.

### Check Settings.json Has Hooks

```bash
cat ~/.claude/settings.json | grep -A2 "session-recovery"
cat ~/.claude/settings.json | grep -A2 "history-search"
cat ~/.claude/settings.json | grep -A2 "history-indexer"
cat ~/.claude/settings.json | grep -A2 "live-session-indexer"
```

**Expected**: Should see hook entries for SessionStart, UserPromptSubmit, and Stop events.

### Functional Tests

1. **History Indexing**:
   - Start Claude Code
   - Type any message and get a response
   - Exit Claude Code
   - Check: `ls -la ~/.claude/history/index.json` (should exist or be updated)

2. **Session Recovery**:
   - Start Claude Code in a project with `context.md`, `todos.md`, `insights.md`
   - Run `/compact`
   - Check: The persistence file contents should appear in the recovered context

3. **History Search**:
   - Start Claude Code
   - Ask about something you've worked on before (e.g., "how did I set up authentication?")
   - Check: Should see `[HISTORY MATCH]` suggestion if relevant past sessions exist

---

## System B: RLM Detection & Processing

### Check Hooks Exist

```bash
ls -la ~/.claude/hooks/hook_logger.py
ls -la ~/.claude/hooks/large-input-detector.py
```

**Expected**: Both files should exist and be executable.

### Check Skill Exists

```bash
ls -la ~/.claude/skills/rlm/SKILL.md
ls -la ~/.claude/skills/rlm/metadata.json
```

**Expected**: Both files should exist.

### Check RLM Tools Exist

Run from your project directory (where you ran the installer):

```bash
ls -la rlm_tools/probe.py
ls -la rlm_tools/chunk.py
ls -la rlm_tools/aggregate.py
ls -la rlm_tools/parallel_process.py
ls -la rlm_tools/sandbox.py
```

**Expected**: All 5 RLM tool files should exist.

### Check Settings.json Has Hooks

```bash
cat ~/.claude/settings.json | grep -A2 "large-input-detector"
```

**Expected**: Should see hook entry for UserPromptSubmit event.

### Functional Tests

1. **Large Input Detection**:
   - Start Claude Code
   - Paste a large text (>50K characters)
   - Check: Should see a suggestion about using RLM workflow

2. **RLM Tools Work**:
   ```bash
   # Test probe
   echo "Some test content here" > /tmp/test.txt
   python3 rlm_tools/probe.py /tmp/test.txt

   # Test chunk
   python3 rlm_tools/chunk.py /tmp/test.txt --output /tmp/chunks/
   ```
   **Expected**: No errors, tools should run successfully.

---

## System C: Auto Skills & Skills Library

### Check Hooks Exist

```bash
ls -la ~/.claude/hooks/hook_logger.py
ls -la ~/.claude/hooks/skill-matcher.py
ls -la ~/.claude/hooks/skill-tracker.py
ls -la ~/.claude/hooks/detect-learning.py
ls -la ~/.claude/hooks/learning-moment-pickup.py
```

**Expected**: All 5 files should exist and be executable.

### Check Skills Exist

```bash
# Count skills (should be 18)
ls -d ~/.claude/skills/*/ | wc -l

# Check skill index
ls -la ~/.claude/skills/skill-index/index.json
cat ~/.claude/skills/skill-index/index.json | head -20
```

**Expected**: 18 skill directories and a valid index.json file.

### Verify All 18 Skills

```bash
ls ~/.claude/skills/
```

**Expected skills**:
- deno2-http-kv-server
- detect-learning (if created as skill)
- history
- hono-bun-sqlite-api
- hook-development
- llm-api-tool-use
- markdown-to-pdf
- rlm
- skill-creator
- skill-health
- skill-improver
- skill-index
- skill-loader
- skill-matcher
- skill-tracker
- skill-updater
- skill-validator
- udcp
- web-research

### Check Settings.json Has Hooks

```bash
cat ~/.claude/settings.json | grep -A2 "skill-matcher"
cat ~/.claude/settings.json | grep -A2 "skill-tracker"
cat ~/.claude/settings.json | grep -A2 "detect-learning"
cat ~/.claude/settings.json | grep -A2 "learning-moment-pickup"
```

**Expected**: Should see hook entries for UserPromptSubmit, PostToolUse, and Stop events.

### Functional Tests

1. **Skill Matching**:
   - Start Claude Code
   - Type: "help me build a bun sqlite api with hono"
   - Check: Should see `[SKILL MATCH]` suggestion for `hono-bun-sqlite-api`

2. **Skill Tracking**:
   - In Claude Code, read a skill: `cat ~/.claude/skills/hono-bun-sqlite-api/SKILL.md`
   - Check metadata was updated: `cat ~/.claude/skills/hono-bun-sqlite-api/metadata.json`
   - **Expected**: `useCount` should increment, `lastUsed` should be today's date

3. **Learning Detection**:
   - This triggers after 3+ failures followed by success
   - Hard to test manually, but you can check the hook runs:
   ```bash
   echo '{"transcript_path": "/tmp/test.jsonl"}' | python3 ~/.claude/hooks/detect-learning.py
   ```
   **Expected**: Should output `{"continue": true}` without errors

---

## Quick All-in-One Verification

### Count Check Script

```bash
echo "=== Checking Installation ==="
echo ""
echo "Hooks installed:"
ls ~/.claude/hooks/*.py 2>/dev/null | wc -l
echo "(Expected: 10 for all systems, 5 for A, 2 for B, 5 for C)"
echo ""
echo "Skills installed:"
ls -d ~/.claude/skills/*/ 2>/dev/null | wc -l
echo "(Expected: 18 for all systems, 1 for A, 1 for B, 18 for C)"
echo ""
echo "Hook commands in settings.json:"
grep -c "python3.*hooks" ~/.claude/settings.json 2>/dev/null
echo "(Expected: ~9 for all systems)"
echo ""
echo "=== Hook Files ==="
ls ~/.claude/hooks/*.py 2>/dev/null
echo ""
echo "=== Skill Directories ==="
ls ~/.claude/skills/ 2>/dev/null
```

### Expected Counts by System

| Component | System A | System B | System C | All Systems |
|-----------|----------|----------|----------|-------------|
| Hook files | 5 | 2 | 5 | 10* |
| Skills | 1 | 1 | 18 | 18* |
| Settings entries | 4 | 1 | 4 | 9* |

*Note: `hook_logger.py` is shared, so totals don't simply add up.

---

## Troubleshooting

### Hooks Not Running?

1. Check permissions:
   ```bash
   chmod +x ~/.claude/hooks/*.py
   ```

2. Reload hooks in Claude Code:
   ```
   /hooks
   ```

3. Check hook logs:
   ```bash
   tail -20 ~/.claude/hooks/logs/skill-matcher.log
   tail -20 ~/.claude/hooks/logs/large-input-detector.log
   ```

### Settings.json Issues?

1. Validate JSON syntax:
   ```bash
   python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
   ```

2. Check backup exists:
   ```bash
   ls ~/.claude/backups/
   ```

### Skills Not Found?

1. Check skill index is valid:
   ```bash
   python3 -m json.tool ~/.claude/skills/skill-index/index.json > /dev/null
   ```

2. Verify skill has required files:
   ```bash
   ls ~/.claude/skills/hono-bun-sqlite-api/
   # Should show: SKILL.md and metadata.json
   ```

---

## Uninstall Verification

After running an uninstaller, verify removal:

```bash
# System A - these should NOT exist
ls ~/.claude/hooks/session-recovery.py 2>/dev/null && echo "FAIL: still exists" || echo "OK: removed"
ls ~/.claude/hooks/history-search.py 2>/dev/null && echo "FAIL: still exists" || echo "OK: removed"

# System B - these should NOT exist
ls ~/.claude/hooks/large-input-detector.py 2>/dev/null && echo "FAIL: still exists" || echo "OK: removed"

# System C - these should NOT exist
ls ~/.claude/hooks/skill-matcher.py 2>/dev/null && echo "FAIL: still exists" || echo "OK: removed"
ls -d ~/.claude/skills/hono-bun-sqlite-api 2>/dev/null && echo "FAIL: still exists" || echo "OK: removed"

# hook_logger.py should STILL exist (shared)
ls ~/.claude/hooks/hook_logger.py 2>/dev/null && echo "OK: preserved" || echo "WARNING: missing"
```
