#!/bin/bash
#
# Enhanced Claude - System B: RLM Detection & Processing
#
# This installer sets up:
# - Automatic detection of large inputs
# - RLM (Reading Language Model) tools for processing large documents
# - Chunking, probing, aggregation, and parallel processing
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# Note: RLM tools are installed to the CURRENT DIRECTORY (project-level tools)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=============================================="
echo "  Enhanced Claude - System B Installer"
echo "  RLM Detection & Processing"
echo "=============================================="
echo -e "${NC}"

# Detect directories
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$HOOKS_DIR/logs"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups/system-b-$(date +%Y%m%d_%H%M%S)"

# Project-level directories (current directory)
PROJECT_DIR="$(pwd)"
RLM_TOOLS_DIR="$PROJECT_DIR/rlm_tools"
RLM_CONTEXT_DIR="$PROJECT_DIR/rlm_context"

echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$HOOKS_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$SKILLS_DIR/rlm"
mkdir -p "$RLM_TOOLS_DIR"
mkdir -p "$RLM_CONTEXT_DIR/chunks"
mkdir -p "$RLM_CONTEXT_DIR/results"
mkdir -p "$BACKUP_DIR"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Backing up existing settings to $BACKUP_DIR...${NC}"
    cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.backup"
fi

echo -e "${YELLOW}Installing hooks...${NC}"

# ============================================
# hook_logger.py (shared utility)
# ============================================
if [ ! -f "$HOOKS_DIR/hook_logger.py" ]; then
cat > "$HOOKS_DIR/hook_logger.py" << 'HOOK_LOGGER_EOF'
#!/usr/bin/env python3
import os
import json
import traceback
from datetime import datetime
from pathlib import Path

LOG_DIR = Path(os.path.expanduser("~/.claude/hooks/logs"))
MAX_LOG_SIZE = 1_000_000
MAX_LOG_FILES = 3

class HookLogger:
    def __init__(self, hook_name):
        self.hook_name = hook_name
        self.log_dir = LOG_DIR
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.log_file = self.log_dir / f"{hook_name}.log"
        self._rotate_if_needed()

    def _rotate_if_needed(self):
        if self.log_file.exists() and self.log_file.stat().st_size > MAX_LOG_SIZE:
            for i in range(MAX_LOG_FILES - 1, 0, -1):
                old_file = self.log_dir / f"{self.hook_name}.{i}.log"
                new_file = self.log_dir / f"{self.hook_name}.{i + 1}.log"
                if old_file.exists():
                    if i + 1 >= MAX_LOG_FILES:
                        old_file.unlink()
                    else:
                        old_file.rename(new_file)
            backup = self.log_dir / f"{self.hook_name}.1.log"
            self.log_file.rename(backup)

    def _write(self, level, message, **kwargs):
        timestamp = datetime.now().isoformat()
        entry = {"timestamp": timestamp, "level": level, "hook": self.hook_name, "message": message}
        if kwargs.get("exc_info"):
            entry["traceback"] = traceback.format_exc()
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except:
            pass

    def debug(self, msg, **kwargs): self._write("DEBUG", msg, **kwargs)
    def info(self, msg, **kwargs): self._write("INFO", msg, **kwargs)
    def warning(self, msg, **kwargs): self._write("WARNING", msg, **kwargs)
    def error(self, msg, **kwargs): self._write("ERROR", msg, **kwargs)
    def log_input(self, hook_input):
        sanitized = {"prompt_length": len(hook_input.get("prompt", "")), "prompt_preview": hook_input.get("prompt", "")[:100]}
        self.debug("Hook input received", data=sanitized)
    def log_output(self, output):
        self.debug("Hook output", data=output)
HOOK_LOGGER_EOF
echo "  Created: hook_logger.py"
else
echo "  Skipped: hook_logger.py (already exists)"
fi

