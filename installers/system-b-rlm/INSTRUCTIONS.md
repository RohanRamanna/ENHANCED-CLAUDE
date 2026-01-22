# System B: RLM Detection & Processing

## Installation

### macOS/Linux
```bash
cd /path/to/your/project
/path/to/installers/system-b-rlm/install.sh
```

### Windows
```cmd
cd \path\to\your\project
\path\to\installers\system-b-rlm\install.bat
```

### After Installation
Run `/hooks` in Claude Code to reload hooks.

---

## CLAUDE.md Configuration

**Add the following to the project's `CLAUDE.md` file:**

```markdown
## RLM (Recursive Language Model) for Large Documents

This project has RLM tools for processing documents too large to fit in context (>200K tokens).

### Automatic Detection

The `large-input-detector.py` hook automatically detects large inputs:
- **>50K chars**: Soft suggestion to consider RLM
- **>150K chars**: Strong recommendation with workflow

### RLM Tools

Located in `rlm_tools/` directory:

| Tool | Purpose |
|------|---------|
| `probe.py` | Analyze input structure and size |
| `chunk.py` | Split large files into chunks (supports semantic code chunking) |
| `aggregate.py` | Combine chunk results into final answer |
| `parallel_process.py` | Coordinate parallel chunk processing |
| `sandbox.py` | Safe Python code execution |

### RLM Workflow

When processing large documents:

1. **Probe**: Analyze the input
   ```bash
   python rlm_tools/probe.py input.txt
   ```

2. **Chunk**: Split into manageable pieces
   ```bash
   # For text
   python rlm_tools/chunk.py input.txt --output rlm_context/chunks/

   # For code (semantic chunking)
   python rlm_tools/chunk.py input.py --strategy code --output rlm_context/chunks/
   ```

3. **Process**: Use Task tool to spawn subagents for each chunk
   ```bash
   # Generate parallel processing commands
   python rlm_tools/parallel_process.py rlm_context/chunks/ "Your query here"
   ```

4. **Aggregate**: Combine results
   ```bash
   python rlm_tools/aggregate.py rlm_context/results/
   ```

### Chunk Strategy Options

| Strategy | Use For |
|----------|---------|
| `text` (default) | Plain text, documents, logs |
| `code` | Source code (Python, JS, TS, Go, Rust, Java) |

### What Claude Should Do

- When hook suggests RLM, guide user through the workflow
- Use `--strategy code` for source code files
- Spawn multiple Task subagents in parallel for faster processing
- Verify results by checking original file at reported locations
```

---

## What Gets Installed

### Hooks (in `~/.claude/hooks/`)
| Hook | Event | Purpose |
|------|-------|---------|
| `hook_logger.py` | Shared | Logging utility for all hooks |
| `large-input-detector.py` | UserPromptSubmit | Detects large inputs, suggests RLM |

### Skills (in `~/.claude/skills/`)
- `rlm/` - RLM workflow documentation

### Tools (in project's `rlm_tools/`)
- `probe.py` - Analyze input structure
- `chunk.py` - Split large files (with semantic code chunking)
- `aggregate.py` - Combine chunk results
- `parallel_process.py` - Coordinate parallel processing
- `sandbox.py` - Safe Python execution

---

## Verification

```bash
# Check hooks exist
ls -la ~/.claude/hooks/large-input-detector.py
ls -la ~/.claude/hooks/hook_logger.py

# Check skill exists
ls -la ~/.claude/skills/rlm/SKILL.md

# Check RLM tools exist
ls -la rlm_tools/probe.py
ls -la rlm_tools/chunk.py
ls -la rlm_tools/aggregate.py

# Check settings.json has hook
grep -A2 "large-input-detector" ~/.claude/settings.json

# Test probe tool
echo "Test content" > /tmp/test.txt
python3 rlm_tools/probe.py /tmp/test.txt
```
