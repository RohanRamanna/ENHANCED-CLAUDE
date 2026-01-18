# Claude Code Skills - Complete Reference

This document explains what Skills are and how to create them. Use this as a reference when the user asks you to create, modify, or work with Skills.

---

## What Are Skills?

Skills are modular, filesystem-based capabilities that extend your functionality. Each Skill is a folder containing a `SKILL.md` file plus optional resources (scripts, templates, reference docs).

**Key difference from slash commands:** Skills are triggered **automatically** based on the user's request matching the skill's description. Slash commands require explicit `/command` invocation.

**Key difference from CLAUDE.md:** CLAUDE.md loads at startup for every conversation. Skills load **on-demand** only when relevant, saving context tokens.

---

## Skill Locations

| Location | Scope | Use Case |
|----------|-------|----------|
| `~/.claude/skills/skill-name/` | Personal | Available in all projects for this user |
| `.claude/skills/skill-name/` | Project | Shared with team via git |

---

## Required Structure

Every Skill must have this minimum structure:

```
skill-name/
└── SKILL.md    # Required
```

### SKILL.md Format

```markdown
---
name: skill-name
description: What this skill does and when you should use it
---

# Skill Title

Instructions, workflows, and guidance go here.
```

### YAML Frontmatter Rules

**Required fields:**

| Field | Rules | Example |
|-------|-------|---------|
| `name` | Max 64 chars, lowercase, letters/numbers/hyphens only, cannot contain "anthropic" or "claude" | `pr-reviewer` |
| `description` | Max 1024 chars, must explain WHAT it does AND WHEN to use it | `Review pull requests for code quality. Use when user asks to review a PR, check code, or mentions code review.` |

**The description is critical** - this is the primary signal you use to determine when to invoke a skill. Write clear, action-oriented descriptions that specify trigger conditions.

**Optional fields:**

| Field | Purpose | Example |
|-------|---------|---------|
| `allowed-tools` | Restrict which tools can be used when skill is active | `Read, Grep, Glob` or `Bash(git:*), Bash(npm:*)` |
| `model` | Specify which model to use for this skill | `claude-3-5-haiku-20241022` |
| `disable-model-invocation` | Prevent programmatic invocation via Skill tool | `true` |
| `argument-hint` | Hint for what argument the skill expects | `[file-path]` or `[message]` |
| `context` | Run in isolated sub-agent context | `fork` |

### allowed-tools Details

Use `allowed-tools` to limit which tools Claude can use when a Skill is active:

```yaml
---
name: code-review
description: Reviews code for best practices
allowed-tools: Read, Grep, Glob
---
```

**Bash with patterns** - Allow specific commands only:
```yaml
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
```

```yaml
allowed-tools: Bash(python:*), Read
```

When `allowed-tools` is set, Claude can only use the specified tools without needing permission. If omitted, the standard permission model applies.

### disable-model-invocation

Prevents the skill from being invoked programmatically:

```yaml
---
name: sensitive-workflow
description: Handles sensitive operations
disable-model-invocation: true
---
```

When `true`:
- Skill cannot be invoked via the Skill tool
- Skill metadata is removed from context
- User must invoke explicitly

### context: fork

Run a skill in an isolated sub-agent context with its own conversation history:

```yaml
---
name: complex-analysis
description: Performs complex multi-step analysis
context: fork
---
```

Useful for skills that perform complex multi-step operations without cluttering the main conversation.

---

## Progressive Disclosure Architecture

Skills use a three-level loading system to minimize context usage:

### Level 1: Metadata (Always Loaded)
- Only `name` and `description` from frontmatter
- ~100 tokens per skill
- Loaded at startup into system prompt
- You see all available skills but not their contents

### Level 2: Instructions (Loaded When Triggered)
- Full SKILL.md body content
- Target: under 5k tokens
- Loaded when you determine the skill is relevant
- Read via: `cat ~/.claude/skills/skill-name/SKILL.md`

### Level 3+: Resources (Loaded As Needed)
- Additional files: reference docs, templates, schemas
- Scripts execute without loading code into context
- Only script OUTPUT enters context, not the code itself
- Effectively unlimited bundled content

---

## Extended Folder Structure

