# RLM: Reading Language Model for Large Documents

> **Use when**: Processing documents/codebases larger than ~50K characters, analyzing multiple files at once, or when the large-input-detector hook suggests RLM.

## Quick Start

```bash
# 1. Probe the input (understand structure)
python rlm_tools/probe.py input.txt

# 2. Chunk into processable pieces
python rlm_tools/chunk.py input.txt --output rlm_context/chunks/

# 3. Process chunks with subagents (Claude does this)
# 4. Aggregate results
python rlm_tools/aggregate.py rlm_context/results/
```

## When to Use RLM

| Input Size | Tokens (~) | Action |
|------------|-----------|--------|
| < 50K chars | < 12K | Direct processing (no RLM needed) |
| 50K - 150K chars | 12K - 40K | Consider RLM for complex queries |
| > 150K chars | > 40K | **Use RLM** (exceeds context) |
| > 800K chars | > 200K | **Must use RLM** (impossible otherwise) |

## Automated Workflow

### Step 1: Probe the Input

```bash
python rlm_tools/probe.py <input_file>
```

Output includes:
- Total size (chars, lines, words)
- Estimated tokens
- Recommended chunk count
- Structure analysis

### Step 2: Chunk the Input

```bash
python rlm_tools/chunk.py <input_file> --output rlm_context/chunks/ [options]
```

Options:
| Flag | Default | Description |
|------|---------|-------------|
| `--chunk-size` | 200000 | Characters per chunk |
| `--overlap` | 500 | Overlap between chunks |
| `--by-file` | false | Split by file boundaries (for code) |

### Step 3: Process with Subagents

Use the Task tool to spawn parallel subagents:

```
For each batch of 3-4 chunks:
  Task(subagent_type="general-purpose", prompt="""
    Analyze these chunks for: <query>

    Chunks:
    <chunk contents>

    Return structured findings with:
    - Location (chunk #, line #)
    - Evidence (quotes)
    - Relevance score
  """)
```

**Parallel processing**: Spawn 4-6 subagents simultaneously for speed.

### Step 4: Aggregate Results

```bash
python rlm_tools/aggregate.py rlm_context/results/ [--format json|markdown]
```

Combines all subagent findings, deduplicates, and ranks by relevance.

## Query Design Best Practices

### Good Queries (Specific, Structured)

```
"Find all authentication-related code. For each:
- File path and line number
- Type (OAuth, JWT, Basic, API Key)
- Any security concerns"
```

```
"List all character deaths across all books:
- Character name
- Book title
- Cause of death
- Exact quote describing the death"
```

### Bad Queries (Vague, Unstructured)

```
"Analyze the codebase"  # Too vague
"What's interesting?"   # No structure
"Summarize everything"  # No focus
```

## Chunk Strategy Selection

| Input Type | Strategy | Flag |
|------------|----------|------|
| Plain text | Fixed size | `--strategy size` (default) |
| Markdown docs | By headers | `--strategy headers` |
| Prose/articles | By paragraphs | `--strategy paragraphs` |
| **Code files** | **Semantic (by function/class)** | `--strategy code` |
| Line-based | By line count | `--strategy lines` |

### Semantic Code Chunking (NEW)

The `--strategy code` option intelligently splits code at function/class boundaries:

```bash
python rlm_tools/chunk.py codebase.py --strategy code --size 200000
```

**Supported Languages** (auto-detected or `--language`):
- Python: `def`, `class`, `async def`
- JavaScript: `function`, arrow functions, `class`
- TypeScript: `interface`, `type`, functions, classes
- Go: `func`, `type struct`, `type interface`
- Rust: `fn`, `struct`, `enum`, `impl`, `trait`
- Java: `class`, methods

**Example Output**:
```json
{
  "chunk_num": 1,
  "language": "python",
  "entities": ["function:chunk_by_size", "function:chunk_by_lines"],
  "entity_count": 2
}
```

This keeps related code together (a class with its methods) and produces more meaningful chunks than arbitrary character splits.

## Parallel Processing (NEW)

For maximum speed, use the parallel processor to spawn multiple subagents simultaneously:

```bash
# Generate parallel batch configuration
python rlm_tools/parallel_process.py rlm_context/chunks/manifest.json \
  --query "Find security vulnerabilities" \
  --batch-size 4 \
  --save-prompts
```

This creates:
- `parallel_config.json` - Full configuration
- `batch_NNN_prompt.txt` - Individual prompts for each batch

### How Parallel Processing Works

```
Sequential (slow):          Parallel (fast):

Batch 1 → Batch 2 → ...    Batch 1 ─┐
         ↓                 Batch 2 ─┼→ All complete
      ~N minutes           Batch 3 ─┤   together
                           Batch 4 ─┘
                              ↓
                           ~1 minute
```

### Speedup

| Chunks | Batches | Sequential | Parallel | Speedup |
|--------|---------|------------|----------|---------|
| 8 | 2 | ~4 min | ~2 min | 2x |
| 20 | 5 | ~10 min | ~2 min | 5x |
| 40 | 10 | ~20 min | ~2 min | 10x |

### Usage Pattern

Claude should spawn ALL batches in a single message:

```
# In ONE response, call Task multiple times:
Task(batch 1) + Task(batch 2) + Task(batch 3) + Task(batch 4)
         ↓           ↓           ↓           ↓
    [All run simultaneously, results collected together]
```

The key is including all Task invocations in ONE response rather than waiting for each to complete.

---

## Example: Codebase Security Audit

```bash
# 1. Concatenate all Python files
find . -name "*.py" -exec cat {} \; > all_code.txt

# 2. Probe
python rlm_tools/probe.py all_code.txt
# Output: 920K tokens, recommend 19 chunks

# 3. Chunk
python rlm_tools/chunk.py all_code.txt --output rlm_context/chunks/

# 4. Process (Claude spawns subagents)
# Query: "Find security vulnerabilities: SQL injection, XSS, auth bypass, hardcoded secrets"

# 5. Aggregate
python rlm_tools/aggregate.py rlm_context/results/
```

## Example: Multi-Book Analysis

```bash
# 1. Concatenate books
cat book1.txt book2.txt book3.txt > corpus.txt

# 2. Probe
python rlm_tools/probe.py corpus.txt
# Output: 1.2M tokens, recommend 24 chunks

# 3. Chunk with overlap for narrative continuity
python rlm_tools/chunk.py corpus.txt --output rlm_context/chunks/ --overlap 1000

# 4. Process
# Query: "Track character development arcs across all books"

# 5. Aggregate
python rlm_tools/aggregate.py rlm_context/results/
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Chunks too large | Reduce `--chunk-size` |
| Missing context at boundaries | Increase `--overlap` |
| Subagents timing out | Reduce batch size (2-3 chunks per agent) |
| Duplicate findings | Run aggregate with `--dedupe` |

## Integration with Hooks

The `large-input-detector.py` hook automatically suggests RLM when:
- Input > 50K chars: Soft suggestion
- Input > 150K chars: Strong recommendation with workflow

No manual intervention needed - just paste large content and follow the suggestion.

## Verified Results

| Test | Input Size | Tokens | Result |
|------|-----------|--------|--------|
| 8-Book Corpus | 4.86M chars | ~1.2M | ✅ Deaths verified |
| FastAPI Codebase | 3.68M chars | ~920K | ✅ Security classes found |

See `docs/VERIFIED_TEST_RESULTS.md` for full verification data.
