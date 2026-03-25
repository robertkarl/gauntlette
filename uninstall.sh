#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills"
GAUNTLETTE_DIR="$SKILL_DIR/gauntlette"

SKILLS=(survey product-review ux-review arch-review fresh-eyes implement code-review quality-check)

# Remove individual skill symlinks (only if they point to gauntlette)
for SKILL in "${SKILLS[@]}"; do
  TARGET="$SKILL_DIR/$SKILL"
  if [ -L "$TARGET" ]; then
    EXISTING=$(readlink "$TARGET")
    if [[ "$EXISTING" == gauntlette/* ]]; then
      rm "$TARGET"
      echo "Removed: /$SKILL"
    else
      echo "SKIP: /$SKILL -> $EXISTING (not owned by gauntlette)"
    fi
  fi
done

# Remove gauntlette directory symlink
if [ -L "$GAUNTLETTE_DIR" ]; then
  rm "$GAUNTLETTE_DIR"
  echo "Removed: $GAUNTLETTE_DIR"
elif [ -d "$GAUNTLETTE_DIR" ]; then
  echo "SKIP: $GAUNTLETTE_DIR is a real directory, not a symlink. Remove manually."
fi

echo ""
echo "Gauntlette uninstalled. Restart Claude Code to take effect."
