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
    code     - Split at function/class boundaries (semantic)
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import List, Tuple


class ProgressTracker:
    """Simple progress tracker for chunk processing."""

    def __init__(self, total: int, description: str = "Processing", show_progress: bool = True):
        self.total = total
        self.current = 0
        self.description = description
        self.show_progress = show_progress
        self.start_time = time.time()

    def update(self, increment: int = 1, item_name: str = None):
        """Update progress."""
        self.current += increment
        if self.show_progress:
            self._display(item_name)

    def _display(self, item_name: str = None):
        """Display progress bar."""
        percent = (self.current / self.total) * 100 if self.total > 0 else 100
        bar_length = 30
        filled = int(bar_length * self.current / self.total) if self.total > 0 else bar_length
        bar = '█' * filled + '░' * (bar_length - filled)

        elapsed = time.time() - self.start_time
        if self.current > 0:
            eta = (elapsed / self.current) * (self.total - self.current)
            eta_str = f"ETA: {eta:.1f}s" if eta > 0 else "Done"
        else:
            eta_str = "..."

        item_info = f" ({item_name})" if item_name else ""
        sys.stdout.write(f"\r{self.description}: |{bar}| {self.current}/{self.total} ({percent:.1f}%) {eta_str}{item_info}    ")
        sys.stdout.flush()

        if self.current >= self.total:
            print()  # Newline at the end

    def finish(self):
        """Complete the progress tracking."""
        elapsed = time.time() - self.start_time
        if self.show_progress:
            print(f"\nCompleted {self.total} items in {elapsed:.2f}s")


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


def detect_language(text: str) -> str:
    """Detect programming language from code patterns."""
    # Python patterns
    if re.search(r'^(def |class |import |from .+ import |async def )', text, re.MULTILINE):
        if re.search(r':\s*$', text, re.MULTILINE):  # Python uses colons
            return "python"

    # JavaScript/TypeScript patterns
    if re.search(r'(function\s+\w+|const\s+\w+\s*=|let\s+\w+\s*=|var\s+\w+\s*=|\=\>\s*\{)', text):
        if re.search(r'(interface\s+\w+|type\s+\w+\s*=|:\s*(string|number|boolean|any))', text):
            return "typescript"
        return "javascript"

    # Go patterns
    if re.search(r'^(func\s+\w+|package\s+\w+|type\s+\w+\s+struct)', text, re.MULTILINE):
        return "go"

    # Rust patterns
    if re.search(r'^(fn\s+\w+|impl\s+\w+|struct\s+\w+|enum\s+\w+|mod\s+\w+)', text, re.MULTILINE):
        return "rust"

    # Java/Kotlin patterns
    if re.search(r'(public\s+class|private\s+class|class\s+\w+\s*\{)', text):
        return "java"

    return "unknown"


def find_code_boundaries(text: str, language: str) -> List[Tuple[int, int, str, str]]:
    """
    Find function/class boundaries in code.
    Returns list of (start, end, type, name) tuples.
    """
    boundaries = []

    # Language-specific patterns
    patterns = {
        "python": [
            (r'^class\s+(\w+)[^:]*:', "class"),
            (r'^(?:async\s+)?def\s+(\w+)\s*\([^)]*\)\s*(?:->[^:]+)?:', "function"),
        ],
        "javascript": [
            (r'^class\s+(\w+)', "class"),
            (r'^(?:async\s+)?function\s+(\w+)', "function"),
            (r'^(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\([^)]*\)\s*=>', "arrow_function"),
            (r'^(?:const|let|var)\s+(\w+)\s*=\s*function', "function"),
            (r'^export\s+(?:default\s+)?(?:async\s+)?function\s+(\w+)', "function"),
        ],
        "typescript": [
            (r'^(?:export\s+)?class\s+(\w+)', "class"),
            (r'^(?:export\s+)?interface\s+(\w+)', "interface"),
            (r'^(?:export\s+)?type\s+(\w+)', "type"),
            (r'^(?:export\s+)?(?:async\s+)?function\s+(\w+)', "function"),
            (r'^(?:export\s+)?(?:const|let|var)\s+(\w+)\s*(?::\s*[^=]+)?\s*=\s*(?:async\s+)?\([^)]*\)\s*(?::\s*[^=]+)?\s*=>', "arrow_function"),
        ],
        "go": [
            (r'^func\s+(?:\([^)]+\)\s+)?(\w+)', "function"),
            (r'^type\s+(\w+)\s+struct', "struct"),
            (r'^type\s+(\w+)\s+interface', "interface"),
        ],
        "rust": [
            (r'^(?:pub\s+)?fn\s+(\w+)', "function"),
            (r'^(?:pub\s+)?struct\s+(\w+)', "struct"),
            (r'^(?:pub\s+)?enum\s+(\w+)', "enum"),
            (r'^impl(?:<[^>]+>)?\s+(\w+)', "impl"),
            (r'^(?:pub\s+)?trait\s+(\w+)', "trait"),
        ],
        "java": [
            (r'^(?:public|private|protected)?\s*class\s+(\w+)', "class"),
            (r'^(?:public|private|protected)\s+(?:static\s+)?(?:\w+(?:<[^>]+>)?)\s+(\w+)\s*\(', "method"),
        ],
    }

    # Use generic patterns if language not specifically supported
    lang_patterns = patterns.get(language, patterns["python"])

    lines = text.split('\n')
    char_offset = 0

    for line_num, line in enumerate(lines):
        for pattern, entity_type in lang_patterns:
            match = re.match(pattern, line.lstrip())
            if match:
                # Find the start of this definition
                start = char_offset

                # Get the name
                name = match.group(1) if match.groups() else "unknown"

                boundaries.append((start, -1, entity_type, name))  # -1 means end not yet determined

        char_offset += len(line) + 1  # +1 for newline

    return boundaries


