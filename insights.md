# Insights

> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. This builds up institutional knowledge.

## Key Learnings

### RLM Architecture Mapping
The paper's RLM components map directly to Claude Code's native tools:

| Paper Component | Claude Code Equivalent |
|-----------------|----------------------|
| Root LM | Main conversation |
| Sub-LM (llm_query) | Task tool with subagents |
| REPL Environment | Bash tool + filesystem |
| context variable | Files on disk |
| FINAL() output | Return to main conversation |

**Key insight**: No external API key needed - Claude Code IS the RLM.

### When to Use Each System

| Scenario | System | Why |
|----------|--------|-----|
| Context compacted, need to resume | Session Persistence | Read context.md, todos.md, insights.md |
| Document fits in context (<100K tokens) | Direct processing | No chunking needed |
| Document exceeds context (>200K tokens) | RLM | Must chunk and delegate |

### RLM Doesn't Save Tokens - It Enables Impossible Tasks

The 8-book test used MORE tokens than direct processing would... but direct processing is **impossible** at 1.2M tokens. RLM makes the impossible possible.

| Approach | 1.2M token input | Result |
|----------|-----------------|--------|
| Direct | ❌ Cannot fit | Impossible |
| RLM (24 chunks) | ✅ Each fits | Verified correct |

## Patterns Identified

### Effective RLM Query Design
- Be specific: "Find all character deaths" > "Analyze the books"
- Request structured output: "List with book name, character, cause"
- Include verification hooks: "Include line numbers or quotes"

### Parallel Subagent Batching
- 4 chunks per subagent works well
- 6 parallel subagents is efficient
- More subagents = faster but higher cost

### Verification Methodology
1. Run RLM query
2. Get specific claims (character X died by Y)
3. Grep original corpus for those claims
4. Confirm at exact line numbers
5. Check for false negatives (things RLM should have found)

## Gotchas & Pitfalls

### Don't Confuse the Two Systems
- Session persistence = memory across compaction (small files, always use)
- RLM = processing large documents (heavy machinery, use when needed)

### Chunk Overlap Matters
- Default 500 chars might miss context at boundaries
- For technical/legal docs, consider 1000-2000 char overlap

### Working Files Are Gitignored
- `rlm_context/input.txt`, chunks, results are NOT committed
- Only `manifest.json` is kept for reference
- Test corpus books are also gitignored (too large)

### Pride and Prejudice Test Was Invalid
- At ~187K tokens, it fits in context window
- Used MORE resources than necessary
- Real RLM value only shows at 6x+ context overflow

## RLM Works on Code Too

### FastAPI Codebase Test (1,252 files, 920K tokens)

Successfully extracted complete security architecture:
- Found all 8 core security classes (OAuth2, HTTPBasic, APIKey, etc.)
- Identified password hashing utilities across tutorial files
- Mapped the full authentication/authorization flow

### Code-Specific Insights

1. **File markers help**: Prepending `=== FILE: path ===` to each file in corpus helps subagents report locations
2. **Code queries work well**: "Find all X-related code" produces structured results
3. **Architectural discovery**: RLM can map entire subsystems (not just find individual items)

## Enhanced Claude: Auto-Skills System

### The Four Systems

| System | Problem | Behavior |
|--------|---------|----------|
| Session Persistence | Memory loss | Read files on resume |
| RLM | Oversized documents | Chunk and delegate |
| Auto-Skills | Repetitive problem-solving | Automatic matching, learning, improvement |
| Skills Library | Reusable patterns | On-demand loading |

### Auto-Skills Feedback Loop

```
User Request
    ↓
skill-matcher → Score skills against request
    ↓
skill-loader → Load matching skill (score ≥ 10)
    ↓
skill-tracker → Log usage (useCount++)
    ↓
[Apply skill]
    ↓
SUCCESS → skill-tracker (successCount++)
        → skill-improver (suggest enhancements)
    ↓
FAILURE → skill-tracker (failureCount++)
        → skill-updater (fix the skill)
    ↓
NO SKILL → Solve via trial-and-error
         → skill-creator (offer to save as new skill)
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

### Key Design Decisions

1. **Skills are files** - SKILL.md + metadata.json, not code
2. **Index is central** - skill-index/index.json for fast matching
3. **Tracking is automatic** - useCount, successCount, failureCount
4. **Learning is opportunistic** - Only offer to save after trial-and-error

## Open Questions

- ~~How does RLM perform on code?~~ → **Answered: Works excellently**
- ~~How to make skills self-improving?~~ → **Answered: Auto-skills feedback loop**
- Can we detect when RLM is needed automatically (probe → recommend)?
- What's the optimal chunk size for different document types?
- How to handle cross-chunk references more elegantly?
- How does performance vary across programming languages?

---

**Last Updated**: 2026-01-18
