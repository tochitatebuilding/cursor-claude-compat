<div align="center">

![Tochitatebuilding Logo](.github/assets/logo-black.svg)

# Cursor-Claude Compat

**A toolkit for efficiently managing projects across both Claude Code and Cursor**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tochitatebuilding/cursor-claude-compat/actions/workflows/ci.yml/badge.svg)](https://github.com/tochitatebuilding/cursor-claude-compat/actions/workflows/ci.yml)
[![Contributors](https://img.shields.io/github/contributors/tochitatebuilding/cursor-claude-compat)](https://github.com/tochitatebuilding/cursor-claude-compat/graphs/contributors)

</div>

## Overview

Cursor-Claude Compat is a toolkit that enables seamless synchronization of project configurations, skills, rules, and plans between Claude Code and Cursor. It helps developers maintain consistency when working with both AI coding assistants.

## Why OSS?

At Tochitatebuilding, we specialize in warehouse and factory real estate, and we're committed to leveraging AI to transform our business operations. By open-sourcing this project, we aim to:

- **Share our learnings** with the developer community working with multiple AI coding assistants
- **Foster collaboration** and receive feedback to improve the tool
- **Demonstrate transparency** in our AI adoption journey
- **Contribute to the open-source ecosystem** that has enabled our growth

We believe that open collaboration accelerates innovation, especially in the rapidly evolving field of AI-assisted development.

## Features

### Project-Level Synchronization

- Automatically sync `docs/plans/` and `docs/skills/` to `.cursor/` directory
- Convert `docs/rules/` to Cursor format (with frontmatter)
- Interactive setup on first run
- Prefers symbolic links, falls back to copying

### Global Configuration Synchronization

- `~/.claude/CLAUDE.md` → `~/.cursor/rules/claude-global.md`
- `~/.claude/skills/` → `~/.cursor/skills-cursor/claude-skills/`
- `~/.claude.json` `mcpServers` → `~/.cursor/mcp.json` (safe merge)

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/tochitatebuilding/cursor-claude-compat.git
cd cursor-claude-compat

# Install global skills and rules
./installer/install.sh
```

### Usage

#### Project-Level Synchronization

Open your project in Cursor and run synchronization using one of the following methods:

1. **Skill invocation**: Type `/sync-claude-docs`
2. **Command execution**: `~/.cursor/skills-cursor/sync-claude-docs/sync.sh`

On first run, you'll be prompted to confirm the source directory, which will be saved to `.cursor/claude-compat.json`.

#### Global Configuration Synchronization

Sync Claude Code's global configuration to Cursor:

1. **Skill invocation**: Type `/sync-claude-global`
2. **Command execution**: `~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh`

## Synchronization Methods

### Project Synchronization

| Target | Claude Format | Cursor Format | Sync Method |
|--------|---------------|---------------|-------------|
| plans | `docs/plans/*.md` | `.cursor/plans/*.md` | Symbolic link or copy |
| skills | `docs/skills/*.md` | `.cursor/skills/*.md` | Symbolic link or copy |
| rules | `docs/rules/*.md` | `.cursor/rules/*.md` | Format conversion copy |

### Global Synchronization

| Target | Claude Format | Cursor Format | Sync Method |
|--------|---------------|---------------|-------------|
| rules | `~/.claude/CLAUDE.md` | `~/.cursor/rules/claude-global.md` | Frontmatter addition |
| skills | `~/.claude/skills/` | `~/.cursor/skills-cursor/claude-skills/` | Symbolic link or copy |
| mcp | `~/.claude.json` `mcpServers` | `~/.cursor/mcp.json` | Safe merge (existing takes priority) |

## Command-Line Options

```bash
# Project synchronization
sync.sh [OPTIONS]

# Global synchronization
sync-global.sh [OPTIONS]

OPTIONS:
  --yes, -y           Non-interactive mode (default: backup then overwrite)
  --skip-existing     Skip existing files
  --force, -f         Overwrite existing files without confirmation (backup created)
  --dry-run, -n       Show what would be done without actually executing
  --no-backup         Don't create backups (not recommended)
  --help, -h          Show help
```

## Directory Structure

```
cursor-claude-compat/
├── src/
│   ├── skill/
│   │   ├── SKILL.md              # Project synchronization skill
│   │   └── SKILL-global.md       # Global synchronization skill
│   ├── rule/
│   │   └── cursor-claude-compat.md
│   └── scripts/
│       ├── lib/
│       │   └── common.sh         # Common library
│       ├── sync.sh               # Project synchronization
│       ├── check.sh              # Project diff check
│       ├── sync-global.sh        # Global synchronization
│       └── check-global.sh       # Global diff check
├── installer/
│   ├── install.sh
│   └── uninstall.sh
├── templates/
└── docs/
```

## Configuration Files

### Project Configuration

`.cursor/claude-compat.json`:

```json
{
  "version": "1",
  "source": {
    "plans": "docs/plans",
    "skills": "docs/skills",
    "rules": "docs/rules"
  },
  "target": {
    "plans": ".cursor/plans",
    "skills": ".cursor/skills",
    "rules": ".cursor/rules"
  },
  "syncMethod": {
    "plans": "symlink",
    "skills": "symlink",
    "rules": "convert"
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

### Global Configuration

`~/.cursor/claude-compat-global.json`:

```json
{
  "version": "1",
  "source": {
    "claudeMd": "/home/user/.claude/CLAUDE.md",
    "skills": "/home/user/.claude/skills",
    "mcpConfig": "/home/user/.claude.json"
  },
  "target": {
    "rules": "/home/user/.cursor/rules/claude-global.md",
    "skills": "/home/user/.cursor/skills-cursor/claude-skills",
    "mcp": "/home/user/.cursor/mcp.json"
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

## Dependencies

**Required**:
- bash 4.0+
- coreutils (ln, mkdir, realpath)

**Recommended**:
- jq (required for MCP config merge; MCP sync will be skipped if not available)
- rsync (for fallback copy operations)

## Backup and Restore

- Backups are automatically saved to `~/.cursor/.claude-compat-backup/`
- Latest 5 backups are kept (older ones are automatically deleted)
- Manual restore from backup is possible if sync fails

## AI Usage Transparency

**Important**: This project uses AI assistance for certain automated tasks:

- **Issue responses**: Some issue responses may be generated or assisted by AI
- **Pull request generation**: Automated PRs (when enabled) may be created with AI assistance
- **Documentation**: Documentation may be enhanced with AI assistance

All AI-generated content is reviewed by maintainers before being merged. We believe in transparency about AI usage in open-source projects.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## Security

If you discover a security vulnerability, please follow our [Security Policy](SECURITY.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Note**: While the code is licensed under MIT, the Tochitatebuilding logo and trademarks are excluded from this license. See [TRADEMARK.md](TRADEMARK.md) for details.

## Support

For support questions, please see [SUPPORT.md](SUPPORT.md).

## About Tochitatebuilding

Tochitatebuilding is a real estate company specializing in warehouses and factories. We're committed to leveraging AI to transform business operations and contribute to the open-source community.

- **Website**: [https://tochitatebuilding.co.jp/](https://tochitatebuilding.co.jp/)
- **GitHub**: [@tochitatebuilding](https://github.com/tochitatebuilding)

---

<div align="center">

Made with ❤️ by [Tochitatebuilding](https://tochitatebuilding.co.jp/)

</div>
