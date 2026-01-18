---
name: skill-health
description: Track skill usage and identify skills needing updates. Track skill usage and effectiveness, identify skills that need updates or maintenance. Use when reviewing skill quality, checking for stale skills, or analyzing skill effectiveness.
---

# Skill Health - Quality Tracking & Maintenance

## Purpose
Monitor skill usage, identify skills that need updates, and suggest maintenance actions. Run health checks periodically or when you notice skill issues.

---

## Health Check Process

### Step 1: Gather Data
Read all skill metadata to analyze health:

```bash
# List all skills
ls ~/.claude/skills/

# For each skill, read metadata.json
cat ~/.claude/skills/{skill-name}/metadata.json
```

### Step 2: Analyze Health Indicators

For each skill, check these indicators:

| Indicator | Healthy | Warning | Action Needed |
|-----------|---------|---------|---------------|
| Last used | < 30 days | 30-90 days | > 90 days |
| Success rate | > 80% | 50-80% | < 50% |
| Version age | < 90 days | 90-180 days | > 180 days |

### Step 3: Generate Report
Present findings to user with suggested actions.

---

## Health Indicators

### 1. Stale Skills (Not Used Recently)

**Detection:**
```
lastUsed > 90 days ago OR lastUsed == null && created > 90 days ago
```

**Report:**
```
⚠️ Stale Skills (not used in 90+ days):
- {skill-name} - Last used: {date} or never

Suggestion: Review if still relevant. Consider archiving if obsolete.
```

**Actions:**
- Review skill - is it still accurate?
- Archive if technology/approach is obsolete
- Update if just needs refresh

### 2. Failing Skills (High Failure Rate)

**Detection:**
```
failureCount / (successCount + failureCount) > 0.2  (>20% failure rate)
```

**Report:**
```
❌ Skills with high failure rate:
- {skill-name} - Success: {X}%, Failures: {Y}

Suggestion: Review and update with more robust solutions.
```

**Actions:**
- Read recent failure context (what went wrong?)
- Update skill with fixes
- Add edge cases to skill

### 3. Frequently Used Skills (Popular)

**Detection:**
```
useCount > 5 AND successRate > 80%
```

**Report:**
```
✅ Popular & reliable skills:
- {skill-name} - Used {X} times, {Y}% success rate

These skills are working well. Consider expanding with more examples.
```

### 4. Similar Skills (Potential Duplicates)

**Detection:**
```
Two skills with >= 3 matching tags AND same category
```

**Report:**
```
🔀 Potentially similar skills:
- {skill-a} and {skill-b}
  Shared tags: {tag1}, {tag2}, {tag3}

Suggestion: Review for overlap. Consider merging.
```

### 5. Outdated Skills (Old Version)

**Detection:**
```
lastUpdated > 180 days ago AND useCount > 0
```

**Report:**
```
📅 Skills that may need version updates:
- {skill-name} - Last updated: {date}
  Used {X} times since then.

Suggestion: Check if tool/API versions have changed.
```

---

## Running a Health Check

### Quick Health Check
When you want a quick overview:

```
Let me run a skill health check...

[Read metadata.json from all skills]
[Analyze against health indicators]
[Report findings]
```

### Full Health Report

```
📊 Skill Health Report - {date}

Total Skills: {N}

✅ Healthy: {X} skills
⚠️ Needs Review: {Y} skills
❌ Needs Update: {Z} skills

DETAILS:

[Stale Skills]
- ...

[Failing Skills]
- ...

[Similar Skills]
- ...

[Outdated Skills]
- ...

RECOMMENDATIONS:
1. {Action 1}
2. {Action 2}
```

---

## Updating Metrics

### After Using a Skill Successfully
Update the skill's metadata.json:
```json
{
  "useCount": {increment by 1},
  "successCount": {increment by 1},
  "lastUsed": "{today's date}"
}
```

### After a Skill Fails
Update the skill's metadata.json:
```json
{
  "useCount": {increment by 1},
  "failureCount": {increment by 1},
  "lastUsed": "{today's date}"
}
```

### After Updating a Skill
Update the skill's metadata.json:
```json
{
  "lastUpdated": "{today's date}",
  "version": "{increment version}",
  "changelog": [{append new entry}]
}
```

---

## Archiving Skills

When a skill is obsolete:

1. Move to archive folder:
```bash
mkdir -p ~/.claude/skills/_archived
mv ~/.claude/skills/{skill-name} ~/.claude/skills/_archived/
```

2. Remove from skill-index/index.json

3. Note: Archived skills can be restored if needed later

---

## Health Check Triggers

Run health checks:
- **Periodically** - Monthly review of all skills
- **After failures** - When a skill doesn't work as expected
- **Before cleanup** - When context is limited and you need to prioritize skills
- **On request** - When user asks about skill quality

---

## Important Notes

- Don't delete skills without user confirmation
- Low usage doesn't mean bad skill - it may just be niche
- High failure rate with recent updates is expected (skill learning)
- Keep archived skills for reference (don't permanently delete)
