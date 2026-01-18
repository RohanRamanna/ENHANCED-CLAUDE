# Persistent Memory RLM

**Recursive Language Models for Lossless Infinite Context in Claude Code**

[![Status](https://img.shields.io/badge/status-complete-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

## Overview

This repository implements the **Recursive Language Model (RLM)** methodology from MIT CSAIL's paper [arXiv:2512.24601v1](https://arxiv.org/abs/2512.24601) to give Claude Code **lossless infinite context** without requiring external API keys.

### Key Insight

Claude Code's native tools map directly to the RLM architecture:

| Paper Component | Claude Code Equivalent |
|-----------------|----------------------|
| Root LM | Main conversation |
| Sub-LM (`llm_query`) | Task tool with subagents |
| REPL Environment | Bash tool + filesystem |
| `context` variable | Files on disk |

**No Anthropic API key needed** - just use Claude Code's built-in capabilities.

## Two Systems for Persistent Memory

| System | Problem Solved | Files |
|--------|---------------|-------|
| **Session Persistence** | Memory loss during context compaction | `context.md`, `todos.md`, `insights.md` |
| **RLM (Large Documents)** | Documents too large for context window | `rlm_tools/*` |

## Quick Start

### Session Persistence (Always Use)

When context compacts, Claude reads these files to recover state:
- `context.md` - Current goal & key decisions
- `todos.md` - Task progress tracking
- `insights.md` - Accumulated learnings

### Processing Large Documents (RLM)

```bash
# 1. Probe structure
python rlm_tools/probe.py your_document.txt

# 2. Chunk into processable pieces
python rlm_tools/chunk.py your_document.txt --size 200000 --output rlm_context/chunks/

# 3. Process with Claude Code Task subagents (in parallel)
# 4. Aggregate results
python rlm_tools/aggregate.py rlm_context/results/ --query "Your question"
```

## Verified Results

### Test 1: RLM Paper (Baseline)
| Metric | Value |
|--------|-------|
| Input size | 88,750 characters |
| Chunks | 5 |
| Result | Comprehensive paper synthesis |

### Test 2: 8-Book Literary Corpus
| Metric | Value |
|--------|-------|
| Corpus | 8 classic novels (Austen, Dickens, Melville, Shelley, etc.) |
| Input size | **4,861,186 characters (~1.2M tokens)** |
| Context overflow | **6x larger than context window** |
| Chunks | 24 |
| Query | "Find all character deaths across all books" |
| Result | **Verified correct** - deaths confirmed via grep at exact line numbers |

### Test 3: FastAPI Codebase (Code Analysis)
| Metric | Value |
|--------|-------|
| Codebase | FastAPI Python framework (1,252 files) |
| Input size | **3,680,132 characters (~920K tokens)** |
| Context overflow | **4.6x larger than context window** |
| Chunks | 19 |
| Query | "Find all security-related code" |
| Result | **Verified correct** - 8 security classes confirmed via grep |

**Key finding**: RLM works on **both prose AND code** at scale.

See [docs/VERIFIED_TEST_RESULTS.md](docs/VERIFIED_TEST_RESULTS.md) for full verification details.

## Repository Structure

```
.
├── CLAUDE.md              # Claude Code guidance (read first)
├── context.md             # Session persistence: current goal
├── todos.md               # Session persistence: task tracking
├── insights.md            # Session persistence: accumulated learnings
├── rlm_tools/
│   ├── probe.py           # Analyze input structure
│   ├── chunk.py           # Split large files
│   ├── aggregate.py       # Combine results
│   └── sandbox.py         # Safe code execution
├── rlm_context/           # Working directory for RLM ops
├── docs/
│   ├── 2512.24601v1.pdf        # Original RLM paper
│   ├── rlm_paper_notes.md      # Detailed paper analysis
│   ├── HOW_TO_USE.md           # Step-by-step usage guide
│   └── VERIFIED_TEST_RESULTS.md # Test verification with grep proof
└── requirements.txt       # Python dependencies
```

## How It Works

1. **Probe**: Analyze input structure (size, format, recommended chunking)
2. **Chunk**: Split large inputs into ~200K character pieces with overlap
3. **Process**: Spawn Claude Code Task subagents to process chunks in parallel
4. **Aggregate**: Combine all chunk results into final synthesized answer

This achieves the paper's goal of **O(log n)** cost scaling while maintaining **perfect accuracy** on tasks that would otherwise exceed context limits.

## Reference

```bibtex
@article{zhang2025rlm,
  title={Recursive Language Models},
  author={Zhang, Alex L. and Kraska, Tim and Khattab, Omar},
  journal={arXiv preprint arXiv:2512.24601},
  year={2025}
}
```

## License

MIT
