#!/usr/bin/env python3
"""
RLM Aggregate Tool - Combine chunk processing results.

Usage:
    python aggregate.py <results_dir> [options]
    python aggregate.py rlm_context/results/ --query "Find all mentions of X"
    python aggregate.py rlm_context/results/ --format json

This tool reads all result files from subagent processing and combines them
into a structured format for final answer synthesis.
"""

import argparse
import json
import os
import re
import sys
from glob import glob
from pathlib import Path
from typing import List, Dict, Any


def read_result_file(filepath: str) -> Dict[str, Any]:
    """Read a single result file and extract its content."""
    path = Path(filepath)

    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # Try to parse as JSON first
    try:
        data = json.loads(content)
        return {
            "file": path.name,
            "type": "json",
            "content": data
        }
    except json.JSONDecodeError:
        pass

    # Parse as plain text with potential key-value structure
    result = {
        "file": path.name,
        "type": "text",
        "content": content.strip(),
        "extracted": {}
    }

    # Try to extract structured information
    lines = content.strip().split('\n')

    # Look for "Key: Value" patterns
    for line in lines:
        if ':' in line and not line.startswith('http'):
            parts = line.split(':', 1)
            if len(parts) == 2:
                key = parts[0].strip().lower().replace(' ', '_')
                value = parts[1].strip()
                if key and value and len(key) < 50:
                    result["extracted"][key] = value

    return result


def aggregate_results(results_dir: str, pattern: str = "*.txt") -> Dict[str, Any]:
    """Read and aggregate all result files."""
    results_path = Path(results_dir)

    if not results_path.exists():
        return {"error": f"Directory not found: {results_dir}"}

    # Find all result files
    files = sorted(glob(str(results_path / pattern)))

    if not files:
        return {"error": f"No files matching '{pattern}' found in {results_dir}"}

    results = []
    for filepath in files:
        result = read_result_file(filepath)
        results.append(result)

    return {
        "total_files": len(results),
        "results_dir": str(results_path.absolute()),
        "results": results
    }


def combine_for_synthesis(aggregated: Dict[str, Any], query: str = None) -> str:
    """Combine results into a format suitable for LLM synthesis."""
    if "error" in aggregated:
        return f"Error: {aggregated['error']}"

    output = []

    if query:
        output.append(f"# Query: {query}")
        output.append("")

    output.append(f"# Aggregated Results ({aggregated['total_files']} chunks processed)")
    output.append("")

    for result in aggregated["results"]:
        output.append(f"## {result['file']}")
        output.append("")

        if result["type"] == "json":
            output.append("```json")
            output.append(json.dumps(result["content"], indent=2))
            output.append("```")
        else:
            content = result["content"]
            # Truncate very long content
            if len(content) > 5000:
                content = content[:5000] + "\n... [truncated]"
            output.append(content)

        output.append("")

    return '\n'.join(output)


def summarize_results(aggregated: Dict[str, Any]) -> Dict[str, Any]:
    """Create a summary of aggregated results."""
    if "error" in aggregated:
        return aggregated

    summary = {
        "total_chunks": aggregated["total_files"],
        "chunks_with_findings": 0,
        "total_chars": 0,
        "extracted_keys": set(),
        "all_extracted": {}
    }

    for result in aggregated["results"]:
        content = result["content"] if isinstance(result["content"], str) else json.dumps(result["content"])
        summary["total_chars"] += len(content)

        # Count chunks with substantive findings
        if len(content.strip()) > 50:
            summary["chunks_with_findings"] += 1

        # Collect extracted keys
        if "extracted" in result:
            for key, value in result["extracted"].items():
                summary["extracted_keys"].add(key)
                if key not in summary["all_extracted"]:
                    summary["all_extracted"][key] = []
                summary["all_extracted"][key].append({
                    "file": result["file"],
                    "value": value
                })

    summary["extracted_keys"] = list(summary["extracted_keys"])
    return summary


def save_aggregation(aggregated: Dict[str, Any], output_path: str, query: str = None):
    """Save aggregation results to file."""
    output = Path(output_path)

    if output.suffix == '.json':
        with open(output, 'w') as f:
            json.dump(aggregated, f, indent=2)
    else:
        combined = combine_for_synthesis(aggregated, query)
        with open(output, 'w') as f:
            f.write(combined)


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate RLM chunk processing results"
    )
    parser.add_argument("results_dir", help="Directory containing result files")
    parser.add_argument("--pattern", default="*.txt",
                        help="File pattern to match (default: *.txt)")
    parser.add_argument("--query", "-q",
                        help="Original query for context")
    parser.add_argument("--output", "-o",
                        help="Save aggregation to file")
    parser.add_argument("--format", choices=["text", "json", "summary"],
                        default="text", help="Output format")

    args = parser.parse_args()

    # Aggregate results
    aggregated = aggregate_results(args.results_dir, args.pattern)

    if "error" in aggregated:
        print(f"Error: {aggregated['error']}")
        sys.exit(1)

    # Output based on format
    if args.format == "json":
        output = json.dumps(aggregated, indent=2)
    elif args.format == "summary":
        summary = summarize_results(aggregated)
        output = json.dumps(summary, indent=2)
    else:
        output = combine_for_synthesis(aggregated, args.query)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"Aggregation saved to: {args.output}")
    else:
        print(output)

    # Print summary stats
    if args.format != "summary":
        summary = summarize_results(aggregated)
        print(f"\n{'='*60}")
        print(f"AGGREGATION SUMMARY")
        print(f"{'='*60}")
        print(f"Total chunks: {summary['total_chunks']}")
        print(f"Chunks with findings: {summary['chunks_with_findings']}")
        print(f"Total characters: {summary['total_chars']:,}")
        if summary['extracted_keys']:
            print(f"Extracted keys: {', '.join(summary['extracted_keys'][:10])}")


if __name__ == "__main__":
    main()
