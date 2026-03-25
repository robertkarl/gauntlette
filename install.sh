#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills"
GAUNTLETTE_DIR="$SKILL_DIR/gauntlette"
SOURCE_DIR="$(cd "$(dirname "$0")/skills" && pwd)"

# Skills to install
SKILLS=(survey product-review ux-review arch-review fresh-eyes implement code-review quality-check)

# Check source exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: skills/ not found. Run from the gauntlette repo root."
  exit 1
fi

# Create target directory
mkdir -p "$SKILL_DIR"

# Symlink the gauntlette directory itself
if [ -L "$GAUNTLETTE_DIR" ]; then
  echo "Updating existing symlink: $GAUNTLETTE_DIR"
  rm "$GAUNTLETTE_DIR"
elif [ -d "$GAUNTLETTE_DIR" ]; then
  echo "ERROR: $GAUNTLETTE_DIR exists and is not a symlink. Remove it first."
  exit 1
fi

ln -s "$SOURCE_DIR" "$GAUNTLETTE_DIR"
echo "Linked: $GAUNTLETTE_DIR -> $SOURCE_DIR"

# Symlink each skill into ~/.claude/skills/
for SKILL in "${SKILLS[@]}"; do
  TARGET="$SKILL_DIR/$SKILL"

  if [ -L "$TARGET" ]; then
    EXISTING=$(readlink "$TARGET")
    if [[ "$EXISTING" != gauntlette/* ]]; then
      echo "SKIP: $SKILL -> $EXISTING (owned by another project, not overwriting)"
      continue
    fi
    rm "$TARGET"
  elif [ -d "$TARGET" ]; then
    echo "SKIP: $SKILL is a directory (owned by another project, not overwriting)"
    continue
  fi

  ln -s "gauntlette/$SKILL" "$TARGET"
  echo "Linked: /$(basename "$SKILL")"
done

echo ""
echo "Installed ${#SKILLS[@]} skills. Conflicts (if any) listed above as SKIP."
echo "Restart Claude Code to pick up new skills."
