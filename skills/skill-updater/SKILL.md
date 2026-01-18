---
name: skill-updater
description: Update skills when they fail or better solutions are found. Update existing skills when their solutions fail, require workarounds, or when better approaches are discovered. Use when a skill was applied but didn't work, when you had to deviate from documented steps, or when an existing skill needs corrections or improvements.
---

# Skill Updater - Improving Skills When Solutions Fail

## Purpose
Monitor when an existing skill is used but its solution fails or is incomplete. When you discover a better, more foolproof solution through troubleshooting, offer to update the skill with the improved approach.

---

## Detection Criteria

### Trigger skill update offer when ANY of these occur:

#### Trigger 1: Skill Failed
1. An existing skill was referenced or used
2. The skill's solution **failed** or was incomplete
3. You found a better solution

#### Trigger 2: Workaround Was Used (NEW)
1. An existing skill was referenced or used
2. The skill's solution **worked** BUT you deviated from documented steps
3. The deviation was necessary (not just personal preference)

**Examples of workarounds to catch:**
| Documented | What You Did | Why |
|------------|--------------|-----|
| `bun run index.ts` | `~/.bun/bin/bun run index.ts` | PATH not updated after fresh install |
| `npm start` | `npm install && npm start` | Dependencies weren't installed |
| `db.query()` | `db.prepare()` | API changed in newer version |
| (no step) | `chmod +x script.sh` | Permission fix was needed |

### When to Trigger

| Scenario | Trigger? | Why |
|----------|----------|-----|
| Skill failed, found fix | ✅ YES | Classic update case |
| Skill worked with workaround | ✅ YES | **Deviation = learning opportunity** |
| Skill worked exactly as documented | ❌ NO | Nothing to improve |
| User-specific issue (wrong path) | ❌ NO | Not generalizable |
| Minor preference difference | ❌ NO | Not worth updating |

### Do NOT trigger when:
- The failure was user-specific (wrong path, missing credentials)
- The skill worked correctly as documented with no deviations
- The issue was unrelated to the skill's domain
- The deviation was personal preference, not necessity

---

## Update Workflow

### Step 1: Identify the Gap
After the original skill failed and you found a fix, identify:
- What specifically failed?
- Why did it fail? (version change, edge case, missing step)
- What's the improved solution?

### Step 2: Offer to Update
Present to the user with this highly visible format:

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

For failures (not deviations), use this variant:
```
╔════════════════════════════════════════════════════════╗
║         SKILL LEARNING OPPORTUNITY DETECTED            ║
╠════════════════════════════════════════════════════════╣
║ Skill: {skill-name}                                    ║
║ Result: ✗ FAILURE - FIX FOUND                          ║
╠════════════════════════════════════════════════════════╣
║ DOCUMENTED: {what skill said to do}                    ║
║ FAILED: {what went wrong}                              ║
║ FIX: {what actually worked}                            ║
╠════════════════════════════════════════════════════════╣
║ Update this skill?  [yes] [no] [show diff]             ║
╚════════════════════════════════════════════════════════╝
```

### Step 3: Handle User Response
- **"yes"** - Update the skill immediately
- **"show me the changes first"** - Display diff/comparison before updating
- **"no"** - Acknowledge and continue without updating

### Step 4: Update the Skill

Read the existing skill:
```bash
cat ~/.claude/skills/{skill-name}/SKILL.md
```

Then update it with improvements. Common update patterns:

#### Pattern A: Add Missing Steps
Add new steps to the existing solution section.

#### Pattern B: Add Edge Case
Add a new "Troubleshooting" or "Edge Cases" section:
```markdown
## Edge Cases

### {Specific Scenario}
If you encounter {condition}, use this approach instead:
{improved solution}
```

#### Pattern C: Replace Outdated Solution
When the original approach is obsolete:
```markdown
## Solution

> **Updated {date}**: Previous approach using {old method} no longer works.
> Now requires {new method}.

{new solution}
```

#### Pattern D: Add Version-Specific Notes
```markdown
## Version Notes

- **v2.x+**: Use {new approach}
- **v1.x**: Use {old approach} (deprecated)
```

