#!/usr/bin/env bash
# Setup script to install pre-commit hooks

HOOK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/pre-commit-hook.sh"
GIT_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.git/hooks"
PRE_COMMIT_HOOK="$GIT_HOOK_DIR/pre-commit"

echo "Installing pre-commit hook..."

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOK_DIR"

# Create or update the pre-commit hook
cat > "$PRE_COMMIT_HOOK" << EOF
#!/usr/bin/env bash
# Auto-generated pre-commit hook
# This calls the project's pre-commit validation script

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
"\$SCRIPT_DIR/scripts/pre-commit-hook.sh"
EOF

# Make the hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo "✓ Pre-commit hook installed successfully!"
echo ""
echo "The hook will run automatically on every commit."
echo "To skip the hook for a specific commit, use: git commit --no-verify"
