<!-- GENERATED FILE — DO NOT EDIT. Edit SKILL.md.tmpl instead. Run ./gen-skills.sh to regenerate. -->
---
name: gauntlette-help
description: "Show available gauntlette skills, pipeline order, and current plan status."
---

# /gauntlette-help — Pipeline Overview

Show the user where they are in the gauntlette pipeline. No preamble.

## Process

### Step 1: Find the current plan

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
PLAN_INREPO="docs/plans/$BRANCH_SAFE.md"
PLAN_SCRATCH="$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md"

if [ -f "$PLAN_INREPO" ]; then
  echo "PLAN: $PLAN_INREPO (promoted)"
elif [ -f "$PLAN_SCRATCH" ]; then
  echo "PLAN: $PLAN_SCRATCH (scratch)"
else
  echo "PLAN: NONE"
fi
```

### Step 2: Determine current stage

If a plan exists, read the **Gauntlette Review Report** table at the bottom of the plan. Find the last skill with status `DONE` or `SKIPPED` (any SKIPPED variant counts as completed) — the *next* skill in the pipeline is the current stage. If no skill has run or been skipped, the current stage is `/survey`.

If no plan exists, the current stage is `/survey`.

### Step 3: Print the overview

Print exactly this, placing a `*` after the skill name that is the current stage (the next one to run). For example if `/arch-review` is done, the current stage is `/fresh-eyes` and you print `/fresh-eyes *`.

```
The gauntlette pipeline:

/survey → /product-review → /ux-review → /arch-review
    → /fresh-eyes → [/cso-review] → /implement → /code-review → /quality-check → /human-review → /ship-it

1. /survey — Create the plan document, orient on codebase
2. /product-review — Challenge the idea itself (scope, value, risk)
3. /ux-review — Visual design review with ASCII wireframes
4. /arch-review — Architecture review, data flow, edge cases, test plan
5. /fresh-eyes — Independent adversarial review, fresh context
6. /cso-review — [OPTIONAL] Security audit: secrets, supply chain, auth, injection, infra
7. /implement — Build the feature from the plan
8. /code-review — Post-implementation adversarial review
9. /quality-check — E2E QA testing via playwright-cli
10. /human-review — Checklist for human: verify fixes, authorize deploys, meatspace tasks
11. /ship-it — Test, version bump, changelog, merge, ship
```

If a plan exists, also print:

```
Plan: {path to plan file}
Branch: {branch}
```

If no plan exists, print:

```
No active plan. Run /survey to start.
```

That's it. Don't explain what each skill does beyond the one-liner. Don't offer to run anything. Just print and stop.
