#!/usr/bin/env python3
"""
Learning Detection Hook - Stop
Detects trial-and-error learning moments and suggests skill creation.

Trigger: Before Claude finishes responding (Stop event)
Logic: Conservative - only triggers on 3+ failures or clear error→fix patterns
Action: Blocks stop and injects learning moment suggestion
"""

import json
import sys
import os
import re

# How many recent messages to analyze
MAX_MESSAGES_TO_ANALYZE = 30

# Minimum failures needed to trigger (conservative)
MIN_FAILURES_FOR_TRIGGER = 3

def load_transcript(transcript_path):
    """Load conversation transcript from JSONL file."""
    messages = []
    try:
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        messages.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except (FileNotFoundError, IOError):
        pass
    return messages

def count_tool_failures(messages):
    """Count tool execution failures in recent messages."""
    failures = 0
    successes_after_failure = 0
    saw_failure = False

    for msg in messages[-MAX_MESSAGES_TO_ANALYZE:]:
        # Look for tool results with errors
        content = str(msg)

        # Common error patterns
        error_patterns = [
            r'error:',
            r'Error:',
            r'ERROR',
            r'failed',
            r'Failed',
            r'FAILED',
            r'exception',
            r'Exception',
            r'not found',
            r'No such file',
            r'Permission denied',
            r'command not found',
            r'ModuleNotFoundError',
            r'ImportError',
            r'SyntaxError',
            r'TypeError',
            r'ValueError',
            r'exit code [1-9]',
        ]

        for pattern in error_patterns:
            if re.search(pattern, content):
                failures += 1
                saw_failure = True
                break
        else:
            # No error in this message
            if saw_failure:
                # Check if this looks like a success after failure
                success_patterns = [
                    r'worked',
                    r'success',
                    r'fixed',
                    r'resolved',
                    r'completed',
                    r'exit code 0',
                ]
                for pattern in success_patterns:
                    if re.search(pattern, content, re.IGNORECASE):
                        successes_after_failure += 1
                        break

    return failures, successes_after_failure

def detect_trial_and_error_phrases(messages):
    """Detect phrases indicating trial-and-error in assistant messages."""
    phrases_found = 0

    trial_error_patterns = [
        r'let me try',
        r'trying again',
        r'another approach',
        r'different approach',
        r'turns out',
        r'the issue was',
        r'the problem was',
        r'that didn\'t work',
        r'that failed',
        r'I\'ll try',
        r'attempting',
        r'workaround',
    ]

    for msg in messages[-MAX_MESSAGES_TO_ANALYZE:]:
        content = str(msg)
        for pattern in trial_error_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                phrases_found += 1
                break  # Count each message once

    return phrases_found

def should_trigger_learning_moment(messages):
    """
    Determine if this is a learning moment worth capturing.

    Conservative criteria:
    1. 3+ tool failures followed by success, OR
    2. 5+ trial-and-error phrases in conversation
    """
    failures, successes_after = count_tool_failures(messages)
    trial_error_phrases = detect_trial_and_error_phrases(messages)

    # Criteria 1: Multiple failures then success
    if failures >= MIN_FAILURES_FOR_TRIGGER and successes_after >= 1:
        return True, f"Detected {failures} failures followed by success"

    # Criteria 2: Many trial-and-error phrases
    if trial_error_phrases >= 5:
        return True, f"Detected {trial_error_phrases} trial-and-error attempts"

    return False, None

def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Get transcript path
    transcript_path = hook_input.get("transcript_path", "")
    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    # Load and analyze transcript
    messages = load_transcript(transcript_path)
    if len(messages) < 5:
        # Not enough conversation to analyze
        sys.exit(0)

    # Check for learning moment
    is_learning_moment, reason = should_trigger_learning_moment(messages)

    if is_learning_moment:
        # For Stop hooks, use systemMessage (not additionalContext)
        output = {
            "continue": True,  # Don't block, just add a message
            "systemMessage": f"""[LEARNING MOMENT DETECTED]
{reason}

You solved a problem through trial-and-error. Consider saving this as a reusable skill:
1. Run /skill-creator to document the solution
2. Or add to insights.md for future reference

This helps avoid re-discovering the same solution later."""
        }
        print(json.dumps(output))

    sys.exit(0)

if __name__ == "__main__":
    main()
