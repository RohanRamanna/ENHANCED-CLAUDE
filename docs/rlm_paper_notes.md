# RLM Implementation Insights

## Executive Summary
RLMs achieve **lossless infinite context** by treating the prompt as an external variable in a REPL environment, allowing the LLM to programmatically access, chunk, and recursively process arbitrarily long inputs.

---

## 1. Core Architecture

### The Key Insight
```
Traditional LLM: Prompt → [Neural Network] → Response
RLM:            Prompt → [External Variable] → [LLM writes code to access it] → Response
```

### Flow Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                    RLM (root / depth=0)                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Language Model (LLM)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↑ ↓                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Environment E (Python REPL)                    │   │
│  │                                                          │   │
│  │  • context = <prompt loaded as variable>                 │   │
│  │  • llm_query(prompt) → sub-LM response                   │   │
│  │  • print() → outputs visible to root LM                  │   │
│  │                                                          │   │
│  │  Code Executions:                                        │   │
│  │  [In 1]: print(context[:100])                            │   │
│  │  [Out 1]: "First 100 chars..."                           │   │
│  │                                                          │   │
│  │  [In 2]: chunk = context[0:10000]                        │   │
│  │          answer = llm_query(f"Analyze: {chunk}")         │   │
│  │  [Out 2]: "Analysis result..."                           │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Final: FINAL(answer) or FINAL_VAR(variable_name)              │
└─────────────────────────────────────────────────────────────────┘
```

### Recursive Sub-Call Structure
```
RLM (depth=0) - Root LLM (e.g., Claude Opus)
    │
    ├── llm_query(chunk1) → RLM (depth=1) - Sub-LM (e.g., Claude Sonnet)
    │       └── Returns: processed result
    │
    ├── llm_query(chunk2) → RLM (depth=1)
    │       └── Returns: processed result
    │
    └── Aggregates results → FINAL(answer)
```

---

## 2. Implementation Components

### 2.1 REPL Environment Setup
The environment provides:
1. **`context` variable** - The full prompt/input loaded as a string or list
2. **`llm_query(prompt)` function** - Calls a sub-LM and returns response
3. **`print()` statements** - Output visible to root LM for reasoning

### 2.2 The llm_query Function
```python
def llm_query(prompt: str) -> str:
    """
    Query a sub-LM with a prompt.
    - Can handle ~500K characters in context
    - Used for semantic analysis that can't be done with code alone
    - Returns string response from sub-LM
    """
    # Implementation: Call Claude API with the prompt
    response = anthropic_client.messages.create(
        model="claude-sonnet-...",  # Use smaller/cheaper model for sub-calls
        messages=[{"role": "user", "content": prompt}]
    )
    return response.content[0].text
```

### 2.3 Final Answer Tags
```python
# Option 1: Direct answer
FINAL(your answer here)

# Option 2: Return a variable from the REPL
FINAL_VAR(variable_name)  # Returns the value of variable_name
```

---

## 3. System Prompt (Claude Adaptation)

Based on the paper's GPT-5 prompt, here's a Claude-optimized version:

```
You are tasked with answering a query with associated context. You can access,
transform, and analyze this context interactively in a REPL environment that can
recursively query sub-LLMs. You will be queried iteratively until you provide
a final answer.

Your context is a {context_type} with {context_total_length} total characters,
broken into chunks of lengths: {context_lengths}.

The REPL environment provides:
1. A 'context' variable containing important information. Check its content
   and look through it sufficiently to answer your query.
2. A 'llm_query' function to query a sub-LM (~500K char capacity) inside REPL.
3. The ability to use 'print()' to view REPL output and continue reasoning.

IMPORTANT: Be careful about using 'llm_query' as it incurs costs. Batch
information into each call (~200k chars per call). If you have 1000 lines,
split into chunks of 5 and call llm_query on each (200 calls) rather than
1000 individual calls.

## Strategy Guidelines:
1. First probe the context to understand structure (print first/last chars, count lines)
2. Determine a chunking strategy based on context structure
3. Break context into smart chunks
4. Query sub-LM per chunk with specific questions, save answers to buffers
5. Aggregate buffers with final sub-LM call to produce answer

## Code Execution Format:
Wrap Python code in triple backticks with 'repl' identifier:

