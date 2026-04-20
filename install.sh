#!/bin/bash
set -e

SOURCE_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
CLAUDE_SKILL_DIR="$HOME/.claude/skills"
CODEX_SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills"

SKILL_LINKS=(
  "gauntlette-help:gauntlette-help"
  "gauntlette-start:survey-and-plan"
  "gauntlette-ceo-review:gauntlette-ceo-review"
  "gauntlette-product-review:gauntlette-ceo-review"
  "gauntlette-design-review:gauntlette-design-review"
  "gauntlette-ux-review:gauntlette-design-review"
  "gauntlette-eng-review:gauntlette-eng-review"
  "gauntlette-arch-review:gauntlette-eng-review"
  "gauntlette-fresh-eyes:fresh-eyes"
  "gauntlette-cso-review:cso-review"
  "gauntlette-implement:implement"
  "gauntlette-code-review:code-review"
  "gauntlette-quality-check:quality-check"
  "gauntlette-human-review:human-review"
  "gauntlette-ship-it:ship-it"
)

# Check source exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: skills/ not found. Run from the gauntlette repo root."
  exit 1
fi

# Generate SKILL.md files from templates
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$REPO_ROOT/gen-skills.sh" ]; then
  echo "Generating skills from templates..."
  bash "$REPO_ROOT/gen-skills.sh"
  echo ""
fi

link_skill_root() {
  local skill_dir="$1"
  local gauntlette_dir="$skill_dir/gauntlette"

  mkdir -p "$skill_dir"

  if [ -L "$gauntlette_dir" ]; then
    echo "Updating existing symlink: $gauntlette_dir"
    rm "$gauntlette_dir"
  elif [ -d "$gauntlette_dir" ]; then
    echo "ERROR: $gauntlette_dir exists and is not a symlink. Remove it first."
    exit 1
  fi

  ln -s "$SOURCE_DIR" "$gauntlette_dir"
  echo "Linked: $gauntlette_dir -> $SOURCE_DIR"
}

link_skill() {
  local skill_dir="$1"
  local target_name="$2"
  local source_name="$3"
  local target="$skill_dir/$target_name"

  if [ -L "$target" ]; then
    local existing
    existing=$(readlink "$target")
    if [[ "$existing" != gauntlette/* ]]; then
      echo "SKIP: $target_name -> $existing (owned by another project, not overwriting)"
      return
    fi
    rm "$target"
  elif [ -d "$target" ]; then
    echo "SKIP: $target_name is a directory (owned by another project, not overwriting)"
    return
  fi

  ln -s "gauntlette/$source_name" "$target"
  echo "Linked: /$target_name"
}

for SKILL_DIR in "$CLAUDE_SKILL_DIR" "$CODEX_SKILL_DIR"; do
  link_skill_root "$SKILL_DIR"

  for LINK in "${SKILL_LINKS[@]}"; do
    TARGET_NAME="${LINK%%:*}"
    SOURCE_NAME="${LINK##*:}"
    link_skill "$SKILL_DIR" "$TARGET_NAME" "$SOURCE_NAME"
  done

  echo ""
done

echo ""
echo "Installed gauntlette skills into:"
echo "  - $CLAUDE_SKILL_DIR"
echo "  - $CODEX_SKILL_DIR"
echo "Conflicts (if any) listed above as SKIP."
echo "Restart Claude Code or Codex to pick up new skills."