### Step 5: Confirm Update
```
Updated skill `{skill-name}` with:
- {summary of changes}

The skill will now handle this case in the future.
```

### Step 6: Verification Checklist
After updating a skill, verify all components are in sync:

```
┌─────────────────────────────────────────────────────────┐
│                    UPDATE VERIFICATION                  │
├─────────────────────────────────────────────────────────┤
│ ✓ SKILL.md updated with fix/improvement                 │
│ ✓ metadata.json version bumped                          │
│ ✓ metadata.json lastUpdated = today                     │
│ ✓ metadata.json changelog entry added                   │
│ ✓ Troubleshooting section added/updated (if applicable) │
│ ✓ skill-index/index.json synced (if description changed)│
└─────────────────────────────────────────────────────────┘
```

---

## Update Templates

### Adding a Troubleshooting Section
```markdown
## Troubleshooting

### {Error or Issue}
**Symptom**: {what you see}
**Cause**: {why it happens}
**Fix**: {how to resolve}
```

### Adding Prerequisites
```markdown
## Prerequisites

Before following this guide, ensure:
- [ ] {requirement 1}
- [ ] {requirement 2}
```

### Adding Version Compatibility
```markdown
## Compatibility

| Version | Status | Notes |
|---------|--------|-------|
| 2.x | ✅ Supported | Use this guide |
| 1.x | ⚠️ Different | See legacy section |
```

### Marking Deprecated Approaches
```markdown
## Solution

~~**Old approach (deprecated)**:~~
~~{old solution}~~

**Current approach**:
{new solution}
```

---

## Example: Complete Flow

**Scenario**: User follows `deno2-http-kv-server` skill but KV doesn't persist after restart.

**Conversation**:
```
User: The visitor counter resets every time I restart the server

Claude: [Investigates, finds the issue]
The skill's example uses an in-memory KV path. For persistence across restarts,
you need to specify a file path.

[Finds solution]
Got it - using `Deno.openKv("./data.db")` persists the data to disk.
```

**Update Offer**:
```
I noticed the `deno2-http-kv-server` skill didn't cover data persistence across restarts.

**Original approach:** `const kv = await Deno.openKv();`
**What failed:** Data resets on server restart (uses temp storage)
**Improved solution:** `const kv = await Deno.openKv("./data.db");` for persistent storage

Would you like me to update the skill with this improvement?
(yes / no / show me the changes first)
```

**After Update**:
```
Updated skill `deno2-http-kv-server` with:
- Added persistent storage option with file path
- Added note about default behavior (temp storage)
- Added troubleshooting section for data persistence

The skill will now cover this case in the future.
```

---

## Principles for Good Updates

1. **Preserve working content** - Don't remove solutions that work; add alternatives
2. **Be specific about conditions** - Clearly state when the new solution applies
3. **Add context** - Explain WHY the original failed (version, environment, edge case)
4. **Keep it scannable** - Use headers, tables, and bullet points
5. **Date significant changes** - Note when major updates were made
6. **Don't over-update** - Only update for meaningful improvements, not minor tweaks

---

## Failure Tracking (skill-tracker Integration)

**IMPORTANT:** When a skill fails, track it before updating.

### Before Updating
When you detect a skill failure:
```
1. Track the failure:
   → Update metadata.json: failureCount++
   → Update index.json: same

2. Then proceed with update workflow
```

### After Updating
When the skill is successfully updated:
```
→ Update metadata.json: version++, lastUpdated = today
→ Add changelog entry with what was fixed
→ Update index.json: same
```

This creates a feedback loop where:
- Failures are recorded for skill-health analysis
- Updates are tracked for version history
- High failure rates trigger maintenance suggestions

---

## Important Notes

- Always ask the user before updating a skill
- Read the full existing skill before proposing changes
- Preserve the original skill structure and formatting
- Add new sections rather than replacing working content when possible
- If the skill needs major rewriting, consider creating a new skill instead
- **Track failures** - Update failureCount when skill-updater triggers (see skill-tracker)
