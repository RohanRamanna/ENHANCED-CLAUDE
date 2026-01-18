#!/usr/bin/env python3
"""
RLM Sandbox - Safe Python code execution for RLM REPL environment.

Usage:
    python sandbox.py --code "print(len(context))" --context "Hello world"
    python sandbox.py --file script.py --context-file input.txt

Uses RestrictedPython for safe execution with limited capabilities.
Provides: context variable, print capture, basic string/list operations.
Blocks: file I/O, network, dangerous imports, system calls.
"""

import argparse
import json
import sys
from io import StringIO
from typing import Dict, Any, Optional

# Try to import RestrictedPython, fall back to basic restricted exec
try:
    from RestrictedPython import compile_restricted, safe_globals
    from RestrictedPython.Guards import safe_builtins, guarded_iter_unpack_sequence
    from RestrictedPython.Eval import default_guarded_getiter, default_guarded_getitem
    HAS_RESTRICTED_PYTHON = True
except ImportError:
    HAS_RESTRICTED_PYTHON = False


# Safe builtins for execution
SAFE_BUILTINS = {
    # Type constructors
    'str': str,
    'int': int,
    'float': float,
    'bool': bool,
    'list': list,
    'dict': dict,
    'set': set,
    'tuple': tuple,

    # String operations
    'len': len,
    'range': range,
    'enumerate': enumerate,
    'zip': zip,
    'map': map,
    'filter': filter,
    'sorted': sorted,
    'reversed': reversed,
    'min': min,
    'max': max,
    'sum': sum,
    'abs': abs,
    'round': round,

    # Type checking
    'isinstance': isinstance,
    'type': type,

    # Boolean
    'True': True,
    'False': False,
    'None': None,

    # String methods (via str class)
    'chr': chr,
    'ord': ord,

    # Exceptions (for try/except)
    'Exception': Exception,
    'ValueError': ValueError,
    'TypeError': TypeError,
    'KeyError': KeyError,
    'IndexError': IndexError,
}


class CapturedOutput:
    """Captures print() output."""

    def __init__(self):
        self.outputs = []

    def write(self, text):
        if text.strip():
            self.outputs.append(text)

    def flush(self):
        pass

    def get_output(self) -> str:
        return ''.join(self.outputs)


class RLMSandbox:
    """Safe execution environment for RLM code."""

    def __init__(self, max_output_chars: int = 50000, max_iterations: int = 100000):
        self.max_output_chars = max_output_chars
        self.max_iterations = max_iterations
        self.variables = {}

    def set_context(self, context: Any):
        """Set the context variable."""
        self.variables['context'] = context

    def set_variable(self, name: str, value: Any):
        """Set a custom variable."""
        if name not in ['__builtins__', '__import__', 'eval', 'exec', 'compile']:
            self.variables[name] = value

    def get_variable(self, name: str) -> Any:
        """Get a variable value."""
        return self.variables.get(name)

    def execute(self, code: str) -> Dict[str, Any]:
        """Execute code safely and return results."""

        # Capture stdout
        captured = CapturedOutput()

        # Build execution environment
        safe_env = SAFE_BUILTINS.copy()
        safe_env.update(self.variables)

        # Add captured print
        def safe_print(*args, **kwargs):
            output = ' '.join(str(arg) for arg in args)
            if len(captured.get_output()) + len(output) < self.max_output_chars:
                captured.write(output + '\n')
            else:
                captured.write("[OUTPUT TRUNCATED]\n")

        safe_env['print'] = safe_print

        # Add iteration guard
        iteration_count = [0]

        def guarded_range(*args):
            result = range(*args)
            if len(result) > self.max_iterations:
                raise ValueError(f"Range too large: {len(result)} > {self.max_iterations}")
            return result

        safe_env['range'] = guarded_range

        result = {
            "success": False,
            "output": "",
            "error": None,
            "variables_modified": []
        }

        try:
            if HAS_RESTRICTED_PYTHON:
                # Use RestrictedPython for better security
                byte_code = compile_restricted(code, '<sandbox>', 'exec')
                if byte_code.errors:
                    result["error"] = f"Compilation errors: {byte_code.errors}"
                    return result

                # Add RestrictedPython guards
                safe_env['_getiter_'] = default_guarded_getiter
                safe_env['_getitem_'] = default_guarded_getitem
                safe_env['_iter_unpack_sequence_'] = guarded_iter_unpack_sequence

                exec(byte_code.code, safe_env)
            else:
                # Basic restricted execution
                # Block dangerous patterns
                dangerous = ['import ', 'exec(', 'eval(', 'compile(', '__', 'open(',
                            'file(', 'input(', 'globals(', 'locals(', 'vars(',
                            'getattr', 'setattr', 'delattr', 'subprocess', 'os.',
                            'sys.', 'socket', 'urllib', 'requests']

                for pattern in dangerous:
                    if pattern in code:
                        result["error"] = f"Blocked pattern: {pattern}"
                        return result

                exec(code, {"__builtins__": {}}, safe_env)

            result["success"] = True
            result["output"] = captured.get_output()

            # Track modified variables
            for key, value in safe_env.items():
                if key not in SAFE_BUILTINS and key != 'print' and not key.startswith('_'):
                    if key not in self.variables or self.variables[key] != value:
                        self.variables[key] = value
                        result["variables_modified"].append(key)

        except Exception as e:
            result["error"] = f"{type(e).__name__}: {str(e)}"

        return result


def main():
    parser = argparse.ArgumentParser(
        description="RLM Sandbox - Safe Python code execution"
    )
    parser.add_argument("--code", "-c", help="Code to execute")
    parser.add_argument("--file", "-f", help="File containing code to execute")
    parser.add_argument("--context", help="Context string to make available")
    parser.add_argument("--context-file", help="File to load as context")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # Get code
    if args.code:
        code = args.code
    elif args.file:
        with open(args.file, 'r') as f:
            code = f.read()
    else:
        print("Error: Must provide --code or --file")
        sys.exit(1)

    # Get context
    context = ""
    if args.context:
        context = args.context
    elif args.context_file:
        with open(args.context_file, 'r', encoding='utf-8', errors='ignore') as f:
            context = f.read()

    # Execute
    sandbox = RLMSandbox()
    sandbox.set_context(context)

    result = sandbox.execute(code)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if result["success"]:
            print("=== Output ===")
            print(result["output"])
            if result["variables_modified"]:
                print(f"\n=== Variables Modified: {result['variables_modified']} ===")
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)


if __name__ == "__main__":
    main()
