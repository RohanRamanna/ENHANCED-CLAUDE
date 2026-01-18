---
name: skill-improver
description: Proactively suggest skill improvements during usage. Monitor skill usage and proactively suggest improvements. Use when a skill worked but could be better, when you notice gaps in skills, or when skills overlap significantly.
---

# Skill Improver - Proactive Improvement Suggestions

## Purpose
Monitor your own skill usage during conversations. When you notice opportunities to improve skills, proactively suggest additions, updates, or merges.

---

## Detection Triggers

### 1. Workaround Not in Skill

**Situation:** You used a skill but had to add a workaround that wasn't documented.

**Detection:**
- Skill was loaded and followed
- You added extra steps beyond what the skill specified
- Those steps were necessary for success

**Prompt:**
```
💡 I noticed I added a workaround that wasn't in the `{skill-name}` skill:

**What I added:** {description of workaround}
**Why:** {reason it was needed}

Would you like me to add this to the skill?
(yes / no / show me the changes)
```

### 2. Missing Information Found

**Situation:** The skill worked, but you discovered additional useful information during use.

**Detection:**
- Skill helped solve the problem
- You learned something new while applying it
- The new info would help future uses

**Prompt:**
```
💡 The `{skill-name}` skill worked, but I discovered something useful:

**New insight:** {what you learned}
**Benefit:** {how it helps}

Would you like me to add this to the skill?
(yes / no / show me the changes)
```

### 3. Skill Overlap Detected

**Situation:** Two skills cover similar ground and could be merged.

**Detection:**
- Loaded two skills with >= 3 matching tags
- Both skills address related problems
- Content could be combined without losing clarity

**Prompt:**
```
🔀 I noticed `{skill-a}` and `{skill-b}` have significant overlap:

**Shared topics:** {list}
**Difference:** {what's unique to each}

Would you like me to merge these into a single skill?
(yes / no / show me the merged version)
```

### 4. Edge Case Hit

**Situation:** An edge case wasn't covered by the skill and required troubleshooting.

**Detection:**
- Skill was used
- Initial approach failed
- Different approach was needed for this specific case

**Prompt:**
```
💡 The `{skill-name}` skill didn't cover this edge case:

**Scenario:** {what was different}
**Solution:** {what worked}

Would you like me to add an edge case section to the skill?
(yes / no / show me the changes)
```

### 5. Deprecated Approach Detected

**Situation:** The skill uses an approach that's now deprecated or has a better alternative.

**Detection:**
- Documentation mentioned deprecation
- A simpler/better approach exists now
- Original approach still works but isn't recommended

**Prompt:**
```
📅 The approach in `{skill-name}` may be outdated:

**Current approach:** {what skill says}
**Better approach:** {new method}
**Reason:** {why it's better}

Would you like me to update the skill?
(yes / no / show me the changes)
```

---

## Improvement Workflow

### Step 1: Detect Opportunity
While using a skill, monitor for any of the triggers above.

### Step 2: Present Suggestion
Use the appropriate prompt template to suggest the improvement.

### Step 3: Handle Response
- **"yes"** - Make the improvement using skill-updater patterns
- **"no"** - Acknowledge and continue without changes
- **"show me"** - Display proposed changes before applying

### Step 4: Apply Changes
If approved:
1. Update the skill's SKILL.md
2. Update metadata.json (version, changelog, lastUpdated)
3. Update skill-index if tags/summary changed

---

## Proactive vs Reactive

### Proactive (skill-improver)
- Suggestions come DURING or AFTER skill use
- Based on observations while working
- Focus on incremental improvements
- Low urgency - skill worked, just could be better

### Reactive (skill-updater)
- Triggered when skill FAILS
- Based on troubleshooting required
- Focus on fixing broken functionality
- High urgency - skill didn't work

---

## Suggestion Templates

### Adding a Workaround
```markdown
## Workarounds

### {Scenario}
If you encounter {condition}:
{steps to work around}
```

### Adding an Edge Case
```markdown
## Edge Cases

### {Case Name}
**When:** {condition that triggers this case}
**Instead of:** {normal approach}
**Do this:** {edge case solution}
```

### Adding a Tip
```markdown
## Tips

- **{Tip title}**: {tip content}
```

### Updating for Deprecation
```markdown
## Solution

> **Note ({date})**: {old approach} is deprecated. Use {new approach} instead.

{updated solution}
```

---

## When NOT to Suggest

- Minor stylistic preferences (not worth updating)
- User-specific configurations (not generalizable)
- One-time workarounds unlikely to recur
- Changes that would make the skill too long/complex

---

## Example: Complete Flow

**Scenario:** Using deno2-http-kv-server skill, discovered a useful pattern.

```
[Applying skill to build Deno server]
[Skill worked, but discovered Response.redirect() for redirects]

Claude: 💡 The `deno2-http-kv-server` skill worked, but I discovered something useful:

**New insight:** Use `Response.redirect(url, 302)` for redirects instead of manual header setting
**Benefit:** Cleaner code, proper status codes

Would you like me to add this to the skill?
(yes / no / show me the changes)

User: yes

Claude: Updated `deno2-http-kv-server` with redirect pattern.

Added to Key Insights:
- `Response.redirect(url, 302)` for temporary redirects (cleaner than manual headers)

Updated metadata:
- Version: 1.2
- Changelog: Added redirect pattern
```

---

## Important Notes

- Only suggest meaningful improvements (avoid noise)
- One suggestion at a time (don't overwhelm)
- Accept "no" gracefully - not every improvement is wanted
- Focus on patterns that help future uses
- Keep skills focused - suggest new skills for unrelated content
