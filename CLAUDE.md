# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Two Systems for Persistent Memory

This repository provides **two complementary systems**:

| System | Problem Solved | When to Use |
|--------|---------------|-------------|
| **Session Persistence** | Memory loss during context compaction | Always - read these files when resuming |
| **RLM (Large Documents)** | Documents too large for context window | When input exceeds ~100K tokens |

---

## System 1: Session Persistence Files

**Purpose**: Maintain continuity across context compaction.

### Files to Check When Resuming

| File | Purpose | Action |
|------|---------|--------|
| `context.md` | Current goal & key decisions | Read first to understand what we're doing |
| `todos.md` | Task progress tracking | Check what's done, what's pending |
| `insights.md` | Accumulated learnings | Reference for patterns & gotchas |

### How to Use

**When starting a task**:
1. Update `context.md` with the goal
2. Add tasks to `todos.md`

**During work**:
1. Mark todos complete as you go
2. Add discoveries to `insights.md`

**After context compaction**:
1. Read all 3 files to recover state
2. Continue from where you left off

---

## System 2: RLM for Large Documents

**Purpose**: Process documents that exceed context window.

**Verified**: Successfully processed 8-book corpus (4.86M chars, ~1.2M tokens, 6x context window).

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
│   ├── HOW_TO_USE.md         # Step-by-step RLM guide
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
