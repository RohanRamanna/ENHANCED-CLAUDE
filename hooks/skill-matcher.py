#!/usr/bin/env python3
"""
Skill Matcher Hook - UserPromptSubmit
Automatically suggests relevant skills based on user prompts.

Trigger: Every user message (before Claude processes it)
Output: Matching skills injected as additionalContext
"""

import json
import sys
import os
from datetime import datetime, timedelta

# Add hooks directory to path for shared modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hook_logger import HookLogger

logger = HookLogger("skill-matcher")

# Skill index location
SKILL_INDEX_PATH = os.path.expanduser("~/.claude/skills/skill-index/index.json")

def load_skill_index():
    """Load the skill index from disk."""
    try:
        with open(SKILL_INDEX_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"skills": []}

def score_skill(skill, prompt_lower, prompt_words):
    """
    Score a skill against the user prompt.

    Scoring:
    - Exact tag match: +3 per tag
    - Category word in prompt: +5
    - Summary word match: +2 per word
    - Tag word in prompt: +2 per tag
    - Recent use (< 7 days): +1
    """
    score = 0

    # Check tags
    tags = [t.lower() for t in skill.get("tags", [])]
    for tag in tags:
        if tag in prompt_lower:
            score += 3  # Exact tag match
        # Check if any word in multi-word tags matches
        for tag_word in tag.split("-"):
            if tag_word in prompt_words and len(tag_word) > 2:
                score += 2

    # Check category
    category = skill.get("category", "").lower()
    if category in prompt_lower:
        score += 5

    # Check summary keywords
    summary = skill.get("summary", "").lower()
    summary_words = set(summary.split())
    matching_summary_words = prompt_words & summary_words
    # Filter out common words
    common_words = {"a", "an", "the", "with", "and", "or", "for", "to", "in", "on", "by", "is", "are"}
    meaningful_matches = matching_summary_words - common_words
    score += len(meaningful_matches) * 2

    # Check skill name
    name = skill.get("name", "").lower()
    name_parts = name.replace("-", " ").split()
    for part in name_parts:
        if part in prompt_words and len(part) > 2:
            score += 3

    # Recent use bonus
    last_used = skill.get("lastUsed")
    if last_used:
        try:
            last_used_date = datetime.strptime(last_used, "%Y-%m-%d")
            if datetime.now() - last_used_date < timedelta(days=7):
                score += 1
        except ValueError:
            pass

    return score

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

    # Prepare prompt for matching
    prompt_lower = prompt.lower()
    prompt_words = set(prompt_lower.replace("-", " ").replace("_", " ").split())

    # Load skill index
    try:
        index = load_skill_index()
        skills = index.get("skills", [])
        logger.debug(f"Loaded {len(skills)} skills from index")
    except Exception as e:
        logger.error(f"Error loading skill index: {e}", exc_info=True)
        sys.exit(0)

    # Score all skills
    scored_skills = []
    for skill in skills:
        score = score_skill(skill, prompt_lower, prompt_words)
        if score >= 5:  # Threshold for potential match
            scored_skills.append((score, skill))

    # Sort by score descending
    scored_skills.sort(key=lambda x: x[0], reverse=True)
    logger.debug(f"Found {len(scored_skills)} potential matches")

    # Build output for matches
    if scored_skills:
        top_matches = scored_skills[:3]  # Top 3 matches

        # Check if any strong matches (score >= 10)
        strong_matches = [(s, sk) for s, sk in top_matches if s >= 10]

        if strong_matches:
            # Build context for strong matches
            lines = ["[SKILL MATCH] Relevant skills detected:"]
            for score, skill in strong_matches:
                name = skill.get("name", "unknown")
                summary = skill.get("summary", "")
                lines.append(f"  - {name} (score:{score}): {summary}")
                lines.append(f"    Load with: cat ~/.claude/skills/{name}/SKILL.md")

            output = {
                "hookSpecificOutput": {
                    "additionalContext": "\n".join(lines)
                }
            }
            logger.log_output(output)
            print(json.dumps(output))
            logger.info(f"Matched {len(strong_matches)} skills")

    logger.info("Hook completed successfully")
    sys.exit(0)

if __name__ == "__main__":
    main()
