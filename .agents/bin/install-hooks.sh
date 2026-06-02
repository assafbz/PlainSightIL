#!/bin/bash

# Antigravity SDLC Git Hooks Installer
# Configures local git hooks for SDLC and Quality Gate enforcement.

echo "⚙️  Installing PlainSightIL SDLC Git Hooks..."

# Ensure we are in the root directory
if [ ! -e ".git" ]; then
  echo "🛑 ERROR: Must run this script from the project root directory containing the .git folder or file."
  exit 1
fi

GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -z "$GIT_COMMON_DIR" ]; then
  GIT_COMMON_DIR=".git"
fi
HOOKS_DIR="$GIT_COMMON_DIR/hooks"
BIN_DIR=".agents/bin"

if [ ! -d "$HOOKS_DIR" ]; then
  mkdir -p "$HOOKS_DIR"
fi

# Copy pre-commit hook
if [ -f "$BIN_DIR/pre-commit" ]; then
  cp "$BIN_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
  chmod +x "$HOOKS_DIR/pre-commit"
  echo "✅ Installed pre-commit hook (Branch and Issue checks)"
else
  echo "⚠️  WARNING: pre-commit hook template not found in $BIN_DIR"
fi

# Copy pre-push hook
if [ -f "$BIN_DIR/pre-push" ]; then
  cp "$BIN_DIR/pre-push" "$HOOKS_DIR/pre-push"
  chmod +x "$HOOKS_DIR/pre-push"
  echo "✅ Installed pre-push hook (Lint and Test validations)"
else
  echo "⚠️  WARNING: pre-push hook template not found in $BIN_DIR"
fi

echo "🎉 SDLC Git Hooks successfully installed!"
exit 0
