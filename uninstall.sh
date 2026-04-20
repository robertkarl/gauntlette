#!/bin/bash
set -e

CLAUDE_SKILL_DIR="$HOME/.claude/skills"
CODEX_SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills"

for SKILL_DIR in "$CLAUDE_SKILL_DIR" "$CODEX_SKILL_DIR"; do
  GAUNTLETTE_DIR="$SKILL_DIR/gauntlette"

  for TARGET in "$SKILL_DIR"/*; do
    if [ ! -L "$TARGET" ]; then
      continue
    fi

    SKILL=$(basename "$TARGET")
    if [ "$SKILL" = "gauntlette" ]; then
      continue
    fi

    EXISTING=$(readlink "$TARGET")
    if [[ "$EXISTING" == gauntlette/* ]]; then
      rm "$TARGET"
      echo "Removed: /$SKILL from $SKILL_DIR"
    fi
  done

  if [ -L "$GAUNTLETTE_DIR" ]; then
    rm "$GAUNTLETTE_DIR"
    echo "Removed: $GAUNTLETTE_DIR"
  elif [ -d "$GAUNTLETTE_DIR" ]; then
    echo "SKIP: $GAUNTLETTE_DIR is a real directory, not a symlink. Remove manually."
  fi
done

echo ""
echo "Gauntlette uninstalled. Restart Claude Code or Codex to take effect."
