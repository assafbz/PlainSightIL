#!/bin/bash

# Antigravity SDLC Git Hooks Installer
# Configures local git hooks for SDLC and Quality Gate enforcement.

echo "⚙️  Installing PlainSightIL SDLC Git Hooks..."

# Ensure we are in the root directory
if [ ! -d ".git" ]; then
  echo "🛑 ERROR: Must run this script from the project root directory containing the .git folder."
  exit 1
fi

HOOKS_DIR=".git/hooks"
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