```repl
chunk = context[:10000]
answer = llm_query(f"What is X in this context? {chunk}")
print(answer)
```

## Example: Iterative Book Analysis
```repl
query = "Did Gryffindor win the House Cup?"
buffers = []
for i, section in enumerate(context):
    if i == len(context) - 1:
        buffer = llm_query(f"Last section. Known: {buffers}. Answer {query}. Section: {section}")
        print(f"Final answer: {buffer}")
    else:
        buffer = llm_query(f"Section {i}/{len(context)}. Gather info for {query}. Section: {section}")
        buffers.append(buffer)
        print(f"Section {i}: {buffer}")
```

## Example: Chunked Processing
```repl
query = "How many jobs did the author have?"
chunk_size = len(context) // 10
answers = []
for i in range(10):
    chunk = context[i*chunk_size:(i+1)*chunk_size] if i < 9 else context[i*chunk_size:]
    answer = llm_query(f"Answer if confident: {query}\n\nDocuments:\n{chunk}")
    answers.append(answer)
    print(f"Chunk {i}: {answer}")
final = llm_query(f"Aggregate answers for {query}:\n" + "\n".join(answers))
```

IMPORTANT: When done, provide final answer using:
1. FINAL(your answer) - for direct answers
2. FINAL_VAR(variable_name) - to return a REPL variable

Think step by step, plan, and execute immediately. Don't just say "I will do this."
```

---

## 4. Key Patterns from Trajectories

### 4.1 Filtering with Model Priors
```python
# Use regex to find relevant chunks based on keywords
def find_snippets(keyword, window=200, max_hits=10):
    hits = []
    for i, chunk in enumerate(context):
        idx = chunk.lower().find(keyword.lower())
        if idx != -1:
            s = max(0, idx - window)
            e = min(len(chunk), idx + len(keyword) + window)
            hits.append((i, chunk[s:e]))
            if len(hits) >= max_hits:
                return hits
    return hits

# Search for keywords from query + model priors
keywords = ["festival", "La Union", "beauty pageant", "anniversary"]
results = {kw: find_snippets(kw, window=400, max_hits=5) for kw in keywords}
```

### 4.2 Chunking & Recursive Sub-Calling
```python
# Process in batches to classify/transform
def process_batch(batch):
    prompt = """Classify each question into categories:
    'numeric value', 'entity', 'location', 'description', 'abbreviation', 'human being'

    Questions:
    """ + "\n".join(batch)
    return llm_query(prompt)

batch_size = 100
for i in range(0, len(lines), batch_size):
    batch = lines[i:i+batch_size]
    classifications = process_batch(batch)
    print(f"Batch {i//batch_size}: {classifications}")
```

### 4.3 Building Long Outputs via Variables
```python
# For tasks requiring long outputs (beyond token limits)
pairs = []
for i in range(len(users)):
    for j in range(i+1, len(users)):
        if meets_criteria(users[i], users[j]):
            pairs.append((users[i], users[j]))

formatted_pairs = [f"({p[0]}, {p[1]})" for p in pairs]
final_result = "\n".join(formatted_pairs)
FINAL_VAR(final_result)  # Return variable, not generated text
```

---

## 5. Critical Implementation Details

### 5.1 Model Selection
| Role | Recommended Model | Reasoning |
|------|------------------|-----------|
| Root LM | Claude Opus/Sonnet | Needs strong reasoning for orchestration |
| Sub-LM | Claude Sonnet/Haiku | Cost-effective, handles semantic tasks |

### 5.2 Context Limits
- Sub-LM can handle ~500K characters (~125K tokens for Claude)
- Batch ~200K chars per sub-call for efficiency
- Truncate REPL outputs to prevent context overflow

### 5.3 Iteration Control
- Max iterations to prevent infinite loops
- Track execution time and cost
- Early termination on FINAL() or FINAL_VAR()

### 5.4 Output Parsing
```python
def parse_rlm_output(output):
    # Check for final answer
    if "FINAL(" in output:
        match = re.search(r'FINAL\((.*?)\)', output, re.DOTALL)
        return {"type": "final", "value": match.group(1)}
    elif "FINAL_VAR(" in output:
        match = re.search(r'FINAL_VAR\((\w+)\)', output)
        return {"type": "final_var", "variable": match.group(1)}

    # Extract code blocks
    code_blocks = re.findall(r'```repl\n(.*?)```', output, re.DOTALL)
    return {"type": "continue", "code": code_blocks}
