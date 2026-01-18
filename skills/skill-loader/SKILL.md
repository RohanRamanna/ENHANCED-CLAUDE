---
name: skill-loader
description: Lazy-load skills to minimize context usage. Implement lazy loading of skill content to save context tokens. Use when loading skills, managing context efficiency, or deciding what skill content to read.
---

# Skill Loader - Context-Efficient Skill Loading

## Purpose
Load skills progressively to minimize context usage. Don't load full skill content until you're sure it's relevant.

---

## Loading Levels

### Level 1: Index Only (~50 tokens per skill)
Always start here. Read the index to find potentially relevant skills.

```bash
cat ~/.claude/skills/skill-index/index.json
```

**Contains:** name, category, tags, summary, useCount, lastUsed

**Decision:** Based on summary and tags, is this skill likely relevant?
- If NO → Don't load anything more
- If MAYBE → Load Level 2
- If YES → Load Level 2 or 3

---

### Level 2: Core Content (~500-2000 tokens)
Load the main SKILL.md when the skill seems relevant.

```bash
cat ~/.claude/skills/{skill-name}/SKILL.md
```

**Contains:** Full instructions, patterns, key insights, basic examples

**Decision:** Does this skill solve my current problem?
- If NO → Stop, don't use this skill
- If YES → Apply the skill; load Level 3 if needed

---

### Level 3: Extended Content (optional, ~500+ tokens each)
Only load if you need more examples or edge cases.

```bash
# If the skill has extended content:
cat ~/.claude/skills/{skill-name}/examples.md      # More examples
cat ~/.claude/skills/{skill-name}/edge-cases.md   # Edge cases
```

**Note:** Most skills only have SKILL.md. Extended files are optional.

---

## Loading Decision Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. READ INDEX                                           │
│    → Check skill-index/index.json                       │
│    → Find skills matching category/tags/summary         │
│                                                         │
│    Relevant skill found?                                │
│    ├─ NO  → Stop (no skill needed)                      │
│    └─ YES → Continue to step 2                          │
├─────────────────────────────────────────────────────────┤
│ 2. LOAD CORE CONTENT                                    │
│    → Read {skill-name}/SKILL.md                         │
│    → Understand the approach                            │
│                                                         │
│    Skill applies to current problem?                    │
│    ├─ NO  → Stop (wrong skill)                          │
│    └─ YES → Apply the skill                             │
├─────────────────────────────────────────────────────────┤
│ 3. LOAD EXTENDED (only if needed)                       │
│    → Read examples.md if need more examples             │
│    → Read edge-cases.md if hitting unusual issue        │
└─────────────────────────────────────────────────────────┘
```

---

## Best Practices

### DO:
- Start with the index for every skill lookup
- Use summary + tags to filter before loading full content
- Only load one skill at a time (the most relevant one)
- Update skill usage stats after successfully using a skill

### DON'T:
- Load multiple full SKILL.md files "just in case"
- Skip the index and load skills directly
- Load extended content unless specifically needed
- Keep old skill content in context after you're done with it

---

## Example: Finding the Right Skill

**Scenario:** User wants to build a REST API with Bun

```
Step 1: Read index.json
        → Found "hono-bun-sqlite-api" with tags [hono, bun, sqlite, api]
        → Summary: "REST API with Hono, Bun and SQLite"
        → This looks relevant!

Step 2: Load SKILL.md
        → Read ~/.claude/skills/hono-bun-sqlite-api/SKILL.md
        → Contains setup steps, CRUD patterns, SQLite operations
        → This is exactly what I need!

Step 3: Apply the skill
        → Follow the patterns in the skill
        → No need for extended content (skill was sufficient)
