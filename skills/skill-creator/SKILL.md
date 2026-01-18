---
name: skill-creator
description: Auto-detect learning moments and create reusable skills. Automatically recognize trial-and-error learning moments and offer to save them as reusable skills. Use when Claude has solved a problem after multiple attempts, discovered a non-obvious solution, or encountered and resolved unexpected errors.
---

# Skill Creator - Auto-Learning from Problem Solving

## Purpose
You are monitoring your own problem-solving process. When you solve something through trial-and-error or discover non-obvious knowledge, offer to save it as a skill for future use.

---

## Detection Criteria

### Trigger skill creation offer when ANY of these occur:

1. **Multiple attempts to success**
   - You tried 2+ different approaches before finding a working solution
   - You encountered an error and had to diagnose/fix it iteratively

2. **Non-obvious discovery**
   - The solution was not what documentation suggested
   - You found a workaround or environment-specific fix
   - Order of operations mattered unexpectedly
   - A specific flag, setting, or configuration was required that wasn't obvious

3. **Knowledge worth preserving**
   - Solution requires 3+ specific steps
   - Exact command syntax or flags are critical
   - There are gotchas that are easy to get wrong
   - You discovered something that would save time in the future

### Do NOT trigger when:
- Solution was straightforward and well-documented (1 attempt)
- Problem was user-specific (wrong file path, typo, missing file)
- Solution is trivial (under 2 steps)
- The fix was just "install the missing package" with no complications

---

## User Confirmation Workflow

### Step 1: Offer to Save
After successfully solving a problem that meets the detection criteria, present:

```
---
I went through some trial-and-error to solve this. Would you like me to save it as a skill for future reference?

**Problem:** [1 sentence describing the issue]
**Solution:** [1 sentence describing what worked]
**Key insight:** [the non-obvious part that was discovered]
**Suggested name:** `{auto-generated-name}`

Create skill? (yes / no / show me first / different name)
---
```

### Step 2: Handle User Response
- **"yes" / "create it"** - Create the skill with suggested name
- **"call it X" / custom name** - Create with user-specified name
- **"show me first"** - Display full SKILL.md content for review before creating
- **"no" / "skip"** - Acknowledge and continue without saving

### Step 3: Create the Skill
```bash
mkdir -p ~/.claude/skills/{name}
```
Then create these files:
1. Write SKILL.md to `~/.claude/skills/{name}/SKILL.md`
2. Write metadata.json to `~/.claude/skills/{name}/metadata.json`
3. Update `~/.claude/skills/skill-index/index.json` with the new skill entry

### Step 4: Confirm Creation
```
Created skill `{name}` at ~/.claude/skills/{name}/

Files created:
- SKILL.md (skill content)
- metadata.json (tracking data)
- Updated skill-index/index.json

This skill will automatically activate when you encounter similar issues in the future.
```

---

## Skill Generation Template

When creating a new skill, use this structure:

### SKILL.md Template (Official Format)
```markdown
---
name: {name}
description: {one-line summary}. {problem-description}. Use when {trigger-phrases-and-conditions}.
---

# {Title Based on Problem Domain}

## Problem Pattern
{Description of the situation/error/challenge that triggers this skill}

## Solution
{The working approach discovered}

### Steps
1. {Step one}
2. {Step two}
3. {Continue as needed}

## Key Insights
- {Insight 1 - why the obvious approach doesn't work}
- {Insight 2 - what was discovered}
- {Gotcha - common mistake to avoid}

## Commands/Code
```{language}
{exact commands or code that worked}
```

## Context
- **Environment**: {OS, tool versions if relevant}
- **Original Error**: {error message if applicable}
- **Root Cause**: {why the problem occurred}

## Troubleshooting
{Common issues and their fixes - add as discovered}

## When NOT to Use
{Conditions where this skill doesn't apply}
```

### metadata.json Template
Also create a metadata.json file alongside SKILL.md:
```json
{
  "category": "{setup | api | debugging | database | meta}",
  "tags": ["{tag1}", "{tag2}", "{tag3}"],
  "dependencies": [],
  "created": "{YYYY-MM-DD}",
  "lastUpdated": "{YYYY-MM-DD}",
  "version": "1.0",
  "useCount": 0,
  "successCount": 0,
  "failureCount": 0,
  "lastUsed": null,
  "changelog": [
    {"version": "1.0", "date": "{YYYY-MM-DD}", "change": "Initial creation"}
  ]
}
```

