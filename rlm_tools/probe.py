#!/usr/bin/env python3
"""
RLM Probe Tool - Analyze input structure for RLM processing.

Usage:
    python probe.py <input_file>
    python probe.py input.txt
    python probe.py document.pdf  # Extracts text first

Outputs structure analysis: character count, line count, estimated tokens,
detected format, and recommended chunk size.
"""

import argparse
import json
import os
import sys
from pathlib import Path


def count_tokens_estimate(text: str) -> int:
    """Rough token estimate: ~4 chars per token for English text."""
    return len(text) // 4


def detect_format(text: str, filename: str) -> dict:
    """Detect the structure/format of the input."""
    lines = text.split('\n')

    # Check for common formats
    format_info = {
        "type": "unknown",
        "has_headers": False,
        "is_structured": False,
        "delimiter": None
    }

    # Check file extension
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
        # Try to detect from content
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


def find_natural_boundaries(text: str) -> list:
    """Find natural chunk boundaries (headers, sections, paragraphs)."""
    boundaries = []
    lines = text.split('\n')

    for i, line in enumerate(lines):
        # Markdown headers
        if line.startswith('#'):
            boundaries.append({"line": i, "type": "header", "text": line[:50]})
        # Double newlines (paragraph breaks)
        elif i > 0 and line.strip() == '' and lines[i-1].strip() == '':
            boundaries.append({"line": i, "type": "paragraph_break", "text": ""})
        # Document markers
        elif line.startswith('---') or line.startswith('==='):
            boundaries.append({"line": i, "type": "separator", "text": line[:20]})

    return boundaries[:20]  # Return first 20 boundaries


def recommend_chunk_size(char_count: int, line_count: int, format_type: str) -> dict:
    """Recommend chunking strategy based on input characteristics."""

    # Target: ~200K chars per chunk (comfortable for Claude subagents)
    target_chunk_chars = 200000

    if char_count <= target_chunk_chars:
        return {
            "strategy": "no_chunking",
            "reason": "Input fits in single context",
            "chunk_size": char_count,
            "estimated_chunks": 1
        }

    num_chunks = (char_count // target_chunk_chars) + 1

    if format_type == "markdown":
        return {
            "strategy": "by_headers",
            "reason": "Markdown detected - chunk at header boundaries",
            "chunk_size": target_chunk_chars,
            "estimated_chunks": num_chunks
        }
    elif format_type == "json":
        return {
            "strategy": "by_elements",
            "reason": "JSON detected - chunk by top-level elements",
            "chunk_size": target_chunk_chars,
            "estimated_chunks": num_chunks
        }
    elif format_type == "code":
        return {
            "strategy": "by_functions",
            "reason": "Code detected - chunk by function/class boundaries",
            "chunk_size": target_chunk_chars,
            "estimated_chunks": num_chunks
        }
    else:
        return {
            "strategy": "by_size",
            "reason": "Plain text - chunk by character count",
            "chunk_size": target_chunk_chars,
            "estimated_chunks": num_chunks
        }


def probe_file(filepath: str) -> dict:
    """Main probe function - analyze a file."""
    path = Path(filepath)

    if not path.exists():
        return {"error": f"File not found: {filepath}"}

    # Read file
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            text = f.read()
    except Exception as e:
        return {"error": f"Failed to read file: {e}"}

    # Basic stats
    char_count = len(text)
    lines = text.split('\n')
    line_count = len(lines)
    token_estimate = count_tokens_estimate(text)

    # Format detection
    format_info = detect_format(text, filepath)

    # Find boundaries
    boundaries = find_natural_boundaries(text)

    # Chunking recommendation
    chunk_recommendation = recommend_chunk_size(char_count, line_count, format_info["type"])

    # Sample content
    sample_start = text[:500] if len(text) > 500 else text
    sample_end = text[-500:] if len(text) > 500 else ""

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
        "sample_start": sample_start,
        "sample_end": sample_end
    }


def main():
    parser = argparse.ArgumentParser(
        description="Analyze input structure for RLM processing"
    )
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
        # Human-readable output
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
        print(f"  File Size:   {result['size_bytes']:,} bytes")

        print(f"\nFormat Detection:")
        print(f"  Type:        {result['format']['type']}")
        print(f"  Structured:  {result['format']['is_structured']}")
        print(f"  Has Headers: {result['format']['has_headers']}")

        print(f"\nChunking Recommendation:")
        rec = result['chunk_recommendation']
        print(f"  Strategy:    {rec['strategy']}")
        print(f"  Reason:      {rec['reason']}")
        print(f"  Est. Chunks: {rec['estimated_chunks']}")

        if result['boundaries_found'] > 0:
            print(f"\nSample Boundaries Found ({result['boundaries_found']} total):")
            for b in result['sample_boundaries']:
                print(f"  Line {b['line']}: [{b['type']}] {b['text'][:40]}")

        print(f"\nSample Content (first 200 chars):")
        print(f"  {result['sample_start'][:200]}...")
        print()


if __name__ == "__main__":
    main()
