---
name: skill-tracker
description: Automatically track skill usage, success, and failure. Track skill usage metrics automatically. Use after loading any skill to update its useCount, after confirming a skill worked to update successCount, or when a skill fails to update failureCount.
---

# Skill Tracker - Automatic Usage Metrics

## Purpose
Automatically update skill metadata when skills are used. This enables accurate health monitoring and identifies which skills are most valuable.

---

## Tracking Events

### 1. Skill Loaded (useCount++)

**When:** Immediately after reading a skill's SKILL.md to apply it.

**Action:** Update the skill's metadata.json and index.json:
```json
{
  "useCount": {current + 1},
  "lastUsed": "{today's date YYYY-MM-DD}"
}
```

**How to track:**
```bash
# Read current metadata
cat ~/.claude/skills/{skill-name}/metadata.json

# Update useCount and lastUsed
# Write updated metadata back
```

### 2. Skill Succeeded (successCount++)

**When:** After applying a skill and confirming the solution worked.

**Signals of success:**
- User confirms "that worked" or "perfect"
- Code runs without errors
- Expected output achieved
- No further troubleshooting needed

**Action:** Update metadata.json:
```json
{
  "successCount": {current + 1}
}
```

### 3. Skill Failed (failureCount++)

**When:** The skill's solution didn't work and required troubleshooting.

**Signals of failure:**
- Errors after following the skill
- Solution didn't match expected behavior
- Had to find alternative approach
- skill-updater was triggered

**Action:** Update metadata.json:
```json
{
  "failureCount": {current + 1}
}
```

### 4. Skill Updated (version++)

**When:** skill-updater modifies a skill's content.

**Action:** Update metadata.json:
```json
{
  "lastUpdated": "{today's date}",
  "version": "{increment version}",
  "changelog": [{append: {"version": "X.Y", "date": "...", "change": "..."}}]
}
```

---

## Tracking Workflow

```
┌─────────────────────────────────────────────────────────┐
│ SKILL LOADED                                            │
│ → Read SKILL.md for {skill-name}                        │
│ → Immediately: useCount++, lastUsed = today             │
├─────────────────────────────────────────────────────────┤
│ APPLY SKILL                                             │
│ → Follow skill instructions                             │
│ → Execute code/commands                                 │
├─────────────────────────────────────────────────────────┤
│ OUTCOME                                                 │
│ ├─ SUCCESS: "It worked!" → successCount++               │
│ └─ FAILURE: Errors/issues → failureCount++              │
│             → May trigger skill-updater                 │
└─────────────────────────────────────────────────────────┘
```

---

## Update Templates

### Increment useCount on Load
```bash
# After reading ~/.claude/skills/{name}/SKILL.md
# Update metadata.json with:
{
  "useCount": {old_value + 1},
  "lastUsed": "2026-01-15"
}

# Also update skill-index/index.json entry for this skill
```

### Increment successCount on Success
```bash
# After confirming skill worked
# Update metadata.json with:
{
  "successCount": {old_value + 1}
}
```

### Increment failureCount on Failure
```bash
# After skill solution failed
# Update metadata.json with:
{
  "failureCount": {old_value + 1}
}
```

---

## When to Track

### ALWAYS track:
- Every time you read a SKILL.md to apply it (useCount)
- When user explicitly confirms success
- When you need to troubleshoot/fix the skill's solution

### DON'T track:
- Reading a skill just to check if it exists
- Browsing the index without using a skill
- Reading metadata.json (not actual skill usage)

---

## Sync with skill-index

After updating any skill's metadata.json, also update the corresponding entry in `~/.claude/skills/skill-index/index.json`:

```json
{
  "name": "{skill-name}",
  "useCount": {same as metadata.json},
  "lastUsed": "{same as metadata.json}"
}
```

This keeps the index accurate for skill-health reports.

---

## Example: Complete Tracking Flow

**User asks:** "Help me build a REST API with Bun"

```
1. [Search index] → Found hono-bun-sqlite-api (score: 15)

2. [Load skill] → Read SKILL.md
   → TRACK: useCount: 0 → 1, lastUsed: 2026-01-15

3. [Apply skill] → Follow CRUD example, run server

4. [Test] → curl http://localhost:3000/items → Works!

5. [User confirms] → "Perfect, that's exactly what I needed"
   → TRACK: successCount: 0 → 1

Final metadata.json:
{
  "useCount": 1,
  "successCount": 1,
  "failureCount": 0,
  "lastUsed": "2026-01-15"
}
```

---

## Failure Tracking Example

**User asks:** "Set up Deno KV server"

```
1. [Load skill] → Read deno2-http-kv-server SKILL.md
   → TRACK: useCount: 0 → 1

2. [Apply skill] → Follow basic example

3. [Error] → "KV not working" - forgot --unstable-kv flag

4. [Troubleshoot] → Found issue in skill's troubleshooting section
   → TRACK: failureCount: 0 → 1 (initial approach failed)

5. [Retry with flag] → Works now
   → Note: Still counts as 1 use with 1 failure
   → The failure was recorded, fix was in the skill
```

---

## Important Notes

- Track EVERY skill load, even if it's the same skill multiple times
- Success and failure are mutually exclusive per use session
- A skill can be used successfully after initial failure (both get counted)
- Keep index.json in sync with individual metadata.json files
- Don't track meta-skills loading other meta-skills (avoid recursive tracking)