### Update Skill Index
After creating a skill, add an entry to `~/.claude/skills/skill-index/index.json`:
```json
{
  "name": "{name}",
  "category": "{category}",
  "tags": ["{tag1}", "{tag2}"],
  "description": "{description}",
  "dependencies": [],
  "lastUsed": null,
  "useCount": 0
}
```

---

## Naming Convention

Generate skill names following these rules:

1. **Format**: `{tool}-{issue-type}` or `{domain}-{problem}`
2. **Max 64 characters**
3. **Lowercase only**
4. **Letters, numbers, and hyphens only** (no underscores or special chars)
5. **Cannot contain "claude" or "anthropic"**
6. **Be specific** - prefer `python-venv-pip-path` over `python-fix`

### Naming Patterns by Category:
| Category | Pattern | Example |
|----------|---------|---------|
| Error fixes | `{tool}-{error-keyword}` | `typescript-module-resolution` |
| Configuration | `{tool}-{setting}-setup` | `git-gpg-signing-setup` |
| Workarounds | `{platform}-{tool}-{issue}` | `macos-homebrew-path-fix` |
| Procedures | `{tool}-{action}` | `docker-multi-stage-build` |
| Integration | `{tool1}-{tool2}-config` | `eslint-typescript-flat-config` |

---

## Example: Complete Flow

**Conversation:**
```
User: Help me set up ESLint with TypeScript

Claude: I'll set up ESLint with TypeScript...
[Tries standard eslint init - gets parser errors]

Claude: Getting a parser error. Let me add the TypeScript parser...
[Adds @typescript-eslint/parser - still conflicts]

Claude: There's a config format conflict. ESLint 9 uses flat config by default...
[Converts to eslint.config.js - works]

Claude: Got it working! The issue was mixing legacy and flat config formats.
```

**Skill Creation Offer:**
```
I went through some trial-and-error to solve this. Would you like me to save it as a skill?

**Problem:** ESLint TypeScript setup fails with parser/config conflicts
**Solution:** Use flat config format (eslint.config.js) with explicit TypeScript parser
**Key insight:** ESLint 9+ uses flat config by default; mixing formats causes conflicts
**Suggested name:** `eslint-typescript-flat-config`

Create skill? (yes / no / show me first / different name)
```

**Generated Skill (if user says yes):**

**SKILL.md:**
```markdown
---
name: eslint-typescript-flat-config
description: ESLint + TypeScript using flat config format. Configure ESLint with TypeScript using flat config format. Use when setting up ESLint in a TypeScript project, encountering parser conflicts, or seeing "eslintrc" vs flat config errors.
---

# ESLint TypeScript Flat Config Setup

## Problem Pattern
Setting up ESLint with TypeScript fails with parser errors or configuration conflicts. Common when using ESLint 9+ which defaults to flat config format.

## Solution
Use the new flat config format (eslint.config.js) instead of legacy .eslintrc.

### Steps
1. Create `eslint.config.js` (not `.eslintrc.js`)
2. Install: `npm i -D eslint @eslint/js typescript-eslint`
3. Configure with explicit TypeScript parser

## Key Insights
- ESLint 9+ defaults to flat config; legacy `.eslintrc` files are ignored unless configured
- The `typescript-eslint` package replaces separate `@typescript-eslint/*` packages
- Flat config uses `export default []` array format, not object format

## Commands/Code
```javascript
// eslint.config.js
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
);
```

```bash
npm i -D eslint @eslint/js typescript-eslint
```

## Context
- **Environment**: ESLint 9+, TypeScript 5+
- **Original Error**: "Parsing error: Unexpected token" or config not found
- **Root Cause**: Mixing flat config and legacy config formats

## Troubleshooting
(Add as issues are discovered)

## When NOT to Use
- ESLint 8.x or earlier (use legacy .eslintrc format)
- Projects already using flat config successfully
```

**metadata.json:**
```json
{
  "category": "setup",
  "tags": ["eslint", "typescript", "config", "linting"],
  "dependencies": [],
  "created": "2026-01-15",
  "lastUpdated": "2026-01-15",
  "version": "1.0",
  "useCount": 0,
  "successCount": 0,
  "failureCount": 0,
  "lastUsed": null,
  "changelog": [
    {"version": "1.0", "date": "2026-01-15", "change": "Initial creation"}
  ]
}
```

---

## Important Notes

- Always ask the user before creating a skill - never auto-create
- Keep skill descriptions under 1024 characters
- Keep SKILL.md content focused and under ~3k tokens
- If the solution has environment-specific aspects, note them in Context
- Include "When NOT to Use" to prevent false matches