# ============================================
# large-input-detector.py
# ============================================
cat > "$HOOKS_DIR/large-input-detector.py" << 'LARGE_INPUT_DETECTOR_EOF'
#!/usr/bin/env python3
"""
Large Input Detector Hook - UserPromptSubmit
Detects large user inputs and suggests RLM workflow.
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("large-input-detector")

SUGGEST_RLM_THRESHOLD = 50000      # 50K chars - suggest RLM
STRONG_RLM_THRESHOLD = 150000      # 150K chars - strongly recommend RLM
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

def estimate_tokens(text):
    return len(text) // 4

def main():
    logger.info("Hook started")
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except Exception as e:
        logger.error(f"Error reading input: {e}", exc_info=True)
        sys.exit(0)

    prompt = hook_input.get("prompt", "")
    if not prompt:
        sys.exit(0)

    char_count = len(prompt)
    token_estimate = estimate_tokens(prompt)
    logger.debug(f"Input size: {char_count} chars, ~{token_estimate} tokens")

    if char_count >= STRONG_RLM_THRESHOLD:
        logger.info(f"Strong RLM recommendation triggered ({char_count} chars)")
        message = f"""[LARGE INPUT DETECTED - RLM RECOMMENDED]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)
This exceeds comfortable context limits.

RECOMMENDED: Use RLM (Reading Language Model) workflow:
1. Save input to file: rlm_context/input.txt
2. Probe structure: python rlm_tools/probe.py rlm_context/input.txt
3. Chunk: python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
4. Process chunks with parallel Task subagents
5. Aggregate: python rlm_tools/aggregate.py rlm_context/results/

This ensures accurate processing of the full document."""

    elif char_count >= SUGGEST_RLM_THRESHOLD:
        logger.info(f"Soft RLM suggestion triggered ({char_count} chars)")
        project_dir = hook_input.get("cwd", PROJECT_DIR)
        message = f"""[LARGE INPUT NOTICE]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)

