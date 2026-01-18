# How to Use Enhanced Claude

This repository provides **four integrated systems** for Claude Code. This guide covers all of them.

---

## Table of Contents

1. [Session Persistence](#system-1-session-persistence) - Memory across context compaction
2. [RLM for Large Documents](#system-2-rlm-for-large-documents) - Processing oversized inputs
3. [Auto-Skills](#system-3-auto-skills) - Self-improving skill system
4. [Skills Library](#system-4-skills-library) - On-demand skill loading
5. [Prerequisites](#prerequisites)
6. [Quick Start](#quick-start)
7. [Detailed Workflow](#detailed-workflow)
8. [Tool Reference](#tool-reference)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)

---

## System 1: Session Persistence

**Problem**: When Claude's context window fills up, it compacts and loses memory of what you were working on.

**Solution**: Three markdown files that Claude reads when resuming to recover full state.

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
│  1. Read context.md    → What are we doing?                     │
│  2. Read todos.md      → What's done? What's pending?           │
│  3. Read insights.md   → What patterns should I remember?       │
│                                                                 │
│  DURING WORK:                                                   │
│  • Complete a task     → Mark [x] in todos.md                   │
│  • Make a decision     → Document in context.md                 │
│  • Learn something     → Add to insights.md                     │
│                                                                 │
│  ON TASK COMPLETION:                                            │
│  • Update all 3 files with final state                          │
│  • Commit changes to git                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Example: context.md

```markdown
# Context

## Current Goal
Implement user authentication for the API

## Key Decisions Made
1. Using JWT tokens (not sessions) - better for stateless APIs
2. Storing refresh tokens in Redis - fast expiration handling

## Important Files
| File | Purpose |
|------|---------|
| `auth/middleware.py` | JWT validation |
| `auth/tokens.py` | Token generation |

## Notes for Future Self
- The JWT secret is in environment variables
- Redis connection pool size is set to 10
```

### Example: todos.md

```markdown
# Todos

## In Progress
- [ ] Create auth middleware

## Pending
- [ ] Add rate limiting
- [ ] Write integration tests

## Completed (This Session)
### Phase 1: Setup
- [x] Set up JWT library
- [x] Create user model
- [x] Configure Redis connection
```

### Example: insights.md

```markdown
# Insights

## Key Learnings
### JWT Best Practices
- Refresh tokens should be rotated on each use
- Access tokens should be short-lived (15 min)
- Store refresh tokens in Redis with TTL

## Patterns Identified
- Use middleware for auth, not decorators
- Connection pooling is essential for Redis

## Gotchas & Pitfalls
- Don't store JWT secret in code - use env vars
- Redis connections timeout after 30s of inactivity
```

### Recovery After Compaction

When context compacts, Claude automatically:
1. Reads all 3 persistence files
2. Understands current goal and progress
3. Continues seamlessly where it left off

---

## System 3: Auto-Skills

**Problem**: Claude solves the same problems repeatedly without remembering solutions.

**Solution**: A self-improving skill system that automatically matches, tracks, learns, and improves.

### How Auto-Skills Work

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTO-SKILLS LOOP                              │
├─────────────────────────────────────────────────────────────────┤
│ 1. SKILL MATCHING (every request)                               │
│    → Score each skill against user request                      │
│    → Load skill if score ≥ 10                                   │
│                                                                 │
│ 2. SKILL TRACKING (after using skill)                           │
│    → useCount++, lastUsed = today                               │
│    → On success: successCount++                                 │
│    → On failure: failureCount++                                 │
│                                                                 │
│ 3. AUTO-LEARNING (after solving without skill)                  │
│    → If 2+ attempts were needed (trial-and-error)               │
│    → Offer to save as new skill                                 │
│                                                                 │
│ 4. AUTO-IMPROVEMENT (after skill usage)                         │
│    → If workaround was needed → update skill                    │
│    → If enhancement found → suggest improvement                 │
└─────────────────────────────────────────────────────────────────┘
```

### Skill Matching Algorithm

| Match Type | Points |
|------------|--------|
| Exact tag match | +3 |
| Category match | +5 |
| Summary keyword | +2 |
| Description keyword | +1 |
| Recent use (< 7 days) | +1 |
| High success rate (> 80%) | +2 |

**Thresholds**: ≥10 = load immediately, 5-9 = mention as option, <5 = no match

---

## System 4: Skills Library

**Problem**: Useful patterns and workflows are forgotten between sessions.

**Solution**: 15 reusable skills loaded on-demand.

### Available Skills

| Category | Skills |
|----------|--------|
| **Meta** (9) | skill-index, skill-matcher, skill-loader, skill-tracker, skill-creator, skill-updater, skill-improver, skill-validator, skill-health |
| **Setup** (2) | deno2-http-kv-server, hono-bun-sqlite-api |
| **API** (1) | llm-api-tool-use |
| **Utility** (1) | markdown-to-pdf |
| **Workflow** (1) | udcp |
| **Fallback** (1) | web-research |

### How to Use Skills

```bash
# Invoke a skill directly
/skill-name

# Or let auto-matching find the right skill
# Just describe what you want and the system matches automatically
```

---

## System 2: RLM for Large Documents

**Problem**: Documents larger than ~200K tokens cannot fit in Claude's context window.

**Solution**: Chunk the document, process with parallel subagents, aggregate results.

---

## Prerequisites

### Required
- **Claude Code** (CLI) - The RLM system uses Claude Code's native tools
- **Python 3.8+** - For running the RLM tools

### Optional
- `pdfplumber` - For PDF text extraction (`pip install pdfplumber`)
- `RestrictedPython` - For safe code execution (`pip install RestrictedPython`)

Install all optional dependencies:
```bash
pip install -r requirements.txt
```

---

## Quick Start

### The 30-Second Version

Got a large document? Here's the fastest path:

```bash
# 1. Extract text (if PDF)
python -c "import pdfplumber; print(pdfplumber.open('doc.pdf').pages[0].extract_text()[:100])"

# 2. Probe it
python rlm_tools/probe.py your_document.txt

# 3. Chunk it
python rlm_tools/chunk.py your_document.txt --output rlm_context/chunks/

# 4. Ask Claude Code to process with Task subagents

# 5. Aggregate results
python rlm_tools/aggregate.py rlm_context/results/
```

---

## Detailed Workflow

### Step 1: Prepare Your Input

**For text files**: Copy or move to the working directory
```bash
cp /path/to/large_document.txt rlm_context/input.txt
```

**For PDFs**: Extract text first
```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    text = "\n\n".join(page.extract_text() or "" for page in pdf.pages)

with open("rlm_context/input.txt", "w") as f:
    f.write(text)
```

### Step 2: Probe the Structure

Analyze your input to understand its size and get chunking recommendations:

```bash
python rlm_tools/probe.py rlm_context/input.txt
```

**Example output**:
```
=== File Analysis ===
File: rlm_context/input.txt
Size: 88,750 characters
Lines: 1,247
Estimated tokens: ~22,187

Format detected: text
Recommended strategy: size
Recommended chunks: 5 (at 20,000 chars each)
```

**Options**:
```bash
# JSON output for programmatic use
python rlm_tools/probe.py input.txt --json

# Analyze multiple files
python rlm_tools/probe.py file1.txt file2.txt file3.txt
```

### Step 3: Chunk the Input

Split the large input into processable pieces:

```bash
python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
```

**Example output**:
```
Chunking: rlm_context/input.txt
Strategy: size (20000 chars, 500 overlap)
Output directory: rlm_context/chunks/

Created 5 chunks:
  chunk_001.txt: 20,035 chars (lines 1-293)
  chunk_002.txt: 20,086 chars (lines 287-574)
  chunk_003.txt: 20,018 chars (lines 568-858)
  chunk_004.txt: 20,074 chars (lines 852-1211)
  chunk_005.txt: 10,537 chars (lines 1205-1247)

Manifest written to: rlm_context/chunks/manifest.json
```

**Chunking options**:
```bash
# Custom chunk size
python rlm_tools/chunk.py input.txt --size 100000

# Different strategies
python rlm_tools/chunk.py input.txt --strategy headers    # Split by markdown headers
python rlm_tools/chunk.py input.txt --strategy paragraphs # Split by paragraphs
python rlm_tools/chunk.py input.txt --strategy lines      # Split by line count

# Custom overlap (for context continuity)
python rlm_tools/chunk.py input.txt --overlap 1000
```

### Step 4: Process with Task Subagents

This is where the magic happens. In Claude Code, spawn Task subagents to process each chunk **in parallel**:

**Tell Claude Code**:
```
Process these chunks with Task subagents. For each chunk, extract [YOUR QUERY HERE]
and save results to rlm_context/results/
```

**What Claude Code does internally**:
```python
# Spawns multiple Task subagents in parallel:
Task(subagent_type="general-purpose", prompt="""
  Read rlm_context/chunks/chunk_001.txt
  Answer: What are the key findings about X?
  Save your analysis to rlm_context/results/chunk_001.result.txt
""")

Task(subagent_type="general-purpose", prompt="""
  Read rlm_context/chunks/chunk_002.txt
  Answer: What are the key findings about X?
  Save your analysis to rlm_context/results/chunk_002.result.txt
""")
# ... etc for all chunks
```

**Pro tip**: Claude Code can run 3-5 subagents in parallel for faster processing.

### Step 5: Aggregate Results

Combine all chunk results into a final synthesized answer:

```bash
python rlm_tools/aggregate.py rlm_context/results/
```

**Example output**:
```
=== Aggregated Results ===
Processed 5 result files

Combined output written to: rlm_context/aggregated_results.txt
```

**Aggregation options**:
```bash
# Include original query for context
python rlm_tools/aggregate.py results/ --query "What are the security vulnerabilities?"

# Different output formats
python rlm_tools/aggregate.py results/ --format json
python rlm_tools/aggregate.py results/ --format summary

# Save to specific file
python rlm_tools/aggregate.py results/ --output final_answer.txt
```

### Step 6: Get Your Answer

Read the aggregated results and Claude Code will synthesize the final answer:

```bash
cat rlm_context/aggregated_results.txt
```

Or simply ask Claude Code to read and summarize the aggregated results.

---

## Tool Reference

### probe.py

| Flag | Description | Default |
|------|-------------|---------|
| `<file>` | File(s) to analyze | Required |
| `--json` | Output in JSON format | False |

### chunk.py

| Flag | Description | Default |
|------|-------------|---------|
| `<file>` | File to chunk | Required |
| `--size` | Chunk size in characters | 200,000 |
| `--strategy` | `size`, `lines`, `headers`, `paragraphs` | `size` |
| `--output` | Output directory | `./chunks/` |
| `--overlap` | Character overlap between chunks | 500 |

### aggregate.py

| Flag | Description | Default |
|------|-------------|---------|
| `<dir>` | Results directory | Required |
| `--query` | Original query for context | None |
| `--format` | `text`, `json`, `summary` | `text` |
| `--output` | Output file path | `aggregated_results.txt` |
| `--pattern` | File pattern to match | `*.txt` |

### sandbox.py

| Flag | Description | Default |
|------|-------------|---------|
| `--code` | Python code to execute | None |
| `--file` | Python file to execute | None |
| `--context` | Context string | None |
| `--context-file` | File containing context | None |

---

## Examples

### Example 1: Analyzing a Research Paper

**Goal**: Extract all methodology details from a 50-page paper

```bash
# 1. Extract PDF text
python -c "
import pdfplumber
with pdfplumber.open('paper.pdf') as pdf:
    text = '\n'.join(p.extract_text() or '' for p in pdf.pages)
open('rlm_context/input.txt', 'w').write(text)
"

# 2. Probe
python rlm_tools/probe.py rlm_context/input.txt
# Output: 150,000 chars, recommends 8 chunks

# 3. Chunk
python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/

# 4. Tell Claude Code:
# "Process each chunk to extract methodology details, save to results/"

# 5. Aggregate
python rlm_tools/aggregate.py rlm_context/results/ --query "methodology details"
```

### Example 2: Code Repository Analysis

**Goal**: Find all API endpoints in a large codebase

```bash
# 1. Concatenate all relevant files
find ./src -name "*.py" -exec cat {} \; > rlm_context/input.txt

# 2. Probe
python rlm_tools/probe.py rlm_context/input.txt

# 3. Chunk by size (code doesn't have headers)
python rlm_tools/chunk.py rlm_context/input.txt --size 150000

# 4. Tell Claude Code:
# "Find all API endpoints (routes, handlers) in each chunk"

# 5. Aggregate
python rlm_tools/aggregate.py rlm_context/results/ --query "API endpoints"
```

### Example 3: Legal Document Review

**Goal**: Extract all obligations and deadlines from a 200-page contract

```bash
# 1. Prepare (assuming text already extracted)
cp contract.txt rlm_context/input.txt

# 2. Probe
python rlm_tools/probe.py rlm_context/input.txt
# Output: 500,000 chars, recommends 25 chunks

# 3. Chunk with more overlap for legal continuity
python rlm_tools/chunk.py rlm_context/input.txt --overlap 2000

# 4. Tell Claude Code:
# "Extract all obligations, deadlines, and penalties from each chunk"

# 5. Aggregate with JSON for structured output
python rlm_tools/aggregate.py rlm_context/results/ --format json
```

---

## Troubleshooting

### "File too large to read"

**Solution**: That's exactly what this system is for! Use the chunking workflow.

### Chunks are too small/large

**Solution**: Adjust the `--size` parameter:
```bash
# Larger chunks (fewer subagent calls, but may hit limits)
python rlm_tools/chunk.py input.txt --size 300000

# Smaller chunks (more calls, but safer)
python rlm_tools/chunk.py input.txt --size 100000
```

### Missing context between chunks

**Solution**: Increase overlap:
```bash
python rlm_tools/chunk.py input.txt --overlap 2000
```

### PDF extraction fails

**Solution**: Install pdfplumber or try alternative:
```bash
pip install pdfplumber

# Or use pdftotext (if available)
pdftotext document.pdf rlm_context/input.txt
```

### Results are inconsistent across chunks

**Solution**: Make your query more specific when processing:
```
"Extract ONLY mentions of [specific term]. Include page/line references."
```

### Out of memory

**Solution**: Process fewer chunks in parallel (2-3 instead of 5).

---

## Best Practices

1. **Always probe first** - Know your input before chunking
2. **Use appropriate overlap** - 500 chars for general text, 1000+ for technical/legal
3. **Be specific in queries** - "Find X" is better than "Analyze everything"
4. **Process in parallel** - Claude Code can handle 3-5 subagents simultaneously
5. **Check manifest.json** - Track what's been processed if interrupted
6. **Clean up after** - Remove `rlm_context/chunks/` and `results/` when done

---

## How It Works (Technical)

The RLM system implements the Recursive Language Model paradigm from MIT CSAIL:

```
┌─────────────────────────────────────────────────────────┐
│                    ROOT LM (Claude Code)                │
│                                                         │
│  1. Receive large input                                 │
│  2. Probe → understand structure                        │
│  3. Chunk → split into pieces                          │
│  4. Delegate → spawn Task subagents                    │
│                                                         │
│     ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│     │ Sub-LM 1 │  │ Sub-LM 2 │  │ Sub-LM 3 │  ...     │
│     │ chunk_1  │  │ chunk_2  │  │ chunk_3  │          │
│     └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│          │             │             │                 │
│          ▼             ▼             ▼                 │
│     ┌──────────────────────────────────────┐          │
│     │         Results on Filesystem         │          │
│     └──────────────────────────────────────┘          │
│                        │                               │
│  5. Aggregate ← combine results                       │
│  6. Synthesize → final answer                         │
└─────────────────────────────────────────────────────────┘
```

This achieves **O(log n)** cost scaling while maintaining accuracy on documents that would otherwise exceed context limits.

---

## Need Help?

- Check `CLAUDE.md` for Claude Code-specific guidance
- Read `docs/rlm_paper_notes.md` for theoretical background
- Original paper: [arXiv:2512.24601](https://arxiv.org/abs/2512.24601)
