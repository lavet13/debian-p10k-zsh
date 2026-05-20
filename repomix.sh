#!/usr/bin/env bash

set -euo pipefail

OUTPUT_FILE="debian-p10k-full.md"
HEADER="Repository: lavet13/debian-p10k-zsh - ($(date '+%Y-%m-%d'))"

echo "📦 Running Repomix..."

repomix \
  --style markdown \
  --ignore "dotfiles/.p10k.zsh,repomix.sh" \
  --output "$OUTPUT_FILE" \
  --parsable-style \
  --header-text "$HEADER" \
  "$@"

echo "✅ Successfully created $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"
echo "💡 You can now feed this file to any AI (Claude, Grok, etc.)"
