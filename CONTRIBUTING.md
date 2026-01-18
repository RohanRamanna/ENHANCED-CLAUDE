# Contributing to Enhanced Claude

Thank you for your interest in contributing to Enhanced Claude! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

- Check existing issues first to avoid duplicates
- Use a clear, descriptive title
- Include steps to reproduce the issue
- Include your environment (OS, Claude Code version, Python version)

### Suggesting Features

- Open an issue with the "enhancement" label
- Describe the feature and its use case
- Explain how it fits with the existing systems

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test your changes (see Testing below)
5. Commit with clear messages
6. Push and open a PR

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/persistent-memory-rlm.git
cd persistent-memory-rlm

# Install hooks for testing
./install.sh

# Test a hook manually
echo '{"prompt": "test message"}' | python3 hooks/skill-matcher.py
```

## Testing

### Hook Testing

Each hook can be tested manually:

```bash
# Test skill matcher
echo '{"prompt": "help me build a bun api"}' | python3 hooks/skill-matcher.py

# Test large input detector
echo '{"prompt": "'$(python3 -c 'print("x"*60000))'"}' | python3 hooks/large-input-detector.py

# Test session recovery
echo '{}' | python3 hooks/session-recovery.py
```

### Integration Testing

1. Install hooks: `./install.sh`
2. Start Claude Code in the project directory
3. Test each system:
   - Session Persistence: Run `/compact`, verify context is restored
   - RLM Detection: Paste >50K characters, verify suggestion appears
   - Auto-Skills: Ask about "bun sqlite api", verify skill suggestion
   - History Search: Ask about past work, verify history suggestion

## Code Style

- Python 3.8+ compatible
- Use type hints where helpful
- Include docstrings for functions
- Follow existing patterns in the codebase

## Project Structure

```
hooks/                 # Hook scripts (copied to ~/.claude/hooks/)
templates/             # Template persistence files
rlm_tools/             # RLM processing tools
skills/                # Skills library
docs/                  # Documentation
```

## Areas for Contribution

### High Priority

- [ ] More chunking strategies (semantic, by function)
- [ ] Async subagent processing for RLM
- [ ] Progress tracking for chunk processing
- [ ] Testing on more languages/frameworks

### Medium Priority

- [ ] Better topic extraction algorithms
- [ ] Improved segment boundary detection
- [ ] Cross-project skill sharing
- [ ] Hook performance optimization

### Documentation

- Improve getting started guide
- Add more examples
- Document edge cases and troubleshooting

## Questions?

Open an issue with the "question" label or start a discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
