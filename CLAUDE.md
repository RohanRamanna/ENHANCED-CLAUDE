# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Enhanced Claude: Self-Improving AI

This repository transforms Claude into an **Enhanced Claude** with four integrated systems:

| System | Problem Solved | Behavior |
|--------|---------------|----------|
| **Session Persistence** | Memory loss during context compaction | Read files when resuming |
| **RLM (Large Documents)** | Documents too large for context window | Chunk and delegate |
| **Auto-Skills** | Repetitive problem-solving | **Automatic** matching, learning, improvement |
| **Skills Library** | Reusable patterns and workflows | On-demand loading |

---

## CRITICAL: Enhanced Claude Protocol

**This protocol runs AUTOMATICALLY on every interaction.**

### On Every User Request

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENHANCED CLAUDE LOOP                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. SKILL MATCHING (automatic)                                   │
│    → Read skills/skill-index/index.json                         │
│    → Score each skill against user request                      │
│    → If score ≥ 10: Load and apply the skill                    │
│    → If score < 5: Proceed without skill (may trigger learning) │
│                                                                 │
│ 2. SKILL TRACKING (after using any skill)                       │
│    → Update metadata.json: useCount++, lastUsed = today         │
│    → On success: successCount++                                 │
│    → On failure: failureCount++, trigger skill-updater          │
│                                                                 │
│ 3. AUTO-LEARNING (after solving without a skill)                │
│    → If trial-and-error was needed (2+ attempts)                │
│    → If non-obvious solution discovered                         │
│    → Offer to save as new skill (skill-creator)                 │
│                                                                 │
│ 4. AUTO-IMPROVEMENT (after skill usage)                         │
│    → If workaround was needed: suggest skill-updater            │
│    → If enhancement discovered: suggest skill-improver          │
└─────────────────────────────────────────────────────────────────┘
```

### Skill Matching Algorithm

When a user makes a request, score each skill:

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 |
| Category match | +5 |
| Summary keyword match | +2 |
| Description keyword match | +1 |
| Recent use bonus (< 7 days) | +1 |
| High success rate (> 80%) | +2 |

**Thresholds:**
- Score ≥ 10: Strong match → Load skill immediately
- Score 5-9: Possible match → Mention as option
- Score < 5: No match → Proceed without skill

### Auto-Learning Triggers

Offer to create a new skill when:
1. ✅ Solved after 2+ attempts (trial-and-error)
2. ✅ Found non-obvious solution (not in docs)
3. ✅ Solution requires 3+ specific steps
4. ✅ Discovered gotchas/edge cases

Do NOT offer when:
- ❌ Solution was straightforward (1 attempt)
- ❌ Issue was user-specific (wrong path, typo)
- ❌ Solution is trivial (< 2 steps)

### Auto-Improvement Triggers

After using a skill, check:
1. Did I deviate from documented steps? → skill-updater
2. Did I discover additional useful info? → skill-improver
3. Did the skill fail? → skill-updater + failureCount++
4. Is another skill very similar? → suggest merge

---

## System 1: Session Persistence Files

**Purpose**: Maintain continuity across context compaction.

**Problem**: When context compacts during long sessions, Claude loses memory of what was being worked on.

**Solution**: Three markdown files that persist state to disk.

### The Three Files

| File | Purpose | When to Update |
|------|---------|----------------|
| `context.md` | Current goal, key decisions, important files | At task start, after major decisions |
| `todos.md` | Task progress tracking with phases | When starting/completing tasks |
| `insights.md` | Accumulated learnings & patterns | When discovering something reusable |

### Session Persistence Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  SESSION PERSISTENCE PROTOCOL                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ON SESSION START / AFTER COMPACTION:                           │
│  ─────────────────────────────────────                          │
│  1. Read context.md    → What are we doing?                     │
│  2. Read todos.md      → What's done? What's pending?           │
│  3. Read insights.md   → What patterns should I remember?       │
│                                                                 │
│  DURING WORK:                                                   │
│  ───────────                                                    │
│  • Complete a task     → Mark [x] in todos.md                   │
│  • Make a decision     → Document in context.md                 │
│  • Learn something     → Add to insights.md                     │
│  • Start new phase     → Add phase header in todos.md           │
│                                                                 │
│  ON TASK COMPLETION:                                            │
│  ──────────────────                                             │
│  • Update all 3 files with final state                          │
│  • Commit changes to git                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### File Structures

**context.md** - Current State
```markdown
# Context
## Current Goal
[1-2 sentences on what we're trying to accomplish]

## Key Decisions Made
1. [Decision and reasoning]

## Important Files
| File | Purpose |
|------|---------|
| `path/file.py` | [What it does] |

## Notes for Future Self
- [Critical context that might be lost]
```

**todos.md** - Progress Tracking
```markdown
# Todos
## In Progress
- [ ] [Current task being worked on]

## Pending
- [ ] [Next task]

## Completed (This Session)
### Phase 1: [Phase Name]
- [x] [Completed task with brief note]
```

**insights.md** - Institutional Knowledge
```markdown
# Insights
## Key Learnings
### [Topic]
[What was learned and why it matters]

## Patterns Identified
- [Pattern]: [When to use it]

## Gotchas & Pitfalls
- [Mistake to avoid]: [Why]
```

### Recovery Example

After context compaction:
```bash
# Claude automatically reads these files:
Read context.md   # "We're implementing Enhanced Claude..."
Read todos.md     # "Phase 7 complete, no pending tasks..."
Read insights.md  # "Auto-skills use scoring algorithm..."

# Then continues seamlessly with full context
```

---

## System 2: RLM for Large Documents

**Purpose**: Process documents that exceed context window.

**Verified on**:
| Test | Type | Size | Overflow | Result |
|------|------|------|----------|--------|
| 8-Book Corpus | Literature | 4.86M chars (~1.2M tokens) | 6x | ✅ Deaths verified via grep |
| FastAPI Codebase | Python (1,252 files) | 3.68M chars (~920K tokens) | 4.6x | ✅ Security classes verified via grep |

**Works on both prose AND code.**

---

## System 3: Skills Library

**Purpose**: Reusable patterns, workflows, and specialized capabilities.

### Available Skills

| Skill | Purpose |
|-------|---------|
| `skill-index` | Index and discover available skills |
| `skill-creator` | Auto-detect learning moments and create skills |
| `skill-matcher` | Find best matching skill for a request |
| `web-research` | Fallback research when stuck |
| `markdown-to-pdf` | Convert markdown to PDF |
| `llm-api-tool-use` | Claude API tool use patterns |
| `udcp` | Update docs, commit, push workflow |
| + more... | See `skills/SKILLS_GUIDE.md` |

### How to Use

```bash
# Invoke a skill
/skill-name

# Or use the Skill tool
Skill(skill="skill-name")
```

---

## Project Purpose

This repository implements **Recursive Language Models (RLMs)** - a technique from MIT CSAIL (arXiv:2512.24601v1) that enables **lossless infinite context** for Claude without external API keys.

**Key Insight**: Claude Code's existing tools map directly to RLM architecture:

| Paper Component | Claude Code Equivalent |
|-----------------|----------------------|
| Root LM | Main conversation (you) |
| Sub-LM (llm_query) | **Task tool with subagents** |
| REPL Environment | **Bash tool + filesystem** |
| context variable | **Files on disk** |

---

## RLM Protocol for Infinite Context

When handling inputs that exceed comfortable context (>100K tokens), use this workflow:

### Step 1: Load & Probe
```bash
# Save large input to working directory
# Then analyze structure:
python rlm_tools/probe.py rlm_context/input.txt
```
Output tells you: character count, line count, format type, recommended chunking strategy.

### Step 2: Chunk
```bash
# Split into processable pieces (~200K chars each)
python rlm_tools/chunk.py rlm_context/input.txt --size 200000 --output rlm_context/chunks/
```
Creates `chunks/chunk_001.txt`, `chunk_002.txt`, etc. plus `manifest.json`.

### Step 3: Process with Task Subagents
Spawn parallel Task subagents to process each chunk:
```
Task(subagent_type="general-purpose", prompt="
  Read rlm_context/chunks/chunk_001.txt and answer: [QUERY]
  Save your findings to rlm_context/results/chunk_001.result.txt
")
```

Run 3-4 subagents in parallel for efficiency.

### Step 4: Aggregate Results
```bash
python rlm_tools/aggregate.py rlm_context/results/ --query "Original query here"
```
Combines all chunk results into synthesized output.

### Step 5: Final Answer
Read aggregated results and provide final answer to user.

---

## RLM Tools Reference

### `rlm_tools/probe.py` - Structure Analyzer
```bash
python rlm_tools/probe.py <file>           # Analyze file structure
python rlm_tools/probe.py file.txt --json  # JSON output
```

### `rlm_tools/chunk.py` - Chunking Utility
```bash
python rlm_tools/chunk.py <file> [options]
  --size 200000        # Chunk size in chars (default: 200000)
  --strategy size|lines|headers|paragraphs
  --output <dir>       # Output directory
  --overlap 500        # Character overlap between chunks
```

### `rlm_tools/aggregate.py` - Result Aggregation
```bash
python rlm_tools/aggregate.py <results_dir> [options]
  --query "..."        # Original query for context
  --format text|json|summary
  --output <file>      # Save to file
```

### `rlm_tools/sandbox.py` - Safe Code Execution
```bash
python rlm_tools/sandbox.py --code "print(len(context))" --context "Hello"
python rlm_tools/sandbox.py --file script.py --context-file input.txt
```
Uses RestrictedPython for safe evaluation.

---

## Directory Structure

```
PERSISTANT MEMORY/
├── CLAUDE.md                 # This file - read first
├── context.md                # Session persistence: current goal
├── todos.md                  # Session persistence: task tracking
├── insights.md               # Session persistence: accumulated learnings
├── skills/                   # Claude Code skills library
│   ├── SKILLS_GUIDE.md       # How to use and create skills
│   └── */                    # Individual skill folders (16 skills)
├── rlm_tools/
│   ├── probe.py              # Analyze input structure
│   ├── chunk.py              # Split large files
│   ├── aggregate.py          # Combine results
│   └── sandbox.py            # Safe code execution
├── rlm_context/              # Working directory for RLM ops
│   ├── chunks/               # Chunked input files
│   └── results/              # Subagent processing results
├── docs/
│   ├── rlm_paper_notes.md    # Paper analysis & implementation details
│   ├── HOW_TO_USE.md         # Step-by-step guide
│   └── VERIFIED_TEST_RESULTS.md # Test verification proof
└── requirements.txt          # Python dependencies
```

---

## Example: Processing a Large Document

**User**: "Analyze this 500-page PDF and find all security vulnerabilities mentioned"

**Claude (as Root LM)**:

1. **Save and probe**:
   ```bash
   python rlm_tools/probe.py document.txt
   # Output: 2.1M chars, 45K lines, text format, 11 chunks recommended
   ```

2. **Chunk**:
   ```bash
   python rlm_tools/chunk.py document.txt --size 200000 --output rlm_context/chunks/
   # Output: Created 11 chunks
   ```

3. **Spawn subagents** (in parallel):
   ```
   Task(prompt="Read chunks/chunk_001.txt, find security vulnerabilities, save to results/chunk_001.result.txt")
   Task(prompt="Read chunks/chunk_002.txt, find security vulnerabilities, save to results/chunk_002.result.txt")
   Task(prompt="Read chunks/chunk_003.txt, find security vulnerabilities, save to results/chunk_003.result.txt")
   ```

4. **Aggregate**:
   ```bash
   python rlm_tools/aggregate.py rlm_context/results/ --query "security vulnerabilities"
   ```

5. **Return** final synthesized answer to user.

---

## State Recovery After Context Compaction

If context is compacted mid-workflow:
1. Check `rlm_context/` for existing chunks and results
2. Read `rlm_context/chunks/manifest.json` to see progress
3. Continue processing remaining chunks
4. Aggregate when all chunks are processed

---

## Key Implementation Details

- **Chunk size**: ~200K chars (fits in Task subagent context)
- **Parallel subagents**: Max 3-4 concurrent Task calls
- **Overlap**: 500 chars between chunks for context continuity
- **No API key needed**: Uses Claude Code's native Task tool for recursion
