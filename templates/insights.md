# Insights

> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. Automatically injected by `session-recovery.py` hook.

## Key Learnings

*Document important learnings and patterns here.*

### Example: Hook Input/Output Pattern

All hooks receive JSON via stdin:
```python
import json
import sys

hook_input = json.load(sys.stdin)  # Contains event-specific data
# ... process ...
output = {"hookSpecificOutput": {"additionalContext": "..."}}
print(json.dumps(output))
sys.exit(0)
```

## Patterns Identified

*Document reusable patterns you discover.*

## Gotchas & Pitfalls

*Document things that tripped you up.*

## Open Questions

*Questions to investigate later.*

---

**Last Updated**: (auto-updated)
