#!/bin/bash
# Claude Picker Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/aviz85/claude-picker/main/install.sh | bash

set -e

echo "🚀 Installing Claude Picker..."

# Check for fzf
if ! command -v fzf &> /dev/null; then
    echo "📦 Installing fzf..."
    if command -v brew &> /dev/null; then
        brew install fzf
    else
        echo "❌ Please install Homebrew first: https://brew.sh"
        echo "   Then run: brew install fzf"
        exit 1
    fi
fi

# Create bin directory
mkdir -p ~/bin

# Download claude-picker
echo "📥 Downloading claude-picker.sh..."
curl -fsSL -o ~/bin/claude-picker.sh https://raw.githubusercontent.com/aviz85/claude-picker/main/claude-picker.sh
chmod +x ~/bin/claude-picker.sh

# Detect shell and add to profile
SHELL_NAME=$(basename "$SHELL")
if [[ "$SHELL_NAME" == "zsh" ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ "$SHELL_NAME" == "bash" ]]; then
    PROFILE="$HOME/.bash_profile"
else
    PROFILE="$HOME/.profile"
fi

# Add source line if not already present
if ! grep -q "claude-picker.sh" "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# Claude Picker - smart terminal startup for Claude Code" >> "$PROFILE"
    echo "source ~/bin/claude-picker.sh" >> "$PROFILE"
    echo "✅ Added to $PROFILE"
else
    echo "ℹ️  Already configured in $PROFILE"
fi

echo ""
echo "✨ Claude Picker installed!"
echo ""
echo "Open a new terminal to start using it."
echo ""
echo "💡 Tip: Create an alias for Claude Code:"
echo "   echo \"alias cld='claude --dangerously-skip-permissions'\" >> $PROFILE"
echo ""