Consider using RLM workflow if you need comprehensive analysis:
- RLM tools available in: {project_dir}/rlm_tools/
- Run: python rlm_tools/probe.py <file> to analyze structure"""

    else:
        logger.debug("Input size below threshold")
        logger.info("Hook completed (early exit)")
        sys.exit(0)

    output = {"hookSpecificOutput": {"additionalContext": message}}
    logger.log_output(output)
    print(json.dumps(output), flush=True)
    logger.info("Hook completed successfully")
    sys.exit(0)

if __name__ == "__main__":
    main()
LARGE_INPUT_DETECTOR_EOF
echo "  Created: large-input-detector.py"

echo -e "${YELLOW}Installing RLM tools to $RLM_TOOLS_DIR...${NC}"

# ============================================
# probe.py
# ============================================
cat > "$RLM_TOOLS_DIR/probe.py" << 'PROBE_EOF'
#!/usr/bin/env python3
"""RLM Probe Tool - Analyze input structure for RLM processing."""
import argparse
import json
import os
import sys
from pathlib import Path

def count_tokens_estimate(text):
    return len(text) // 4

def detect_format(text, filename):
    lines = text.split('\n')
    format_info = {"type": "unknown", "has_headers": False, "is_structured": False, "delimiter": None}
    ext = Path(filename).suffix.lower()
    if ext == '.json':
        try:
            json.loads(text)
            format_info["type"] = "json"
            format_info["is_structured"] = True
        except:
            format_info["type"] = "text"
    elif ext == '.csv':
        format_info["type"] = "csv"
        format_info["is_structured"] = True
        format_info["delimiter"] = ","
    elif ext == '.md':
        format_info["type"] = "markdown"
        format_info["has_headers"] = any(line.startswith('#') for line in lines[:50])
    elif ext in ['.py', '.js', '.ts', '.java', '.cpp', '.c', '.go', '.rs']:
        format_info["type"] = "code"
        format_info["is_structured"] = True
    else:
        if text.strip().startswith('{') or text.strip().startswith('['):
            try:
                json.loads(text)
                format_info["type"] = "json"
                format_info["is_structured"] = True
            except:
                pass
        if any(line.startswith('#') for line in lines[:20]):
            format_info["type"] = "markdown"
            format_info["has_headers"] = True
    return format_info

def find_natural_boundaries(text):
    boundaries = []
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('#'):
            boundaries.append({"line": i, "type": "header", "text": line[:50]})
        elif i > 0 and line.strip() == '' and lines[i-1].strip() == '':
            boundaries.append({"line": i, "type": "paragraph_break", "text": ""})
        elif line.startswith('---') or line.startswith('==='):
            boundaries.append({"line": i, "type": "separator", "text": line[:20]})
    return boundaries[:20]

def recommend_chunk_size(char_count, line_count, format_type):
    target_chunk_chars = 200000
    if char_count <= target_chunk_chars:
        return {"strategy": "no_chunking", "reason": "Input fits in single context", "chunk_size": char_count, "estimated_chunks": 1}
    num_chunks = (char_count // target_chunk_chars) + 1
    if format_type == "markdown":
        return {"strategy": "by_headers", "reason": "Markdown detected - chunk at header boundaries", "chunk_size": target_chunk_chars, "estimated_chunks": num_chunks}
    elif format_type == "json":
        return {"strategy": "by_elements", "reason": "JSON detected - chunk by top-level elements", "chunk_size": target_chunk_chars, "estimated_chunks": num_chunks}
    elif format_type == "code":
        return {"strategy": "by_functions", "reason": "Code detected - chunk by function/class boundaries", "chunk_size": target_chunk_chars, "estimated_chunks": num_chunks}
    else:
        return {"strategy": "by_size", "reason": "Plain text - chunk by character count", "chunk_size": target_chunk_chars, "estimated_chunks": num_chunks}

def probe_file(filepath):
    path = Path(filepath)
    if not path.exists():
        return {"error": f"File not found: {filepath}"}
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            text = f.read()
    except Exception as e:
        return {"error": f"Failed to read file: {e}"}
    char_count = len(text)
    lines = text.split('\n')
    line_count = len(lines)
    token_estimate = count_tokens_estimate(text)
    format_info = detect_format(text, filepath)
    boundaries = find_natural_boundaries(text)
    chunk_recommendation = recommend_chunk_size(char_count, line_count, format_info["type"])
    return {
        "file": str(path.absolute()),
        "size_bytes": path.stat().st_size,
        "char_count": char_count,
        "line_count": line_count,
        "token_estimate": token_estimate,
        "format": format_info,
        "boundaries_found": len(boundaries),
        "sample_boundaries": boundaries[:5],
        "chunk_recommendation": chunk_recommendation,
        "sample_start": text[:500] if len(text) > 500 else text,
        "sample_end": text[-500:] if len(text) > 500 else ""
    }

def main():
    parser = argparse.ArgumentParser(description="Analyze input structure for RLM processing")
    parser.add_argument("input_file", help="File to analyze")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--save", help="Save analysis to file")
    args = parser.parse_args()
    result = probe_file(args.input_file)
    if args.json or args.save:
        output = json.dumps(result, indent=2)
        if args.save:
            with open(args.save, 'w') as f:
                f.write(output)
            print(f"Analysis saved to {args.save}")
        else:
            print(output)
    else:
        if "error" in result:
            print(f"Error: {result['error']}")
            sys.exit(1)
        print(f"\n{'='*60}")
        print(f"RLM PROBE ANALYSIS: {result['file']}")
        print(f"{'='*60}")
        print(f"\nBasic Stats:")
        print(f"  Characters:  {result['char_count']:,}")
        print(f"  Lines:       {result['line_count']:,}")
        print(f"  Est. Tokens: {result['token_estimate']:,}")
        print(f"\nFormat Detection:")
        print(f"  Type:        {result['format']['type']}")
        print(f"\nChunking Recommendation:")
        rec = result['chunk_recommendation']
        print(f"  Strategy:    {rec['strategy']}")
        print(f"  Reason:      {rec['reason']}")
        print(f"  Est. Chunks: {rec['estimated_chunks']}")
        print()

if __name__ == "__main__":
    main()
PROBE_EOF
echo "  Created: rlm_tools/probe.py"

# ============================================
# chunk.py
# ============================================
cat > "$RLM_TOOLS_DIR/chunk.py" << 'CHUNK_EOF'
#!/usr/bin/env python3
"""RLM Chunk Tool - Split large files into processable chunks."""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import List, Tuple

class ProgressTracker:
    def __init__(self, total, description="Processing", show_progress=True):
        self.total = total
        self.current = 0
        self.description = description
        self.show_progress = show_progress
        self.start_time = time.time()

    def update(self, increment=1, item_name=None):
        self.current += increment
        if self.show_progress:
            self._display(item_name)

    def _display(self, item_name=None):
        percent = (self.current / self.total) * 100 if self.total > 0 else 100
        bar_length = 30
        filled = int(bar_length * self.current / self.total) if self.total > 0 else bar_length
        bar = '#' * filled + '-' * (bar_length - filled)
        elapsed = time.time() - self.start_time
        if self.current > 0:
            eta = (elapsed / self.current) * (self.total - self.current)
            eta_str = f"ETA: {eta:.1f}s" if eta > 0 else "Done"
        else:
            eta_str = "..."
        sys.stdout.write(f"\r{self.description}: |{bar}| {self.current}/{self.total} ({percent:.1f}%) {eta_str}    ")
        sys.stdout.flush()
        if self.current >= self.total:
            print()

def chunk_by_size(text, chunk_size, overlap=500):
    chunks = []
    start = 0
    chunk_num = 1
    while start < len(text):
        end = start + chunk_size
        if end < len(text):
            newline_pos = text.rfind('\n', start + chunk_size - 1000, end + 100)
            if newline_pos > start:
                end = newline_pos + 1
        chunk_text = text[start:end]
        metadata = {"chunk_num": chunk_num, "start_char": start, "end_char": end, "char_count": len(chunk_text), "line_count": chunk_text.count('\n') + 1}
        chunks.append((chunk_text, metadata))
        start = end - overlap if end < len(text) else end
        chunk_num += 1
    return chunks

def chunk_by_lines(text, lines_per_chunk, overlap_lines=10):
    lines = text.split('\n')
    chunks = []
    start = 0
    chunk_num = 1
    while start < len(lines):
        end = min(start + lines_per_chunk, len(lines))
        chunk_text = '\n'.join(lines[start:end])
        metadata = {"chunk_num": chunk_num, "start_line": start, "end_line": end, "char_count": len(chunk_text), "line_count": end - start}
        chunks.append((chunk_text, metadata))
        start = end - overlap_lines if end < len(lines) else end
        chunk_num += 1
    return chunks

def chunk_by_headers(text, max_chunk_size=200000):
    header_pattern = re.compile(r'^(#{1,6})\s+(.+)$', re.MULTILINE)
    headers = list(header_pattern.finditer(text))
    if not headers:
        return chunk_by_size(text, max_chunk_size)
    chunks = []
    chunk_num = 1
    for i, match in enumerate(headers):
        start = match.start()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        section_text = text[start:end]
        if len(section_text) > max_chunk_size:
            sub_chunks = chunk_by_size(section_text, max_chunk_size)
            for sub_text, sub_meta in sub_chunks:
                sub_meta["chunk_num"] = chunk_num
                sub_meta["header"] = match.group(2)[:50]
                chunks.append((sub_text, sub_meta))
                chunk_num += 1
        else:
            metadata = {"chunk_num": chunk_num, "start_char": start, "end_char": end, "char_count": len(section_text), "header": match.group(2)[:50]}
            chunks.append((section_text, metadata))
            chunk_num += 1
    return chunks

def save_chunks(chunks, output_dir, prefix="chunk", show_progress=False):
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    manifest = {"total_chunks": len(chunks), "chunks": []}
    progress = ProgressTracker(len(chunks), "Saving chunks", show_progress) if show_progress else None
    for chunk_text, metadata in chunks:
        filename = f"{prefix}_{metadata['chunk_num']:03d}.txt"
        filepath = output_path / filename
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(chunk_text)
        chunk_info = {"filename": filename, "path": str(filepath.absolute()), **metadata}
        manifest["chunks"].append(chunk_info)
        if progress:
            progress.update(item_name=filename)
    manifest_path = output_path / "manifest.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
    return manifest

def main():
    parser = argparse.ArgumentParser(description="Split large files into processable chunks for RLM")
    parser.add_argument("input_file", help="File to chunk")
    parser.add_argument("--size", type=int, default=200000, help="Target chunk size in characters")
    parser.add_argument("--strategy", choices=["size", "lines", "headers"], default="size", help="Chunking strategy")
    parser.add_argument("--lines", type=int, default=1000, help="Lines per chunk (for lines strategy)")
    parser.add_argument("--overlap", type=int, default=500, help="Character overlap between chunks")
    parser.add_argument("--output", "-o", default="rlm_context/chunks", help="Output directory")
    parser.add_argument("--prefix", default="chunk", help="Chunk filename prefix")
    parser.add_argument("--progress", "-p", action="store_true", help="Show progress bar")
    args = parser.parse_args()

    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"Error: File not found: {args.input_file}")
        sys.exit(1)

    with open(input_path, 'r', encoding='utf-8', errors='ignore') as f:
        text = f.read()

    print(f"Input: {args.input_file} ({len(text):,} chars)")

    if args.strategy == "size":
        chunks = chunk_by_size(text, args.size, args.overlap)
    elif args.strategy == "lines":
        chunks = chunk_by_lines(text, args.lines)
    elif args.strategy == "headers":
        chunks = chunk_by_headers(text, args.size)

    print(f"Created {len(chunks)} chunks using '{args.strategy}' strategy")
    manifest = save_chunks(chunks, args.output, args.prefix, show_progress=args.progress)
    print(f"\nChunks saved to: {args.output}/")
    print(f"Manifest: {args.output}/manifest.json")

if __name__ == "__main__":
    main()
CHUNK_EOF
echo "  Created: rlm_tools/chunk.py"

# ============================================
# aggregate.py
# ============================================
cat > "$RLM_TOOLS_DIR/aggregate.py" << 'AGGREGATE_EOF'
#!/usr/bin/env python3
"""RLM Aggregate Tool - Combine chunk processing results."""
import argparse
import json
import sys
from glob import glob
from pathlib import Path

def read_result_file(filepath):
    path = Path(filepath)
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    try:
        data = json.loads(content)
        return {"file": path.name, "type": "json", "content": data}
    except json.JSONDecodeError:
        pass
    result = {"file": path.name, "type": "text", "content": content.strip(), "extracted": {}}
    lines = content.strip().split('\n')
    for line in lines:
        if ':' in line and not line.startswith('http'):
            parts = line.split(':', 1)
            if len(parts) == 2:
                key = parts[0].strip().lower().replace(' ', '_')
                value = parts[1].strip()
                if key and value and len(key) < 50:
                    result["extracted"][key] = value
    return result

def aggregate_results(results_dir, pattern="*.txt"):
    results_path = Path(results_dir)
    if not results_path.exists():
        return {"error": f"Directory not found: {results_dir}"}
    files = sorted(glob(str(results_path / pattern)))
    if not files:
        return {"error": f"No files matching '{pattern}' found"}
    results = [read_result_file(f) for f in files]
    return {"total_files": len(results), "results_dir": str(results_path.absolute()), "results": results}

def combine_for_synthesis(aggregated, query=None):
    if "error" in aggregated:
        return f"Error: {aggregated['error']}"
    output = []
    if query:
        output.append(f"# Query: {query}\n")
    output.append(f"# Aggregated Results ({aggregated['total_files']} chunks)\n")
    for result in aggregated["results"]:
        output.append(f"## {result['file']}\n")
        if result["type"] == "json":
            output.append(f"```json\n{json.dumps(result['content'], indent=2)}\n```")
        else:
            content = result["content"]
            if len(content) > 5000:
                content = content[:5000] + "\n... [truncated]"
            output.append(content)
        output.append("")
    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(description="Aggregate RLM chunk processing results")
    parser.add_argument("results_dir", help="Directory containing result files")
    parser.add_argument("--pattern", default="*.txt", help="File pattern to match")
    parser.add_argument("--query", "-q", help="Original query for context")
    parser.add_argument("--output", "-o", help="Save aggregation to file")
    parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    args = parser.parse_args()

    aggregated = aggregate_results(args.results_dir, args.pattern)
    if "error" in aggregated:
        print(f"Error: {aggregated['error']}")
        sys.exit(1)

    if args.format == "json":
        output = json.dumps(aggregated, indent=2)
    else:
        output = combine_for_synthesis(aggregated, args.query)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"Aggregation saved to: {args.output}")
    else:
        print(output)
    print(f"\n{'='*60}")
    print(f"Total chunks: {aggregated['total_files']}")

if __name__ == "__main__":
    main()
AGGREGATE_EOF
echo "  Created: rlm_tools/aggregate.py"

# ============================================
# parallel_process.py
# ============================================
cat > "$RLM_TOOLS_DIR/parallel_process.py" << 'PARALLEL_EOF'
#!/usr/bin/env python3
"""RLM Parallel Processor - Coordinate parallel chunk processing."""
import argparse
import json
import sys
from pathlib import Path

def load_manifest(manifest_path):
    with open(manifest_path, 'r') as f:
        return json.load(f)

def create_batches(chunks, batch_size):
    batches = []
    for i in range(0, len(chunks), batch_size):
        batches.append(chunks[i:i + batch_size])
    return batches

def generate_batch_prompt(batch, query, batch_num, total_batches):
    chunk_info = [f"  - {c['filename']}: {c['char_count']:,} chars" for c in batch]
    chunk_list = '\n'.join(chunk_info)
    chunk_paths = [c['path'] for c in batch]
    return f"""Processing batch {batch_num}/{total_batches} for RLM analysis.

