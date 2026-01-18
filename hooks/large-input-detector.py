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

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("large-input-detector")

# Thresholds (characters)
SUGGEST_RLM_THRESHOLD = 50000      # 50K chars (~12K tokens) - suggest RLM
STRONG_RLM_THRESHOLD = 150000      # 150K chars (~37K tokens) - strongly recommend RLM

# Project directory with RLM tools (use cwd from hook input)
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

def estimate_tokens(text):
    """Rough estimate: ~4 chars per token for English text."""
    return len(text) // 4

def main():
    logger.info("Hook started")

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
        logger.log_input(hook_input)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}", exc_info=True)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error reading input: {e}", exc_info=True)
        sys.exit(0)

    # Get the user prompt
    prompt = hook_input.get("prompt", "")
    if not prompt:
        logger.debug("No prompt provided, exiting")
        sys.exit(0)

    char_count = len(prompt)
    token_estimate = estimate_tokens(prompt)
    logger.debug(f"Input size: {char_count} chars, ~{token_estimate} tokens")

    # Check if input is large enough to warrant RLM
    if char_count >= STRONG_RLM_THRESHOLD:
        logger.info(f"Strong RLM recommendation triggered ({char_count} chars)")
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
        logger.info(f"Soft RLM suggestion triggered ({char_count} chars)")
        # Soft suggestion
        project_dir = hook_input.get("cwd", PROJECT_DIR)
        message = f"""[LARGE INPUT NOTICE]
Input size: {char_count:,} characters (~{token_estimate:,} tokens)

Consider using RLM workflow if you need comprehensive analysis:
- RLM tools available in: {project_dir}/rlm_tools/
- Run: python rlm_tools/probe.py <file> to analyze structure"""

    else:
        # Input is fine, no action needed
        logger.debug("Input size below threshold, no action needed")
        sys.exit(0)

    # Output suggestion
    output = {
        "hookSpecificOutput": {
            "additionalContext": message
        }
    }
    logger.log_output(output)
    print(json.dumps(output))
    logger.info("Hook completed successfully")
    sys.exit(0)

if __name__ == "__main__":
    main()