```

---

## 6. What NOT to Do (Negative Results)

### 6.1 Don't Use Same Prompt for All Models
- GPT-5 and Qwen3-Coder needed different prompts
- Claude may need specific adaptations

### 6.2 Models Need Strong Coding Capabilities
- Smaller models (e.g., 8B params) struggle with REPL reasoning
- Use capable models for root LM

### 6.3 Thinking Models Need Sufficient Output Tokens
- Extended thinking can exhaust output token limits
- May need to increase max_tokens or disable extended thinking for RLM

### 6.4 Async Calls Are Important
- Synchronous sub-calls are slow
- Implement async/parallel sub-LM queries for performance

### 6.5 Final Answer Detection is Brittle
- Model may output FINAL() prematurely or wrap wrong content
- Need robust parsing and validation

---

## 7. Performance Characteristics

### 7.1 Scaling Results
| Input Length | Base GPT-5 | RLM(GPT-5) |
|-------------|------------|------------|
| 8K tokens   | 95%        | 90%        |
| 131K tokens | 60%        | 85%        |
| 524K tokens | 20%        | 80%        |
| 1M tokens   | N/A (limit)| 75%        |

### 7.2 Cost Comparison
- RLM median cost ≈ base model cost
- High variance due to trajectory length differences
- Can be 3x cheaper than summarization approaches

### 7.3 When to Use RLM vs Base Model
- **Use Base Model**: Short contexts (<16K), simple retrieval tasks
- **Use RLM**: Long contexts (>32K), information-dense tasks, quadratic complexity tasks

---

## 8. Implementation Pseudocode

```python
class RecursiveLanguageModel:
    def __init__(self, root_model, sub_model, max_iterations=50):
        self.root_model = root_model
        self.sub_model = sub_model
        self.max_iterations = max_iterations

    def __call__(self, prompt: str, query: str) -> str:
        # Initialize REPL environment
        env = REPLEnvironment()
        env.set_variable("context", prompt)
        env.register_function("llm_query", self._create_llm_query())

        # Build system prompt
        system = self._build_system_prompt(prompt)

        # Iteration loop
        messages = [{"role": "user", "content": query}]

        for iteration in range(self.max_iterations):
            # Call root LM
            response = self.root_model.generate(system, messages)

            # Parse response
            parsed = self._parse_response(response)

            if parsed["type"] == "final":
                return parsed["value"]
            elif parsed["type"] == "final_var":
                return env.get_variable(parsed["variable"])

            # Execute code blocks
            for code in parsed["code"]:
                output = env.execute(code)
                messages.append({"role": "assistant", "content": response})
                messages.append({"role": "user", "content": f"Output:\n{output}"})

        raise TimeoutError("Max iterations exceeded")

    def _create_llm_query(self):
        def llm_query(prompt):
            return self.sub_model.generate(prompt)
        return llm_query
```

---

## 9. Testing Checklist

- [ ] Single needle-in-haystack (8K to 1M tokens)
- [ ] Multi-hop QA over documents
- [ ] Information aggregation (OOLONG-style)
- [ ] Pairwise reasoning (quadratic complexity)
- [ ] Code repository understanding
- [ ] Long conversation history recall
- [ ] Cost and latency benchmarks

---

## 10. Summary: Key Takeaways for Claude Implementation

1. **Don't feed long prompts directly** - Load as external variable
2. **Use Python REPL** - Enables programmatic context access
3. **Recursive sub-calls** - Smaller model handles chunks, aggregates
4. **Model priors help** - Use keywords/patterns to filter before reading
5. **Variables for long outputs** - FINAL_VAR returns REPL variables
6. **Batch sub-calls** - ~200K chars per call for efficiency
7. **Two-model setup** - Root (capable) + Sub (efficient)
8. **Robust parsing** - Handle FINAL/code blocks reliably
9. **Async execution** - Parallelize sub-calls for speed
10. **Task-agnostic prompt** - Same system prompt works across tasks