QUERY: {query}

CHUNKS:
{chunk_list}

INSTRUCTIONS:
1. Read each chunk file
2. Analyze content for query relevance
3. Return findings as JSON with location, evidence, relevance

PATHS: {json.dumps(chunk_paths, indent=2)}"""

def generate_parallel_config(manifest_path, query, batch_size=4, output_dir=None):
    manifest = load_manifest(manifest_path)
    chunks = manifest['chunks']
    batches = create_batches(chunks, batch_size)
    if output_dir is None:
        output_dir = str(Path(manifest_path).parent / "results")
    config = {"query": query, "total_chunks": len(chunks), "total_batches": len(batches), "batch_size": batch_size, "output_dir": output_dir, "batches": []}
    for i, batch in enumerate(batches, 1):
        batch_config = {"batch_num": i, "chunks": [c['filename'] for c in batch], "chunk_paths": [c['path'] for c in batch], "prompt": generate_batch_prompt(batch, query, i, len(batches)), "output_file": f"{output_dir}/batch_{i:03d}_results.json"}
        config["batches"].append(batch_config)
    return config

def main():
    parser = argparse.ArgumentParser(description="Generate parallel processing config for RLM")
    parser.add_argument("manifest", help="Path to chunk manifest.json")
    parser.add_argument("--query", "-q", required=True, help="Analysis query")
    parser.add_argument("--batch-size", "-b", type=int, default=4, help="Chunks per batch")
    parser.add_argument("--output", "-o", default=None, help="Output directory for results")
    parser.add_argument("--save-prompts", "-s", action="store_true", help="Save batch prompts to files")
    parser.add_argument("--json", action="store_true", help="Output config as JSON")
    args = parser.parse_args()

    if not Path(args.manifest).exists():
        print(f"Error: Manifest not found: {args.manifest}")
        sys.exit(1)

    config = generate_parallel_config(args.manifest, args.query, args.batch_size, args.output)
    Path(config['output_dir']).mkdir(parents=True, exist_ok=True)

    if args.json:
        print(json.dumps(config, indent=2))
    else:
        print(f"{'='*60}")
        print(f"RLM PARALLEL PROCESSING")
        print(f"{'='*60}")
        print(f"Query: {config['query']}")
        print(f"Total chunks: {config['total_chunks']}")
        print(f"Total batches: {config['total_batches']}")
        print(f"\nSpawn {config['total_batches']} Task subagents in parallel for {config['total_batches']}x speedup")

        if args.save_prompts:
            for batch in config['batches']:
                prompt_file = f"{config['output_dir']}/batch_{batch['batch_num']:03d}_prompt.txt"
                with open(prompt_file, 'w') as f:
                    f.write(batch['prompt'])
                print(f"  Saved: {prompt_file}")

    config_path = f"{config['output_dir']}/parallel_config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"\nConfig saved to: {config_path}")

if __name__ == "__main__":
    main()
PARALLEL_EOF
echo "  Created: rlm_tools/parallel_process.py"

# ============================================
# sandbox.py
# ============================================
cat > "$RLM_TOOLS_DIR/sandbox.py" << 'SANDBOX_EOF'
#!/usr/bin/env python3
"""RLM Sandbox - Safe Python code execution for RLM REPL environment."""
import argparse
import json
import sys

SAFE_BUILTINS = {
    'str': str, 'int': int, 'float': float, 'bool': bool, 'list': list, 'dict': dict, 'set': set, 'tuple': tuple,
    'len': len, 'range': range, 'enumerate': enumerate, 'zip': zip, 'map': map, 'filter': filter,
    'sorted': sorted, 'reversed': reversed, 'min': min, 'max': max, 'sum': sum, 'abs': abs, 'round': round,
    'isinstance': isinstance, 'type': type, 'True': True, 'False': False, 'None': None, 'chr': chr, 'ord': ord,
    'Exception': Exception, 'ValueError': ValueError, 'TypeError': TypeError, 'KeyError': KeyError, 'IndexError': IndexError,
}

class RLMSandbox:
    def __init__(self, max_output_chars=50000, max_iterations=100000):
        self.max_output_chars = max_output_chars
        self.max_iterations = max_iterations
        self.variables = {}

    def set_context(self, context):
        self.variables['context'] = context

    def execute(self, code):
        outputs = []
        safe_env = SAFE_BUILTINS.copy()
        safe_env.update(self.variables)

        def safe_print(*args, **kwargs):
            output = ' '.join(str(arg) for arg in args)
            if len(''.join(outputs)) + len(output) < self.max_output_chars:
                outputs.append(output + '\n')

        safe_env['print'] = safe_print

        def guarded_range(*args):
            result = range(*args)
            if len(result) > self.max_iterations:
                raise ValueError(f"Range too large: {len(result)}")
            return result
        safe_env['range'] = guarded_range

        result = {"success": False, "output": "", "error": None}

        dangerous = ['import ', 'exec(', 'eval(', 'compile(', '__', 'open(', 'file(', 'input(', 'globals(', 'locals(', 'vars(', 'getattr', 'setattr', 'delattr', 'subprocess', 'os.', 'sys.']
        for pattern in dangerous:
            if pattern in code:
                result["error"] = f"Blocked pattern: {pattern}"
                return result

        try:
            exec(code, {"__builtins__": {}}, safe_env)
            result["success"] = True
            result["output"] = ''.join(outputs)
        except Exception as e:
            result["error"] = f"{type(e).__name__}: {str(e)}"
        return result

def main():
    parser = argparse.ArgumentParser(description="RLM Sandbox - Safe Python execution")
    parser.add_argument("--code", "-c", help="Code to execute")
    parser.add_argument("--file", "-f", help="File containing code")
    parser.add_argument("--context", help="Context string")
    parser.add_argument("--context-file", help="File to load as context")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    code = args.code or (open(args.file).read() if args.file else None)
    if not code:
        print("Error: Must provide --code or --file")
        sys.exit(1)

    context = args.context or (open(args.context_file, encoding='utf-8', errors='ignore').read() if args.context_file else "")

    sandbox = RLMSandbox()
    sandbox.set_context(context)
    result = sandbox.execute(code)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if result["success"]:
            print("=== Output ===")
            print(result["output"])
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)

if __name__ == "__main__":
    main()
SANDBOX_EOF
echo "  Created: rlm_tools/sandbox.py"

echo -e "${YELLOW}Installing RLM skill...${NC}"

# ============================================
# rlm/SKILL.md
# ============================================
cat > "$SKILLS_DIR/rlm/SKILL.md" << 'RLM_SKILL_EOF'
# RLM: Reading Language Model for Large Documents

> **Use when**: Processing documents/codebases larger than ~50K characters

## Quick Start

```bash
# 1. Probe the input
python rlm_tools/probe.py input.txt

# 2. Chunk into pieces
python rlm_tools/chunk.py input.txt --output rlm_context/chunks/

# 3. Process chunks with Task subagents

# 4. Aggregate results
python rlm_tools/aggregate.py rlm_context/results/
```

## When to Use RLM

| Input Size | Tokens (~) | Action |
|------------|-----------|--------|
| < 50K chars | < 12K | Direct processing |
| 50K - 150K chars | 12K - 40K | Consider RLM |
| > 150K chars | > 40K | **Use RLM** |

## Tools

- `probe.py` - Analyze input structure and size
- `chunk.py` - Split into processable pieces
- `aggregate.py` - Combine chunk results
- `parallel_process.py` - Coordinate parallel processing
- `sandbox.py` - Safe code execution

## Automatic Detection

The `large-input-detector.py` hook automatically suggests RLM when:
- Input > 50K chars: Soft suggestion
- Input > 150K chars: Strong recommendation
RLM_SKILL_EOF

cat > "$SKILLS_DIR/rlm/metadata.json" << 'RLM_META_EOF'
{
  "name": "rlm",
  "version": "1.0.0",
  "description": "Reading Language Model for processing documents larger than context window",
  "tags": ["rlm", "large-documents", "chunking", "subagents", "aggregation"],
  "useCount": 0,
  "successCount": 0,
  "failureCount": 0
}
RLM_META_EOF
echo "  Created: rlm skill"

echo -e "${YELLOW}Configuring Claude Code settings...${NC}"

# Update settings.json
python3 << SETTINGS_SCRIPT
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")
hooks_dir = os.path.expanduser("~/.claude/hooks")

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except:
    settings = {}

if "hooks" not in settings:
    settings["hooks"] = {}

system_b_hooks = {
    "UserPromptSubmit": [
        {"hooks": [{"type": "command", "command": f"python3 {hooks_dir}/large-input-detector.py"}]}
    ]
}

for event, event_hooks in system_b_hooks.items():
    if event not in settings["hooks"]:
        settings["hooks"][event] = []
    existing_commands = set()
    for hook_group in settings["hooks"][event]:
        for hook in hook_group.get("hooks", []):
            existing_commands.add(hook.get("command", ""))
    for new_hook_group in event_hooks:
        new_commands = [h.get("command", "") for h in new_hook_group.get("hooks", [])]
        if not any(cmd in existing_commands for cmd in new_commands):
            settings["hooks"][event].append(new_hook_group)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings updated successfully")
SETTINGS_SCRIPT

# Save installation manifest
cat > "$BACKUP_DIR/install-manifest.json" << MANIFEST_EOF
{
  "system": "B",
  "name": "RLM Detection & Processing",
  "installed": "$(date -Iseconds)",
  "hooks": ["$HOOKS_DIR/large-input-detector.py"],
  "skills": ["$SKILLS_DIR/rlm"],
  "project_files": ["$RLM_TOOLS_DIR"]
}
MANIFEST_EOF

echo -e "${GREEN}"
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo -e "${NC}"
echo "Installed components:"
echo "  - 2 hooks (large-input-detector, hook_logger)"
echo "  - 1 skill (rlm)"
echo "  - 5 RLM tools in $RLM_TOOLS_DIR"
echo ""
echo "Features enabled:"
echo "  - Automatic detection of large inputs"
echo "  - RLM workflow suggestion"
echo "  - Chunking, probing, aggregation tools"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo -e "${YELLOW}To uninstall, run: ./uninstall.sh${NC}"
echo ""
echo "Restart Claude Code or run /hooks to reload hooks."
