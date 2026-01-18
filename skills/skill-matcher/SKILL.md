---
name: skill-matcher
description: Smart skill discovery with scoring and proactive suggestions. Find the best matching skill for a request using scored matching. Use when searching for relevant skills, suggesting skills proactively, or when no obvious skill match exists.
---

# Skill Matcher - Smart Skill Discovery

## Purpose
Find the most relevant skill for a given request using a scoring algorithm. Provides better matches than simple keyword search and can proactively suggest skills.

---

## Matching Algorithm

### Score Calculation

For each skill, calculate a relevance score:

| Match Type | Points | Example |
|------------|--------|---------|
| Exact tag match | +3 | Request has "deno", skill tagged "deno" |
| Category match | +5 | Request is about "setup", skill category is "setup" |
| Summary keyword | +2 | Request word appears in summary |
| Description keyword | +1 | Request word appears in description |
| Recent use bonus | +1 | lastUsed < 7 days ago |
| High success rate | +2 | successCount / useCount > 80% |

### Scoring Process

```
1. Extract keywords from user request
2. For each skill in index:
   a. Check tag matches (+3 each)
   b. Check category match (+5)
   c. Check summary keywords (+2 each)
   d. Check description keywords (+1 each)
   e. Add recency bonus if applicable (+1)
   f. Add success rate bonus if applicable (+2)
3. Sort skills by score descending
4. Return top 3 candidates
```

---

## Match Thresholds

| Score | Action |
|-------|--------|
| >= 10 | Strong match - recommend confidently |
| 5-9 | Possible match - mention as option |
| < 5 | Weak match - suggest web-research instead |

---

## Matching Workflow

### Step 1: Extract Intent

From user request, identify:
- **Keywords:** Technical terms (deno, api, database, etc.)
- **Action:** What they want to do (build, fix, set up, etc.)
- **Context:** Any constraints (typescript, python, etc.)

Example:
```
Request: "Help me build a REST API with TypeScript"
Keywords: [REST, API, TypeScript]
Action: build
Context: TypeScript
```

### Step 2: Score Skills

```
Reading skill-index/index.json...

Skill: hono-bun-sqlite-api
- Tags: [hono, bun, sqlite, api, rest, typescript]
  - "api" match: +3
  - "rest" match: +3
  - "typescript" match: +3
- Category: setup
  - "build" implies setup: +5
- Summary: "REST API with Hono, Bun and SQLite"
  - "REST" match: +2
  - "API" match: +2
- Total: 18 points ✅ STRONG MATCH

Skill: deno2-http-kv-server
- Tags: [deno, http, kv, database, server, typescript]
  - "typescript" match: +3
- Category: setup: +5
- Summary: "Deno 2 HTTP server with KV database"
  - No direct matches
- Total: 8 points ⚠️ POSSIBLE MATCH

Skill: llm-api-tool-use
- Tags: [anthropic, llm, tool-use, python, sdk, agents]
  - No tag matches
- Category: api: +5
- Total: 5 points ⚠️ WEAK MATCH
```

### Step 3: Return Results

```
🎯 Best matches for "build a REST API with TypeScript":

1. hono-bun-sqlite-api (score: 18) ⭐ RECOMMENDED
   "REST API with Hono, Bun and SQLite"

2. deno2-http-kv-server (score: 8)
   "Deno 2 HTTP server with KV database"

3. llm-api-tool-use (score: 5)
   "Claude API tool use with Python SDK"
```

---

## Proactive Suggestions

### After Solving a Problem

If you solve a problem without using a skill, check if one exists:

```
💡 FYI: The `{skill-name}` skill covers this topic.
   It might help next time you need to {summary}.
```

### When Similar Task Detected

If the user's request is similar to a high-scoring skill:

```
💡 You might find the `{skill-name}` skill helpful.
   It covers {summary} and has worked well before
   (used {useCount} times, {successRate}% success rate).
```

### When No Good Match

If no skill scores above threshold:

```
🔍 No existing skill matches this request well.
   Options:
   1. Use web-research to find a solution
   2. After solving, consider creating a new skill
```

---

## Category Inference

Map user intent to categories:

| User Says | Likely Category |
|-----------|-----------------|
| "set up", "create", "build", "start" | setup |
| "fix", "debug", "error", "not working" | debugging |
| "API", "endpoint", "request", "fetch" | api |
| "database", "store", "persist", "query" | database |
| "skill", "learning", "track" | meta |

---

## Tag Synonyms

Expand search with common synonyms:

| Term | Also Match |
|------|------------|
| "REST" | api, http, endpoint |
| "database" | db, storage, persist, kv, sqlite |
| "server" | http, api, backend |
| "TypeScript" | ts, typescript |
| "JavaScript" | js, javascript |

---

## Example: Complete Matching Flow

**User:** "I need to store data persistently in a Deno app"

```
Step 1: Extract Intent
- Keywords: [store, data, persistently, Deno]
- Action: store (implies database)
- Context: Deno

Step 2: Score Skills

deno2-http-kv-server:
- Tags: deno (+3), database (+3)
- Category: setup (+5)
- Summary: "KV database" - database (+2), Deno (+2)
- Total: 15 ⭐

hono-bun-sqlite-api:
- Tags: sqlite (+3)
- Category: setup (+5)
- Total: 8

Step 3: Recommend

🎯 Best match: deno2-http-kv-server (score: 15)
   "Deno 2 HTTP server with KV database"

   This skill covers Deno's built-in KV database for
   persistent storage. Load it?
```

---

## Fallback Behavior

When no skill matches well (all scores < 5):

1. **Suggest web-research:**
   ```
   No existing skill covers this well. Let me research it.
   [Trigger web-research skill]
   ```

2. **After solving, suggest skill-creator:**
   ```
   I solved this through research. Want to save it as a skill?
   [Trigger skill-creator if successful]
   ```

---

## Important Notes

- Always show the score reasoning (transparency)
- Don't overwhelm with too many suggestions (max 3)
- Prefer skills with high success rates
- Consider recency - recently used skills are more likely relevant
- Update skill-index usage stats to improve future matching
- Proactive suggestions should be helpful, not annoying
