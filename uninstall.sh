#!/bin/bash
set -e

CLAUDE_SKILL_DIR="$HOME/.claude/skills"
CODEX_SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills"

SKILLS=(
  gauntlette-help
  survey-and-plan
  survey
  help-me-plan
  gauntlette-start
  ceo-review
  gauntlette-ceo-review
  product-review
  gauntlette-product-review
  design-review
  gauntlette-design-review
  ux-review
  gauntlette-ux-review
  eng-review
  gauntlette-eng-review
  arch-review
  gauntlette-arch-review
  fresh-eyes
  gauntlette-fresh-eyes
  cso-review
  gauntlette-cso-review
  implement
  gauntlette-implement
  code-review
  gauntlette-code-review
  quality-check
  gauntlette-quality-check
  human-review
  gauntlette-human-review
  ship-it
  gauntlette-ship-it
)

for SKILL_DIR in "$CLAUDE_SKILL_DIR" "$CODEX_SKILL_DIR"; do
  GAUNTLETTE_DIR="$SKILL_DIR/gauntlette"

  for SKILL in "${SKILLS[@]}"; do
    TARGET="$SKILL_DIR/$SKILL"
    if [ -L "$TARGET" ]; then
      EXISTING=$(readlink "$TARGET")
      if [[ "$EXISTING" == gauntlette/* ]]; then
        rm "$TARGET"
        echo "Removed: /$SKILL from $SKILL_DIR"
      else
        echo "SKIP: /$SKILL -> $EXISTING (not owned by gauntlette)"
      fi
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
