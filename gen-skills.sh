#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/shared"
SKILLS_DIR="$SCRIPT_DIR/skills"

# Load shared fragments
PREAMBLE=$(cat "$SHARED_DIR/preamble.md")
PLAN_FINDING=$(cat "$SHARED_DIR/plan-finding.md")

GENERATED=0
SKIPPED=0
ERRORS=0

HEADER="<!-- GENERATED FILE — DO NOT EDIT. Edit SKILL.templ.md instead. Run ./gen-skills.sh to regenerate. -->"

for TMPL in "$SKILLS_DIR"/*/SKILL.templ.md; do
  [ -f "$TMPL" ] || continue
  SKILL_DIR=$(dirname "$TMPL")
  SKILL_NAME=$(basename "$SKILL_DIR")
  OUTPUT="$SKILL_DIR/SKILL.md"

  # Replace placeholders
  CONTENT=$(cat "$TMPL")
  CONTENT="${CONTENT//\{\{PREAMBLE\}\}/$PREAMBLE}"
  CONTENT="${CONTENT//\{\{PLAN_FINDING\}\}/$PLAN_FINDING}"

  # Check for unresolved placeholders
  if echo "$CONTENT" | grep -qE '\{\{[A-Z_]+\}\}'; then
    UNRESOLVED=$(echo "$CONTENT" | grep -oE '\{\{[A-Z_]+\}\}' | sort -u | tr '\n' ' ')
    echo "ERROR: $SKILL_NAME/SKILL.templ.md has unresolved placeholders: $UNRESOLVED"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Write generated file with header
  { echo "$HEADER"; printf '%s\n' "$CONTENT"; } > "$OUTPUT"
  GENERATED=$((GENERATED + 1))
  echo "Generated: $SKILL_NAME/SKILL.md"
done

# Warn about skills with no template
for SKILL_DIR in "$SKILLS_DIR"/*/; do
  SKILL_NAME=$(basename "$SKILL_DIR")
  if [ ! -f "$SKILL_DIR/SKILL.templ.md" ] && [ -f "$SKILL_DIR/SKILL.md" ]; then
    SKIPPED=$((SKIPPED + 1))
    echo "No template: $SKILL_NAME/SKILL.md (hand-maintained)"
  fi
done

echo ""
echo "Generated $GENERATED skills. $SKIPPED hand-maintained."

if [ "$ERRORS" -gt 0 ]; then
  echo "ERROR: $ERRORS skills had unresolved placeholders."
  exit 1
fi