def chunk_by_code(text: str, max_chunk_size: int = 200000, language: str = None) -> List[Tuple[str, dict]]:
    """
    Split code at function/class boundaries.
    Keeps related code together (e.g., class with its methods).
    """
    # Auto-detect language if not specified
    if not language:
        language = detect_language(text)

    boundaries = find_code_boundaries(text, language)

    if not boundaries:
        # No code structures found, fall back to size-based chunking
        return chunk_by_size(text, max_chunk_size)

    # Calculate end positions for each boundary
    for i in range(len(boundaries)):
        start, _, entity_type, name = boundaries[i]
        if i + 1 < len(boundaries):
            end = boundaries[i + 1][0]
        else:
            end = len(text)
        boundaries[i] = (start, end, entity_type, name)

    # Group boundaries into chunks that fit within max_chunk_size
    chunks = []
    current_chunk_boundaries = []
    current_chunk_size = 0
    chunk_num = 1

    for start, end, entity_type, name in boundaries:
        entity_size = end - start

        # If single entity is larger than max, split it with size-based chunking
        if entity_size > max_chunk_size:
            # First, save current chunk if any
            if current_chunk_boundaries:
                chunk_start = current_chunk_boundaries[0][0]
                chunk_end = current_chunk_boundaries[-1][1]
                chunk_text = text[chunk_start:chunk_end]

                entities = [f"{b[2]}:{b[3]}" for b in current_chunk_boundaries]
                metadata = {
                    "chunk_num": chunk_num,
                    "start_char": chunk_start,
                    "end_char": chunk_end,
                    "char_count": len(chunk_text),
                    "line_count": chunk_text.count('\n') + 1,
                    "language": language,
                    "entities": entities,
                    "entity_count": len(entities)
                }
                chunks.append((chunk_text, metadata))
                chunk_num += 1
                current_chunk_boundaries = []
                current_chunk_size = 0

            # Split the large entity
            large_entity_text = text[start:end]
            sub_chunks = chunk_by_size(large_entity_text, max_chunk_size)
            for sub_text, sub_meta in sub_chunks:
                sub_meta["chunk_num"] = chunk_num
                sub_meta["language"] = language
                sub_meta["entities"] = [f"{entity_type}:{name} (part {sub_meta.get('chunk_num', '?')})"]
                sub_meta["entity_count"] = 1
                chunks.append((sub_text, sub_meta))
                chunk_num += 1
            continue

        # Check if adding this entity would exceed max size
        if current_chunk_size + entity_size > max_chunk_size and current_chunk_boundaries:
            # Save current chunk
            chunk_start = current_chunk_boundaries[0][0]
            chunk_end = current_chunk_boundaries[-1][1]
            chunk_text = text[chunk_start:chunk_end]

            entities = [f"{b[2]}:{b[3]}" for b in current_chunk_boundaries]
            metadata = {
                "chunk_num": chunk_num,
                "start_char": chunk_start,
                "end_char": chunk_end,
                "char_count": len(chunk_text),
                "line_count": chunk_text.count('\n') + 1,
                "language": language,
                "entities": entities,
                "entity_count": len(entities)
            }
            chunks.append((chunk_text, metadata))
            chunk_num += 1

            # Start new chunk
            current_chunk_boundaries = [(start, end, entity_type, name)]
            current_chunk_size = entity_size
        else:
            current_chunk_boundaries.append((start, end, entity_type, name))
            current_chunk_size += entity_size

    # Don't forget the last chunk
    if current_chunk_boundaries:
        chunk_start = current_chunk_boundaries[0][0]
        chunk_end = current_chunk_boundaries[-1][1]
        chunk_text = text[chunk_start:chunk_end]

        entities = [f"{b[2]}:{b[3]}" for b in current_chunk_boundaries]
        metadata = {
            "chunk_num": chunk_num,
            "start_char": chunk_start,
            "end_char": chunk_end,
            "char_count": len(chunk_text),
            "line_count": chunk_text.count('\n') + 1,
            "language": language,
            "entities": entities,
            "entity_count": len(entities)
        }
        chunks.append((chunk_text, metadata))

    return chunks


def save_chunks(chunks: List[Tuple[str, dict]], output_dir: str, prefix: str = "chunk", show_progress: bool = False) -> dict:
    """Save chunks to files and return manifest."""
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    manifest = {
        "total_chunks": len(chunks),
        "chunks": []
    }

    progress = ProgressTracker(len(chunks), "Saving chunks", show_progress) if show_progress else None

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

        if progress:
            progress.update(item_name=filename)

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
    parser.add_argument("--strategy", choices=["size", "lines", "headers", "paragraphs", "code"],
                        default="size", help="Chunking strategy")
    parser.add_argument("--language", choices=["python", "javascript", "typescript", "go", "rust", "java"],
                        default=None, help="Programming language (auto-detected if not specified)")
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
    parser.add_argument("--progress", "-p", action="store_true",
                        help="Show progress bar during chunking")

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
    elif args.strategy == "code":
        language = args.language or detect_language(text)
        print(f"Detected/using language: {language}")
        chunks = chunk_by_code(text, args.size, language)

    print(f"Created {len(chunks)} chunks using '{args.strategy}' strategy")

    # Save chunks
    manifest = save_chunks(chunks, args.output, args.prefix, show_progress=args.progress)

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
