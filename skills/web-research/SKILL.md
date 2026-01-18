---
name: web-research
description: Fallback research when stuck after initial attempt fails. Use AFTER attempting a solution that failed, when encountering an unfamiliar error, or when existing skills don't cover the situation. Do NOT use as a first resort - try existing knowledge and skills first.
---

# Web Research - Fallback When Stuck

## Purpose

This is a **fallback skill**, not a first resort. Attempt solutions using existing knowledge and skills before researching. Research consumes context tokens and should be reserved for when you're genuinely stuck.

---

## Decision Flow

```
1. Check existing skills     → Use skill if match found
2. Try with existing knowledge → Attempt solution confidently
3. Hit a wall / error?        → NOW research
4. Still uncertain?           → Research specific gap
```

---

## When to Research (Fallback Triggers)

### DO research when:
1. **First attempt failed** - You tried something and got an unexpected error
2. **Genuinely unfamiliar** - You truly don't know (not just "could verify")
3. **Error you can't diagnose** - Stuck on an error message after trying obvious fixes
4. **Version/breaking changes suspected** - Your approach should work but doesn't
5. **User explicitly requests** - "Look up the current docs for X"
6. **Rapidly evolving tool** - Known to change frequently (new frameworks, APIs)

### DO NOT research when:
- You're reasonably confident in the approach
- An existing skill covers the topic
- It's fundamental knowledge (loops, basic syntax, common patterns)
- You just want to "double-check" (try first instead)
- The user provided documentation already

### Ask yourself before researching:
> "Have I actually tried something that failed, or am I just being cautious?"

If you haven't tried yet, **try first**.

---

## Research Workflow

### Step 1: Identify the Specific Gap

After hitting a wall, be specific:
- What exactly failed?
- What error message did I get?
- What specific piece of information am I missing?

**Bad:** "Let me research how to set up Express"
**Good:** "My Express route returns 404 - let me search for this specific issue"

### Step 2: Craft Targeted Queries

| Situation | Query Pattern | Example |
|-----------|---------------|---------|
| Error fix | `"{exact error}" {tool}` | `"ENOENT" npm install` |
| Unexpected behavior | `{tool} {thing} not working` | `vite hmr not working docker` |
| Specific feature | `{tool} {feature} docs` | `prisma cascade delete docs` |
| Version-specific | `{tool} {version} {issue}` | `react 19 useEffect changes` |

### Step 3: Execute Search

```
WebSearch: {targeted query}
```

For specific doc pages:
```
WebFetch: {url} - Extract {specific info needed}
```

### Step 4: Apply and Continue

1. Apply the fix to your failed attempt
2. Mention what you found briefly
3. Continue with the solution

---

## Examples

### Example 1: Appropriate Research (After Failure)
```
User: Set up a Deno server with KV

Claude: [Tries Deno.serve with kv.get/set]
        [Gets error: "kv is not defined"]

Claude: I'm getting an error with KV. Let me look up the current syntax.
        [WebSearch: deno kv openKv example 2025]

Claude: Found it - need to use Deno.openKv() first. [Fixes and continues]
```

### Example 2: Inappropriate Research (Should Try First)
```
User: Create a Python function to reverse a string

Claude: [DON'T research this - just write it]
        def reverse_string(s):
            return s[::-1]
```

### Example 3: Appropriate Research (Genuinely Unfamiliar)
```
User: Set up Turso database with Drizzle ORM

Claude: I haven't worked with Turso before.
        [WebSearch: turso drizzle orm setup 2025]
        [This is appropriate - genuinely unfamiliar tool]
```

---

## Search Strategies by Situation

### After an Error
```
1. Search the exact error message (quoted)
2. Add the tool/framework name
3. Add version if relevant
```

### Feature Not Working as Expected
```
1. Search: "{tool} {feature} not working"
2. Check GitHub issues
3. Look for version-specific changes
```

### Need Current Syntax/API
```
1. Search: "{tool} {feature} documentation {year}"
2. Prefer official docs
3. WebFetch the specific page
```

---

## Communicating Research

Be brief - don't over-explain:

**Good:** "That didn't work. I looked it up - turns out you need the `--unstable-kv` flag."

**Too verbose:** "I wasn't sure about the exact approach, so I decided to research this topic to ensure I provide you with accurate and up-to-date information. According to my research..."

---

## Important Notes

- **Try first, research second** - This saves context and is often faster
- **Be specific** - Research the exact gap, not the whole topic
- **Existing skills first** - Check if a skill already covers this
- **Brief citations** - Mention sources without lengthy explanations
- **Don't research basics** - If you know it, just do it