```
skill-name/
├── SKILL.md              # Required - core instructions
├── reference.md          # Optional - detailed documentation
├── examples.md           # Optional - usage examples
├── templates/            # Optional - output templates
│   └── report.md
└── scripts/              # Optional - executable code
    ├── validate.py
    └── process.sh
```

### Referencing Additional Files

In SKILL.md, reference other files that you should read when needed:

```markdown
For form-filling procedures, see [FORMS.md](FORMS.md).
For the complete API reference, see [reference.md](reference.md).
```

When you encounter these references and need that information, read the file:
```bash
cat ~/.claude/skills/skill-name/FORMS.md
```

### Using Scripts

Scripts provide deterministic operations. When SKILL.md instructs you to run a script:

```markdown
## Validation
Run the validation script before submitting:
```bash
python ~/.claude/skills/skill-name/scripts/validate.py "$FILE"
```
```

**Important:** The script code never enters your context. Only the script's output does. This makes scripts extremely efficient for:
- Data validation
- File processing
- Calculations
- API interactions
- Any repeatable operation

---

## Complete SKILL.md Example

```markdown
---
name: pr-reviewer
description: Review pull requests for code quality, security issues, and best practices. Use when user asks to review a PR, check code changes, or mentions code review.
---

# Pull Request Reviewer

You are a code reviewer. Follow these guidelines when reviewing PRs.

## Review Checklist

1. **Code Quality**
   - Clear naming conventions
   - No code duplication
   - Appropriate error handling

2. **Security**
   - No hardcoded secrets
   - Input validation present
   - No SQL injection vulnerabilities

3. **Performance**
   - No N+1 queries
   - Appropriate caching
   - No memory leaks

## Output Format

Provide feedback in this structure:

### Summary
[1-2 sentence overview]

### Issues Found
- **[severity]**: [description] at `file:line`

### Suggestions
- [optional improvements]

## Additional Resources

For security-specific checks, see [security-checklist.md](security-checklist.md).
```

---

## When to Create a Skill vs Other Options

| Need | Solution |
|------|----------|
| Project-specific instructions loaded every time | `CLAUDE.md` |
| Reusable prompt invoked explicitly by user | Slash command (`.claude/commands/`) |
| Capability you should use automatically when relevant | **Skill** |
| One-time task guidance | Just include in the conversation |

---

## Creating a Skill - Step by Step

1. **Identify the capability** - What specific task should this enable?

2. **Create the folder structure:**
   ```bash
   mkdir -p ~/.claude/skills/my-skill
   ```

3. **Write SKILL.md** with:
   - YAML frontmatter (`name`, `description`)
   - Clear instructions
   - Examples if helpful
   - References to additional files if needed

4. **Add supporting files** (optional):
   - Reference documentation
   - Scripts for deterministic operations
   - Templates for output formatting

5. **Test the skill** by asking the user to make a request that should trigger it

---

## Best Practices

### Writing Descriptions
- Be specific about WHAT and WHEN
- Include trigger phrases users might say
- Example: `"Generate database migrations. Use when user mentions migrations, schema changes, database updates, or asks to modify tables."`

### Keeping Context Lean
- Put essential info in SKILL.md (Level 2)
- Put detailed/specialized info in separate files (Level 3)
- If sections are mutually exclusive, keep them in separate files

### Scripts
- Use scripts for any operation that should be deterministic
- Scripts don't consume context (only output does)
- Good for: validation, formatting, calculations, file processing

### Splitting Large Skills
When SKILL.md exceeds ~3k tokens, split into:
- SKILL.md - Core workflow and decision logic
- reference.md - Detailed API/technical docs
- examples.md - Extended examples
- Specialized files for specific scenarios

---

## Skill Invocation Flow

1. User makes a request
2. You check if any skill descriptions match the request
3. If match found, read the skill: `cat ~/.claude/skills/skill-name/SKILL.md`
4. Follow the skill's instructions
5. Read additional files only as needed
6. Execute scripts as instructed

---

## Security Note

Only create and use skills from trusted sources. Skills can:
- Instruct you to run arbitrary code
- Access files on the filesystem
- Make network requests (in Claude Code)

When the user asks you to install a skill from an external source, warn them to audit it first.
