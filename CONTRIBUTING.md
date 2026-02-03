# Contributing to Cursor-Claude Compat

Thank you for your interest in contributing to Cursor-Claude Compat! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue using the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Include:

- A clear description of the bug
- Steps to reproduce the issue
- Expected vs. actual behavior
- Your environment (OS, shell version, etc.)
- Any relevant error messages or logs

### Suggesting Features

Feature requests are welcome! Please use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) and include:

- A clear description of the proposed feature
- Use cases and motivation
- Any potential implementation considerations

### Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following our coding style guidelines
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Submit a pull request** using our [PR template](.github/pull_request_template.md)

## Development Setup

### Prerequisites

- bash 4.0+
- coreutils (ln, mkdir, realpath)
- jq (for MCP config merge)
- shellcheck (for linting)

### Getting Started

```bash
# Clone your fork
git clone https://github.com/your-username/cursor-claude-compat.git
cd cursor-claude-compat

# Create a branch
git checkout -b feature/your-feature-name

# Make your changes
# ...

# Test your changes
./src/scripts/sync.sh --dry-run
```

## Coding Style Guidelines

### Shell Scripts

- Use `shellcheck` to check your scripts before submitting
- Follow [Shell Style Guide](https://google.github.io/styleguide/shellguide.html) best practices
- Use meaningful variable names
- Add comments for complex logic
- Ensure scripts work on both Linux and macOS

### Markdown

- Use proper heading hierarchy
- Keep lines under 100 characters where possible
- Use code blocks with language identifiers
- Add alt text for images

### Commit Messages

- Use clear, descriptive commit messages
- Follow conventional commits format when possible:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation changes
  - `refactor:` for code refactoring
  - `test:` for test additions/changes
  - `chore:` for maintenance tasks

Example:
```
feat: add support for custom sync directories

Allow users to specify custom source and target directories
via configuration file or command-line arguments.
```

## Testing

Before submitting a PR, please:

1. Run `shellcheck` on all modified shell scripts
2. Test your changes with `--dry-run` flag
3. Verify the changes work on your system
4. Check that existing functionality still works

## Pull Request Process

1. **Ensure your PR**:
   - Addresses an open issue (or create one first)
   - Follows the project's coding style
   - Includes tests if applicable
   - Updates documentation as needed
   - Has a clear description of changes

2. **PR Review**:
   - All PRs require at least one maintainer review
   - Maintainers may request changes
   - Once approved, a maintainer will merge your PR

3. **After Merging**:
   - Your contribution will be included in the next release
   - Thank you for contributing!

## AI Usage Transparency

**Important**: This project uses AI assistance for certain tasks:

- **Issue responses**: Some issue responses may be generated or assisted by AI
- **Pull request generation**: Automated PRs (when enabled) may be created with AI assistance
- **Documentation**: Documentation may be enhanced with AI assistance

All AI-generated content is reviewed by maintainers before being merged. We believe in transparency about AI usage in open-source projects.

If you use AI tools to help with your contributions, that's fine! We just ask that you:
- Review and verify all AI-generated code
- Ensure it follows our coding standards
- Test thoroughly before submitting

## Questions?

If you have questions about contributing, please:
- Open an issue with the `question` label
- Check existing issues and discussions
- Review the [documentation](docs/)

## Recognition

Contributors will be recognized in:
- Release notes (for significant contributions)
- The project's README (for major contributors)
- GitHub's contributors page

Thank you for helping make Cursor-Claude Compat better!
