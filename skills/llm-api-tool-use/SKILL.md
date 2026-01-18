---
name: llm-api-tool-use
description: Claude API tool use with Python SDK. Implement tool use with the Claude API using Python SDK. Use when building agents, adding function calling, creating tools for Claude, or working with the Anthropic API tool_use feature.
---

# Claude API Tool Use Implementation

## Overview
The Claude API supports tool use (function calling) where Claude can request to call tools you define, and you return results for Claude to use in its response.

## Two Approaches

### Approach 1: Tool Runner (Recommended)
The simplest approach using the `@beta_tool` decorator. Handles the tool loop automatically.

```python
import anthropic
import json
from anthropic import beta_tool

client = anthropic.Anthropic()  # Uses ANTHROPIC_API_KEY env var

@beta_tool
def get_weather(location: str, unit: str = "fahrenheit") -> str:
    """Get the current weather in a given location.

    Args:
        location: The city and state, e.g. San Francisco, CA
        unit: Temperature unit, either 'celsius' or 'fahrenheit'
    """
    # Your implementation here
    return json.dumps({"location": location, "temp": "72", "unit": unit})

@beta_tool
def calculate(expression: str) -> str:
    """Evaluate a mathematical expression.

    Args:
        expression: A math expression like "2 + 2" or "sqrt(16)"
    """
    import math
    allowed = {k: v for k, v in math.__dict__.items() if not k.startswith("_")}
    return str(eval(expression, {"__builtins__": {}}, allowed))

# Use the tool runner - handles everything automatically
runner = client.beta.messages.tool_runner(
    model="claude-sonnet-4-5-20250514",
    max_tokens=1024,
    tools=[get_weather, calculate],
    messages=[
        {"role": "user", "content": "What's the weather in SF? And what's 15 * 7?"}
    ]
)

# Iterate through messages
for message in runner:
    for block in message.content:
        if hasattr(block, 'text'):
            print(block.text)

# Or get final message directly:
# final = runner.until_done()
```

**Key points:**
- `@beta_tool` extracts schema from type hints and docstrings
- Tool runner handles the request/response loop automatically
- Return strings (use `json.dumps()` for structured data)

### Approach 2: Manual Handling (More Control)
Use when you need custom logic, async tools, or more control over the loop.

```python
import anthropic
import json

client = anthropic.Anthropic()

# Define tools with JSON schema
tools = [
    {
        "name": "get_weather",
        "description": "Get the current weather in a given location. Returns temperature and conditions.",
        "input_schema": {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "The city and state, e.g. San Francisco, CA"
                },
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "Temperature unit"
                }
            },
            "required": ["location"]
        }
    }
]

def execute_tool(name: str, input_data: dict) -> str:
    """Execute a tool and return result as string."""
    if name == "get_weather":
        return json.dumps({
            "location": input_data["location"],
            "temperature": "72",
            "condition": "Sunny"
        })
    return "Unknown tool"

# Start conversation
messages = [{"role": "user", "content": "What's the weather in NYC?"}]

# Tool use loop
while True:
    response = client.messages.create(
        model="claude-sonnet-4-5-20250514",
        max_tokens=1024,
        tools=tools,
        messages=messages
    )

    if response.stop_reason == "tool_use":
        # Collect all tool results
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                result = execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result
                })

        # Add to conversation
        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})
    else:
        # Done - print final response
        for block in response.content:
            if hasattr(block, 'text'):
                print(block.text)
        break
```

## Key Concepts

### Tool Definition Schema
```python
{
    "name": "tool_name",           # Max 64 chars, alphanumeric + underscore/hyphen
    "description": "Detailed description of what it does and when to use it",
    "input_schema": {
        "type": "object",
        "properties": {
            "param1": {"type": "string", "description": "..."},
            "param2": {"type": "integer", "description": "..."}
        },
        "required": ["param1"]
    }
}
```

### Response Handling
- `stop_reason == "tool_use"` → Claude wants to call tools
- `stop_reason == "end_turn"` → Claude is done
- `stop_reason == "max_tokens"` → Response was truncated

### Tool Results Format
```python
{
    "type": "tool_result",
    "tool_use_id": "toolu_xxx",  # Must match the tool_use block id
    "content": "result string"   # Or list of content blocks
}
```

### Error Handling
```python
{
    "type": "tool_result",
    "tool_use_id": "toolu_xxx",
    "content": "Error: Connection failed",
    "is_error": True  # Tell Claude this was an error
}
```

## Model Recommendations
- **Claude Sonnet 4.5 / Opus 4.5**: Best for complex tools and ambiguous queries
- **Claude Haiku**: Good for straightforward tools (may infer missing params)

## Common Patterns

### Forcing a Specific Tool
```python
response = client.messages.create(
    model="claude-sonnet-4-5-20250514",
    tools=tools,
    tool_choice={"type": "tool", "name": "get_weather"},  # Force this tool
    messages=[...]
)
```

### Parallel Tool Calls
Claude may call multiple tools at once. All results go in one user message:
```python
messages.append({"role": "user", "content": [
    {"type": "tool_result", "tool_use_id": "id1", "content": "result1"},
    {"type": "tool_result", "tool_use_id": "id2", "content": "result2"}
]})
```

### Streaming with Tools
```python
runner = client.beta.messages.tool_runner(
    model="claude-sonnet-4-5-20250514",
    tools=[my_tool],
    messages=[...],
    stream=True  # Enable streaming
)
for message_stream in runner:
    for event in message_stream:
        print(event)
```

## Installation
```bash
pip install anthropic
export ANTHROPIC_API_KEY="your-key-here"
```

## Sources
- [Official Tool Use Docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use)
- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
