#!/usr/bin/env python3
"""
Large Input Detector Hook - UserPromptSubmit
Detects large user inputs and suggests RLM workflow.

Trigger: Every user message (before Claude processes it)
Logic: If input > threshold, suggest RLM chunking approach
"""

import json
import sys
import os

# Thresholds (characters)
SUGGEST_RLM_THRESHOLD = 50000      # 50K chars (~12K tokens) - suggest RLM
STRONG_RLM_THRESHOLD = 150000      # 150K chars (~37K tokens) - strongly recommend RLM

# Project directory with RLM tools (auto-detected from environment or cwd)
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

def estimate_tokens(text):
    """Rough estimate: ~4 chars per token for English text."""
    return len(text) // 4

def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Get the user prompt
    prompt = hook_input.get("prompt", "")
    if not prompt:
        sys.exit(0)

    char_count = len(prompt)
    token_estimate = estimate_tokens(prompt)

    # Check if input is large enough to warrant RLM
    if char_count >= STRONG_RLM_THRESHOLD:
        # Strong recommendation
        message = f"""[LARGE INPUT DETECTED - RLM RECOMMENDED]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)
This exceeds comfortable context limits.

RECOMMENDED: Use RLM (Recursive Language Model) workflow:
1. Save input to file: rlm_context/input.txt
2. Probe structure: python rlm_tools/probe.py rlm_context/input.txt
3. Chunk: python rlm_tools/chunk.py rlm_context/input.txt --output rlm_context/chunks/
4. Process chunks with parallel Task subagents
5. Aggregate: python rlm_tools/aggregate.py rlm_context/results/

This ensures accurate processing of the full document."""

    elif char_count >= SUGGEST_RLM_THRESHOLD:
        # Soft suggestion
        message = f"""[LARGE INPUT NOTICE]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)

Consider using RLM workflow if you need comprehensive analysis:
- RLM tools available in: rlm_tools/
- Run: python rlm_tools/probe.py <file> to analyze structure"""

    else:
        # Input is fine, no action needed
        sys.exit(0)

    # Output suggestion
    output = {
        "hookSpecificOutput": {
            "additionalContext": message
        }
    }
    print(json.dumps(output))
    sys.exit(0)

if __name__ == "__main__":
    main()