```

**Tokens used:** ~50 (index) + ~1500 (SKILL.md) = ~1550 tokens
**Without lazy loading:** Would have loaded ALL skills = ~8000+ tokens

---

## Updating Usage Stats

After successfully using a skill, update its stats:

1. Update the skill's metadata.json:
```json
{
  "useCount": 1,  // increment
  "lastUsed": "2026-01-15"  // current date
}
```

2. Update skill-index/index.json entry:
```json
{
  "name": "skill-name",
  "useCount": 1,
  "lastUsed": "2026-01-15"
}
```

This helps skill-health identify frequently used and stale skills.

---

## Automatic Tracking (skill-tracker Integration)

**IMPORTANT:** After loading and using a skill, track it automatically.

### On Skill Load
Immediately after reading a skill's SKILL.md:
```
→ Update metadata.json: useCount++, lastUsed = today
→ Update index.json: same fields
```

### On Success
When the skill's solution works:
```
→ Update metadata.json: successCount++
```

### On Failure
When the skill's solution fails:
```
→ Update metadata.json: failureCount++
→ Consider triggering skill-updater
```

See `skill-tracker` for detailed tracking workflow.

---

## Post-Use Deviation Detection

```
╔═══════════════════════════════════════════════════════════════════╗
║  ⚠️  MANDATORY: CHECK FOR DEVIATIONS AFTER EVERY SKILL USE  ⚠️    ║
╚═══════════════════════════════════════════════════════════════════╝
```

**CRITICAL:** After applying a skill, ALWAYS check if you deviated from the documented steps. This is how skills improve over time.

### Deviation Check (Do This Every Time)

After the skill is applied and the task succeeds, ask yourself:

```
┌─────────────────────────────────────────────────────────┐
│  Did I follow the documented steps EXACTLY as written?  │
├─────────────────────────────────────────────────────────┤
│  YES → Track success (successCount++), done             │
│  NO  → TRIGGER skill-updater workflow                   │
└─────────────────────────────────────────────────────────┘
```

### What Counts as a Deviation?

| Deviation Type | Example |
|----------------|---------|
| **Command didn't work** | `bun` not found, had to use `~/.bun/bin/bun` |
| **Extra step required** | Had to install a dependency not mentioned |
| **Different approach** | Used alternative syntax or method |
| **Environment workaround** | PATH issue, permission fix, config change |
| **Version difference** | Newer version has different API |

### When Deviation Detected → Use skill-updater

If you deviated from documented steps, trigger the skill-updater boxed prompt:

```
╔════════════════════════════════════════════════════════╗
║         SKILL LEARNING OPPORTUNITY DETECTED            ║
╠════════════════════════════════════════════════════════╣
║ Skill: {skill-name}                                    ║
║ Result: ✓ SUCCESS WITH DEVIATION                       ║
╠════════════════════════════════════════════════════════╣
║ DOCUMENTED: {what skill said to do}                    ║
║ ACTUAL: {what I did instead}                           ║
║ REASON: {why deviation was necessary}                  ║
╠════════════════════════════════════════════════════════╣
║ Update this skill?  [yes] [no] [show diff]             ║
╚════════════════════════════════════════════════════════╝
```

### Examples of Deviations to Catch

1. **PATH not updated after install**
   - Documented: `bun run index.ts`
   - Actual: `~/.bun/bin/bun run index.ts`
   - Why: Fresh install, shell PATH not reloaded

2. **Missing dependency**
   - Documented: `npm start`
   - Actual: `npm install && npm start`
   - Why: Skill assumed deps were installed

3. **API changed**
   - Documented: `db.query().all()`
   - Actual: `db.prepare().all()`
   - Why: Newer version uses different method

### Important

- **Don't skip this check** - Deviations are learning opportunities
- **Small workarounds matter** - Even minor deviations help future users
- **Prompt every time** - Let the user decide if it's worth updating
- **This catches what failure detection misses** - Skill "succeeded" but needed undocumented steps

---

## Post-Task Learning Check

```
╔═══════════════════════════════════════════════════════════════════╗
║  ⚠️  MANDATORY: RUN THIS CHECK AFTER COMPLETING ANY TASK  ⚠️       ║
╚═══════════════════════════════════════════════════════════════════╝
```

**CRITICAL:** After completing ANY non-trivial task, ALWAYS run this learning check. This catches NEW knowledge that should become skills.

### The Check (Do This Every Time)

```
┌─────────────────────────────────────────────────────────────────────┐
│              POST-TASK LEARNING CHECK                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Did I use an existing skill to complete this task?              │
│     ├─ YES → Run "Post-Use Deviation Detection" (above)             │
│     └─ NO  → Continue to step 2                                     │
│                                                                     │
│  2. Did I solve this through trial-and-error?                       │
│     (Multiple attempts, failed approaches, non-obvious solution)    │
│     ├─ YES → Continue to step 3                                     │
│     └─ NO  → Done (task was straightforward)                        │
│                                                                     │
│  3. Is this knowledge worth preserving?                             │
│     (Would help future users, not user-specific, reusable)          │
│     ├─ YES → TRIGGER skill-creator prompt (below)                   │
│     └─ NO  → Done                                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Trigger skill-creator

Trigger the skill creation prompt when ANY of these occurred:

| Indicator | Example |
|-----------|---------|
| **Multiple failed attempts** | Tried 2+ approaches before success |
| **Non-obvious solution** | Answer wasn't in first search result |
| **Unexpected workaround** | Had to work around a limitation |
| **Tool discovery** | Found a tool/library that "just works" |
| **Environment gotcha** | macOS/Linux/Windows-specific fix |

### skill-creator Prompt (Use This Exactly)

```
╔════════════════════════════════════════════════════════╗
║         SKILL LEARNING OPPORTUNITY DETECTED            ║
╠════════════════════════════════════════════════════════╣
║ Problem: {what I was trying to do}                     ║
║ Attempts: {N approaches tried}                         ║
║ Solution: {what finally worked}                        ║
╠════════════════════════════════════════════════════════╣
║ Key insight: {the non-obvious part}                    ║
╠════════════════════════════════════════════════════════╣
║ Create skill `{suggested-name}`?  [yes] [no]           ║
╚════════════════════════════════════════════════════════╝
```

### Example: When This Should Have Triggered

**Task:** Convert markdown to PDF

```
Attempt 1: pandoc → not installed
Attempt 2: pandoc + pdflatex → LaTeX not installed
Attempt 3: weasyprint → missing system libraries
Attempt 4: wkhtmltopdf → cask unavailable
Attempt 5: md-to-pdf → ✅ SUCCESS

Post-Task Learning Check:
1. Used existing skill? NO
2. Trial-and-error? YES (5 attempts)
3. Worth preserving? YES (common task, non-obvious solution)

→ SHOULD TRIGGER skill-creator prompt
```

### Why This Matters

Without this check:
- ❌ Knowledge disappears after the conversation
- ❌ Same problems get re-solved from scratch
- ❌ The system never learns from new discoveries

With this check:
- ✅ Trial-and-error becomes reusable knowledge
- ✅ Skills grow organically from real problems
- ✅ Future tasks are faster

---

## Important Notes

- **Context is precious** - Every token loaded reduces room for conversation
- **Index first, always** - Never skip the index lookup step
- **One skill at a time** - Load only what you need for the current task
- **Trust the summaries** - They're designed for quick relevance checking
- **Track every use** - Update metadata after using skills (see skill-tracker)
- **Run post-task check** - ALWAYS check for learning opportunities after tasks
