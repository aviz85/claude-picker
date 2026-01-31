# Claude Picker

Smart terminal startup for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) users on macOS.

When you open a terminal, instead of manually typing `cd project && claude`, Claude Picker shows an interactive project picker that learns your habits.

## What It Does

**Terminal opens in home directory (~):**
```
📂 Select project folder (sorted by usage)
Recent: inbox dreemz-backend tasks
┌──────────────────────────────────┐
│ > sb              ← default      │
│   my-project      (5 uses)       │
│   another-project (3 uses)       │
│   ...                            │
└──────────────────────────────────┘
```

**Terminal opens in a project folder:**
- Runs Claude Code directly (no picker)

## Features

- **Sorted by usage** - Most used projects appear first
- **Default project** - Your main project always at top (configurable)
- **Recent projects** - Shows last 3 projects in header
- **Fuzzy search** - Type to filter projects
- **Preview pane** - See folder contents before selecting
- **Handles spaces** - Works with folder names like "My Project" or "פרויקט שלי"
- **Smart skipping** - Doesn't run inside VS Code or nested Claude sessions

## Requirements

- macOS with Terminal.app or iTerm2
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [fzf](https://github.com/junegunn/fzf) - fuzzy finder

## Installation

### Recommended: Use Claude Code

The easiest way to install - just ask Claude Code to do it:

```
claude "Install claude-picker from github.com/aviz85/claude-picker"
```

Claude will download the script, install fzf if needed, and configure your shell.

### One-liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/aviz85/claude-picker/main/install.sh | bash
```

### Manual Install

1. **Install fzf:**
```bash
brew install fzf
```

2. **Download claude-picker:**
```bash
mkdir -p ~/bin
curl -o ~/bin/claude-picker.sh https://raw.githubusercontent.com/aviz85/claude-picker/main/claude-picker.sh
chmod +x ~/bin/claude-picker.sh
```

3. **Add to your shell profile:**

For bash (`~/.bash_profile`):
```bash
echo 'source ~/bin/claude-picker.sh' >> ~/.bash_profile
```

For zsh (`~/.zshrc`):
```bash
echo 'source ~/bin/claude-picker.sh' >> ~/.zshrc
```

4. **Open a new terminal** - that's it!

## Configuration

Edit `~/bin/claude-picker.sh` to customize:

```bash
# Your default project (always shown first)
DEFAULT_PROJECT="sb"

# Claude Code command
CLAUDE_CMD="claude"
```

### Using an alias for Claude Code

Many users create an alias to skip permission prompts:

```bash
# Add to your shell profile (~/.bash_profile or ~/.zshrc)
alias cld='claude --dangerously-skip-permissions'
```

Then update `claude-picker.sh`:
```bash
CLAUDE_CMD="cld"
```

## Usage Data

Usage counts are stored in `~/.claude/project-usage.json`:

```json
{
  "usage": {"sb": 10, "my-project": 5, "another": 2},
  "recent": ["my-project", "sb", "another"]
}
```

Delete this file to reset usage history.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate |
| `Enter` | Select project & launch Claude |
| `ESC` or `Ctrl+C` | Cancel (stay in ~) |
| Type anything | Filter projects |

## Disable Temporarily

```bash
# Skip picker for current session
export CLAUDE_PICKER_RAN=1

# Or just press ESC at the picker
```

## Uninstall

```bash
# Remove the script
rm ~/bin/claude-picker.sh

# Remove the source line from your shell profile
# Edit ~/.bash_profile or ~/.zshrc and remove the line:
# source ~/bin/claude-picker.sh

# Optionally remove usage data
rm ~/.claude/project-usage.json
```

## About Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) is Anthropic's official CLI for Claude - an AI coding assistant that runs in your terminal.

### Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

### Basic Usage

```bash
# Start Claude Code in current directory
claude

# Skip permission prompts (use with caution)
claude --dangerously-skip-permissions
```

### The `cld` Alias

Power users often create an alias to skip the permission prompts that Claude Code shows before running commands:

```bash
alias cld='claude --dangerously-skip-permissions'
```

**Note:** This bypasses safety prompts. Only use if you trust Claude's actions in your projects.

## License

MIT

## Author

Created by [Aviz](https://github.com/aviz85) with Claude Code.
