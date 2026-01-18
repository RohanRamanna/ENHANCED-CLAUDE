---
name: udcp
description: Update documentation, commit, and push in one command. Sync skill changes from ~/.claude/skills to repo, update documentation, commit, and push. Use when invoking /udcp or after making skill changes that need to be committed.
---

# /udcp - Update Documentation, Commit, Push

## Trigger
When user types `/udcp` or asks to "update docs and commit" or "sync and push changes".

## Workflow

### Step 1: Sync Skills to Repo
Copy any modified skills from `~/.claude/skills/` to the repo's `skills/` directory:

```bash
# For each modified skill, sync to repo
cp ~/.claude/skills/{skill-name}/SKILL.md "skills/{skill-name}/SKILL.md"
cp ~/.claude/skills/{skill-name}/metadata.json "skills/{skill-name}/metadata.json"
```

### Step 2: Check What Changed
```bash
git status
git diff --stat
```

### Step 3: Update Documentation (if needed)
Review and update these files if skill changes affect them:
- `README.md` - Update if new skills added or architecture changed
- `CLAUDE.md` - Update if workflows or commands changed
- `plan.md` - Update status if implementation milestones reached

### Step 4: Stage and Commit
```bash
git add -A
git commit -m "$(cat <<'EOF'
{Descriptive commit message}

{Summary of changes}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 5: Push
```bash
git push
```

### Step 6: Confirm
Report back:
- What was synced
- What was committed
- Push status

## Example Usage

**User:** `/udcp`

**Claude:**
1. Syncing skills to repo...
   - skill-loader (modified)
   - skill-updater (modified)
2. Checking documentation...
   - README.md: No changes needed
   - plan.md: No changes needed
3. Committing: "Update skill-loader and skill-updater with deviation detection"
4. Pushed to origin/main

Done! Changes are live.

## Quick Mode

If user says `/udcp quick` or `/udcp -q`, skip documentation review and just:
1. Sync modified skills
2. Auto-generate commit message from changes
3. Commit and push

## Important Notes

- Always check `git status` before committing
- Never force push
- Include Co-Authored-By in commit messages
- If no changes detected, report "Nothing to commit"
