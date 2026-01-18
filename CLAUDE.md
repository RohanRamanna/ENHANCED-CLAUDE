# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status: ✅ COMPLETE & TESTED

**Implementation**: Fully functional RLM system using Claude Code's native tools.

**Verified**: Successfully processed 33-page RLM paper (88,750 chars → 5 chunks → parallel subagent processing → synthesized answer).

**Key Results from Test**:
| Metric | Value |
|--------|-------|
| Input size | 88,750 characters |
| Chunks created | 5 (~20K chars each) |
| Subagents spawned | 5 (parallel) |
| Processing | Successful |
| Output | Comprehensive paper synthesis |

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
├── CLAUDE.md                 # This file
├── rlm_tools/
│   ├── probe.py              # Analyze input structure
│   ├── chunk.py              # Split large files
│   ├── aggregate.py          # Combine results
│   └── sandbox.py            # Safe code execution
├── rlm_context/              # Working directory for RLM ops
│   ├── chunks/               # Chunked input files
│   └── results/              # Subagent processing results
├── docs/
│   └── rlm_paper_notes.md    # Paper analysis & implementation details
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
