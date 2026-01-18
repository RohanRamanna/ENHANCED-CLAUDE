---
name: skill-validator
description: Validate skills still work by checking dependencies and examples. Validate skill health by checking dependencies, syntax, and examples. Use when reviewing skills, before major updates, or when a skill might be outdated due to tool version changes.
---

# Skill Validator - Test If Skills Still Work

## Purpose
Validate that skills are still functional by checking their dependencies, code syntax, and external references. Identifies outdated or broken skills before they cause failures.

---

## Validation Types

### 1. Dependency Check (Safe - Auto-run)

Check if required tools are installed:

```bash
# Common dependency checks
deno --version      # For Deno skills
bun --version       # For Bun skills
node --version      # For Node skills
python3 --version   # For Python skills
```

**Pass:** Tool installed and returns version
**Fail:** Command not found or errors

### 2. Syntax Check (Safe - Auto-run)

Validate code examples without execution:

| Language | Check Command |
|----------|---------------|
| TypeScript | `deno check file.ts` or `bun build --dry-run` |
| Python | `python3 -m py_compile file.py` |
| JavaScript | `node --check file.js` |
| JSON | `jq '.' file.json` |

**Pass:** No syntax errors
**Fail:** Parse/compile errors

### 3. URL Check (Safe - Auto-run)

Verify documentation URLs in Sources section:

```bash
# Check if URL is reachable
curl -sI "{url}" | head -1
# Look for: HTTP/2 200 or HTTP/1.1 200 OK
```

**Pass:** HTTP 200 response
**Warn:** HTTP 301/302 (redirect - may need update)
**Fail:** HTTP 404/500 or connection error

### 4. Example Execution (Dangerous - Requires Confirmation)

Actually run code examples to verify they work:

**Only run with user confirmation because:**
- May start servers/processes
- May create files/databases
- May make network requests
- May consume API credits

---

## Validation Process

### Step 1: Select Skill to Validate
```bash
# Read skill list
cat ~/.claude/skills/skill-index/index.json

# Or validate specific skill
cat ~/.claude/skills/{skill-name}/SKILL.md
```

### Step 2: Extract Validation Targets

From SKILL.md, identify:
- Code blocks (```typescript, ```python, etc.)
- Shell commands (```bash)
- URLs in Sources section
- Required tools mentioned

### Step 3: Run Safe Validations

```
✅ SAFE (auto-run):
- Dependency checks (version commands)
- Syntax checks (no execution)
- URL reachability (HEAD requests only)

⚠️ DANGEROUS (ask first):
- Code execution
- Server starts
- API calls
- File modifications
```

### Step 4: Generate Report

```
📋 Validation Report: {skill-name}

Dependencies:
✅ deno 2.1.4 installed
✅ bun 1.1.0 installed

Syntax:
✅ TypeScript examples valid
⚠️ Line 45: Deprecated API warning

URLs:
✅ https://docs.deno.com/ (200 OK)
❌ https://old-docs.example.com/ (404 Not Found)

Overall: ⚠️ NEEDS REVIEW
- Update deprecated API on line 45
- Fix broken URL in Sources
```

---

## Validation Commands by Skill Type

### Deno Skills
```bash
# Check Deno installed
deno --version

# Syntax check TypeScript
deno check {file}.ts

# Check if --unstable flags still needed
deno info
```

### Bun Skills
```bash
# Check Bun installed
bun --version

# Syntax check
bun build --dry-run {file}.ts

# Check dependencies
bun pm ls
```

### Python Skills
```bash
# Check Python installed
python3 --version

# Syntax check
python3 -m py_compile {file}.py

# Check package installed
python3 -c "import {package}"
```

### API Skills
```bash
# Check API reachable (safe - no auth)
curl -sI https://api.example.com/health

# Note: Don't make authenticated calls without confirmation
```

---

## Validation Report Format

```
═══════════════════════════════════════════════════════
SKILL VALIDATION REPORT
═══════════════════════════════════════════════════════

Skill: {name}
Version: {version}
Last Updated: {date}

───────────────────────────────────────────────────────
DEPENDENCIES
───────────────────────────────────────────────────────
✅ {tool} {version} - Installed
❌ {tool} - NOT FOUND (required)
⚠️ {tool} {version} - Outdated (skill expects {expected})

───────────────────────────────────────────────────────
CODE SYNTAX
───────────────────────────────────────────────────────
✅ {language} examples - Valid
⚠️ {file}:{line} - Deprecation warning
❌ {file}:{line} - Syntax error

───────────────────────────────────────────────────────
EXTERNAL REFERENCES
───────────────────────────────────────────────────────
✅ {url} - Reachable (200)
⚠️ {url} - Redirects to {new_url}
❌ {url} - Not found (404)

───────────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────────
Status: ✅ VALID | ⚠️ NEEDS REVIEW | ❌ BROKEN

Recommendations:
1. {action item}
2. {action item}

═══════════════════════════════════════════════════════
```

---

## Quick Validation (All Skills)

Run a quick check on all skills:

```bash
# For each skill directory
for skill in ~/.claude/skills/*/; do
  name=$(basename "$skill")
  echo "Checking $name..."

  # Check if SKILL.md exists
  if [ -f "$skill/SKILL.md" ]; then
    echo "  ✅ SKILL.md present"
  else
    echo "  ❌ SKILL.md missing"
  fi

  # Check if metadata.json exists
  if [ -f "$skill/metadata.json" ]; then
    echo "  ✅ metadata.json present"
  else
    echo "  ⚠️ metadata.json missing"
  fi
done
```

---

## When to Validate

### Proactive (scheduled):
- Monthly review of all skills
- After major tool updates (new Deno/Bun/Node version)
- Before sharing skills with others

### Reactive (triggered):
- After a skill fails unexpectedly
- When user reports skill doesn't work
- When skill-health flags high failure rate

---

## Important Notes

- Safe validations can run without asking
- ALWAYS ask before executing actual code
- URL checks use HEAD requests (no body download)
- Syntax checks don't execute code
- Mark skills as `testable: true` in frontmatter if they have safe tests
- Failed validation should trigger skill-updater consideration
