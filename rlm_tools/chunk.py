#!/usr/bin/env python3
"""
RLM Chunk Tool - Split large files into processable chunks.

Usage:
    python chunk.py <input_file> [options]
    python chunk.py input.txt --size 200000 --output chunks/
    python chunk.py document.md --strategy headers --output chunks/

Strategies:
    size     - Split by character count (default)
    lines    - Split by line count
    headers  - Split at markdown headers
    paragraphs - Split at paragraph breaks
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple


def chunk_by_size(text: str, chunk_size: int, overlap: int = 500) -> List[Tuple[str, dict]]:
    """Split text into chunks of approximately chunk_size characters."""
    chunks = []
    start = 0
    chunk_num = 1

    while start < len(text):
        end = start + chunk_size

        # Try to end at a natural boundary (newline, period, space)
        if end < len(text):
            # Look for newline first
            newline_pos = text.rfind('\n', start + chunk_size - 1000, end + 100)
            if newline_pos > start:
                end = newline_pos + 1
            else:
                # Look for period
                period_pos = text.rfind('. ', start + chunk_size - 500, end + 50)
                if period_pos > start:
                    end = period_pos + 2
                else:
                    # Look for space
                    space_pos = text.rfind(' ', start + chunk_size - 200, end + 20)
                    if space_pos > start:
                        end = space_pos + 1

        chunk_text = text[start:end]
        metadata = {
            "chunk_num": chunk_num,
            "start_char": start,
            "end_char": end,
            "char_count": len(chunk_text),
            "line_count": chunk_text.count('\n') + 1
        }

        chunks.append((chunk_text, metadata))

        # Move start with overlap for context continuity
        start = end - overlap if end < len(text) else end
        chunk_num += 1

    return chunks


def chunk_by_lines(text: str, lines_per_chunk: int, overlap_lines: int = 10) -> List[Tuple[str, dict]]:
    """Split text by line count."""
    lines = text.split('\n')
    chunks = []
    start = 0
    chunk_num = 1

    while start < len(lines):
        end = min(start + lines_per_chunk, len(lines))
        chunk_lines = lines[start:end]
        chunk_text = '\n'.join(chunk_lines)

        metadata = {
            "chunk_num": chunk_num,
            "start_line": start,
            "end_line": end,
            "char_count": len(chunk_text),
            "line_count": len(chunk_lines)
        }

        chunks.append((chunk_text, metadata))

        start = end - overlap_lines if end < len(lines) else end
        chunk_num += 1

    return chunks


def chunk_by_headers(text: str, max_chunk_size: int = 200000) -> List[Tuple[str, dict]]:
    """Split markdown text at header boundaries."""
    # Find all headers
    header_pattern = re.compile(r'^(#{1,6})\s+(.+)$', re.MULTILINE)
    headers = list(header_pattern.finditer(text))

    if not headers:
        # No headers found, fall back to size-based chunking
        return chunk_by_size(text, max_chunk_size)

    chunks = []
    chunk_num = 1

    for i, match in enumerate(headers):
        start = match.start()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)

        section_text = text[start:end]

        # If section is too large, split it further
        if len(section_text) > max_chunk_size:
            sub_chunks = chunk_by_size(section_text, max_chunk_size)
            for sub_text, sub_meta in sub_chunks:
                sub_meta["chunk_num"] = chunk_num
                sub_meta["header"] = match.group(2)[:50]
                sub_meta["header_level"] = len(match.group(1))
                chunks.append((sub_text, sub_meta))
                chunk_num += 1
        else:
            metadata = {
                "chunk_num": chunk_num,
                "start_char": start,
                "end_char": end,
                "char_count": len(section_text),
                "line_count": section_text.count('\n') + 1,
                "header": match.group(2)[:50],
                "header_level": len(match.group(1))
            }
            chunks.append((section_text, metadata))
            chunk_num += 1

    return chunks


def chunk_by_paragraphs(text: str, max_chunk_size: int = 200000) -> List[Tuple[str, dict]]:
    """Split text at paragraph boundaries (double newlines)."""
    paragraphs = re.split(r'\n\n+', text)

    chunks = []
    current_chunk = []
    current_size = 0
    chunk_num = 1

    for para in paragraphs:
        para_size = len(para) + 2  # +2 for \n\n

        if current_size + para_size > max_chunk_size and current_chunk:
            # Save current chunk
            chunk_text = '\n\n'.join(current_chunk)
            metadata = {
                "chunk_num": chunk_num,
                "char_count": len(chunk_text),
                "paragraph_count": len(current_chunk)
            }
            chunks.append((chunk_text, metadata))
            chunk_num += 1

            current_chunk = [para]
            current_size = para_size
        else:
            current_chunk.append(para)
            current_size += para_size

    # Don't forget the last chunk
    if current_chunk:
        chunk_text = '\n\n'.join(current_chunk)
        metadata = {
            "chunk_num": chunk_num,
            "char_count": len(chunk_text),
            "paragraph_count": len(current_chunk)
        }
        chunks.append((chunk_text, metadata))

    return chunks


def save_chunks(chunks: List[Tuple[str, dict]], output_dir: str, prefix: str = "chunk") -> dict:
    """Save chunks to files and return manifest."""
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    manifest = {
        "total_chunks": len(chunks),
        "chunks": []
    }

    for chunk_text, metadata in chunks:
        filename = f"{prefix}_{metadata['chunk_num']:03d}.txt"
        filepath = output_path / filename

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(chunk_text)

        chunk_info = {
            "filename": filename,
            "path": str(filepath.absolute()),
            **metadata
        }
        manifest["chunks"].append(chunk_info)

    # Save manifest
    manifest_path = output_path / "manifest.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    return manifest


def main():
    parser = argparse.ArgumentParser(
        description="Split large files into processable chunks for RLM"
    )
    parser.add_argument("input_file", help="File to chunk")
    parser.add_argument("--size", type=int, default=200000,
                        help="Target chunk size in characters (default: 200000)")
    parser.add_argument("--strategy", choices=["size", "lines", "headers", "paragraphs"],
                        default="size", help="Chunking strategy")
    parser.add_argument("--lines", type=int, default=1000,
                        help="Lines per chunk (for lines strategy)")
    parser.add_argument("--overlap", type=int, default=500,
                        help="Character overlap between chunks (default: 500)")
    parser.add_argument("--output", "-o", default="rlm_context/chunks",
                        help="Output directory (default: rlm_context/chunks)")
    parser.add_argument("--prefix", default="chunk",
                        help="Chunk filename prefix (default: chunk)")
    parser.add_argument("--json", action="store_true",
                        help="Output manifest as JSON to stdout")

    args = parser.parse_args()

    # Read input file
    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"Error: File not found: {args.input_file}")
        sys.exit(1)

    with open(input_path, 'r', encoding='utf-8', errors='ignore') as f:
        text = f.read()

    print(f"Input: {args.input_file} ({len(text):,} chars)")

    # Chunk based on strategy
    if args.strategy == "size":
        chunks = chunk_by_size(text, args.size, args.overlap)
    elif args.strategy == "lines":
        chunks = chunk_by_lines(text, args.lines)
    elif args.strategy == "headers":
        chunks = chunk_by_headers(text, args.size)
    elif args.strategy == "paragraphs":
        chunks = chunk_by_paragraphs(text, args.size)

    print(f"Created {len(chunks)} chunks using '{args.strategy}' strategy")

    # Save chunks
    manifest = save_chunks(chunks, args.output, args.prefix)

    if args.json:
        print(json.dumps(manifest, indent=2))
    else:
        print(f"\nChunks saved to: {args.output}/")
        print(f"Manifest: {args.output}/manifest.json")
        print("\nChunk summary:")
        for chunk_info in manifest["chunks"]:
            print(f"  {chunk_info['filename']}: {chunk_info['char_count']:,} chars")


if __name__ == "__main__":
    main()
