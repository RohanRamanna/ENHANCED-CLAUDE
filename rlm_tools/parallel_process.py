#!/usr/bin/env python3
"""
RLM Parallel Processor - Coordinate parallel chunk processing.

This tool generates batch configurations for parallel subagent processing.
Claude can then spawn multiple Task subagents simultaneously for faster results.

Usage:
    python parallel_process.py manifest.json --query "Your query" [options]
    python parallel_process.py rlm_context/chunks/manifest.json --query "Find security issues" --batch-size 4

Output:
    Generates batch configuration with prompts ready for parallel Task spawning.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any
import time


def load_manifest(manifest_path: str) -> Dict[str, Any]:
    """Load chunk manifest."""
    with open(manifest_path, 'r') as f:
        return json.load(f)


def create_batches(chunks: List[Dict], batch_size: int) -> List[List[Dict]]:
    """Split chunks into batches for parallel processing."""
    batches = []
    for i in range(0, len(chunks), batch_size):
        batches.append(chunks[i:i + batch_size])
    return batches


def generate_batch_prompt(batch: List[Dict], query: str, batch_num: int, total_batches: int) -> str:
    """Generate a prompt for processing a batch of chunks."""
    chunk_info = []
    for chunk in batch:
        # Include entity info if available (from semantic chunking)
        entities = chunk.get('entities', [])
        entity_str = f" | Entities: {', '.join(entities)}" if entities else ""
        chunk_info.append(f"  - {chunk['filename']}: {chunk['char_count']:,} chars{entity_str}")

    chunk_list = '\n'.join(chunk_info)
    chunk_paths = [chunk['path'] for chunk in batch]

    prompt = f"""You are processing batch {batch_num}/{total_batches} for an RLM (Reading Language Model) analysis.

QUERY: {query}

CHUNKS IN THIS BATCH:
{chunk_list}

INSTRUCTIONS:
1. Read each chunk file listed above
2. Analyze the content for information relevant to the query
3. Extract specific findings with:
   - Location (chunk filename, line number if possible)
   - Evidence (exact quotes or code snippets)
   - Relevance (how it relates to the query)
4. Return findings as a JSON array

CHUNK PATHS TO READ:
{json.dumps(chunk_paths, indent=2)}

Return your findings in this format:
```json
{{
  "batch": {batch_num},
  "findings": [
    {{
      "location": "chunk_001.txt:45",
      "type": "relevant_type",
      "evidence": "exact quote or code",
      "relevance": "why this matters"
    }}
  ],
  "summary": "Brief summary of what was found in this batch"
}}
```
"""
    return prompt


def generate_parallel_config(manifest_path: str, query: str, batch_size: int = 4,
                             output_dir: str = None) -> Dict[str, Any]:
    """Generate configuration for parallel processing."""
    manifest = load_manifest(manifest_path)
    chunks = manifest['chunks']
    batches = create_batches(chunks, batch_size)

    if output_dir is None:
        output_dir = str(Path(manifest_path).parent / "results")

    config = {
        "query": query,
        "total_chunks": len(chunks),
        "total_batches": len(batches),
        "batch_size": batch_size,
        "output_dir": output_dir,
        "batches": []
    }

    for i, batch in enumerate(batches, 1):
        batch_config = {
            "batch_num": i,
            "chunks": [c['filename'] for c in batch],
            "chunk_paths": [c['path'] for c in batch],
            "prompt": generate_batch_prompt(batch, query, i, len(batches)),
            "output_file": f"{output_dir}/batch_{i:03d}_results.json"
        }
        config["batches"].append(batch_config)

    return config


def print_parallel_instructions(config: Dict[str, Any]):
    """Print instructions for Claude to execute parallel processing."""
    print("=" * 70)
    print("RLM PARALLEL PROCESSING CONFIGURATION")
    print("=" * 70)
    print(f"\nQuery: {config['query']}")
    print(f"Total chunks: {config['total_chunks']}")
    print(f"Total batches: {config['total_batches']}")
    print(f"Batch size: {config['batch_size']}")
    print(f"\nOutput directory: {config['output_dir']}")

    print("\n" + "=" * 70)
    print("PARALLEL EXECUTION INSTRUCTIONS")
    print("=" * 70)
    print("""
To process these batches in parallel, Claude should:

1. Use MULTIPLE Task tool calls in a SINGLE message
2. Each Task call processes one batch with subagent_type="general-purpose"
3. All batches run simultaneously for maximum speed

The key is to include ALL Task invocations in ONE response so they execute
in parallel rather than sequentially.
""")

    print("=" * 70)
    print("BATCH PROMPTS (copy these for Task tool)")
    print("=" * 70)


def save_batch_prompts(config: Dict[str, Any], output_dir: str):
    """Save individual batch prompts to files for easy loading."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for batch in config['batches']:
        prompt_file = f"{output_dir}/batch_{batch['batch_num']:03d}_prompt.txt"
        with open(prompt_file, 'w') as f:
            f.write(batch['prompt'])
        print(f"  Saved: {prompt_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate parallel processing configuration for RLM chunks"
    )
    parser.add_argument("manifest", help="Path to chunk manifest.json")
    parser.add_argument("--query", "-q", required=True, help="Analysis query")
    parser.add_argument("--batch-size", "-b", type=int, default=4,
                        help="Chunks per batch (default: 4)")
    parser.add_argument("--output", "-o", default=None,
                        help="Output directory for results")
    parser.add_argument("--save-prompts", "-s", action="store_true",
                        help="Save batch prompts to individual files")
    parser.add_argument("--json", action="store_true",
                        help="Output full config as JSON")

    args = parser.parse_args()

    if not Path(args.manifest).exists():
        print(f"Error: Manifest not found: {args.manifest}")
        sys.exit(1)

    # Generate configuration
    config = generate_parallel_config(
        args.manifest,
        args.query,
        args.batch_size,
        args.output
    )

    # Create output directory
    Path(config['output_dir']).mkdir(parents=True, exist_ok=True)

    if args.json:
        print(json.dumps(config, indent=2))
    else:
        print_parallel_instructions(config)

        if args.save_prompts:
            print("\nSaving batch prompts...")
            save_batch_prompts(config, config['output_dir'])

        print("\n" + "=" * 70)
        print("QUICK START")
        print("=" * 70)
        print(f"""
1. Run with --save-prompts to save individual prompt files:
   python parallel_process.py {args.manifest} --query "{args.query}" --save-prompts

2. Or use --json to get full config for programmatic use:
   python parallel_process.py {args.manifest} --query "{args.query}" --json

3. Claude should spawn {config['total_batches']} Task subagents in parallel,
   one for each batch.

Estimated speedup: {config['total_batches']}x faster than sequential processing
""")

    # Save config for reference
    config_path = f"{config['output_dir']}/parallel_config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"\nConfig saved to: {config_path}")


if __name__ == "__main__":
    main()
