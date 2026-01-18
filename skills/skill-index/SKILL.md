---
name: skill-index
description: Index and discover available skills by category/tags. Use when looking for relevant skills, checking what skills exist, categorizing new skills, or finding skills by keyword/category.
---

# Skill Index - Discover and Search Skills

## Purpose
Maintain a searchable index of all available skills for quick discovery without loading full skill content. Use this skill when you need to find relevant skills or check what capabilities exist.

---

## How to Use

### 1. Check the Index
Read the index to find relevant skills:
```bash
cat ~/.claude/skills/skill-index/index.json
```

### 2. Search by Category
Available categories:
- `meta` - Skills about skills (creator, updater, research)
- `setup` - Project setup and configuration patterns
- `api` - API integration patterns
- `debugging` - Error diagnosis and fixes
- `database` - Database patterns and operations

### 3. Search by Tags
Find skills with specific tags in the index.json `tags` array.

### 4. Load Relevant Skill
Once you identify a relevant skill, read its SKILL.md:
```bash
cat ~/.claude/skills/{skill-name}/SKILL.md
```

---

## Index Structure

The `index.json` contains an array of skill entries:

```json
{
  "skills": [
    {
      "name": "skill-name",
      "category": "setup",
      "tags": ["tag1", "tag2"],
      "summary": "One-line description",
      "dependencies": [],
      "lastUsed": "2026-01-15",
      "useCount": 3
    }
  ],
  "lastUpdated": "2026-01-15"
}
```

---

## Maintenance

### When to Update Index
- After creating a new skill (via skill-creator)
- After updating a skill (via skill-updater)
- After deleting a skill
- Periodically to sync usage stats

### Update Process
1. Read the skill's frontmatter (summary, category, tags, depends-on)
2. Read the skill's metadata.json (useCount, lastUsed)
3. Update or add entry in index.json

---

## Quick Reference

### Find Skills by Problem Type

| If you need... | Look for category/tags |
|----------------|------------------------|
| Set up a project | `category: setup` |
| API integration | `category: api` or `tags: [api]` |
| Debug an error | `category: debugging` |
| Database operations | `tags: [database, sqlite, kv]` |
| Learn/create skills | `category: meta` |

### Skills at a Glance (from index)

Read `~/.claude/skills/skill-index/index.json` for a quick overview of all available skills with their summaries.

---

## Important Notes

- Always check the index FIRST before loading full skill content
- Index provides summaries - only load full SKILL.md when needed
- Keep index updated when skills change
- Use index to avoid loading irrelevant skills (saves context)
