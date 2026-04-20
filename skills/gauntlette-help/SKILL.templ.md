---
name: gauntlette-help
description: "Show preferred gauntlette commands, pipeline order, and current plan status."
---

# /gauntlette-help — Pipeline Overview

Show the user where they are in the gauntlette pipeline. No preamble.

## Process

### Step 1: Find the current plan

{{PLAN_FINDING}}

### Step 2: Determine current stage

If a plan exists, read the **Gauntlette Review Report** table at the bottom of the plan. Find the last skill with status `DONE` or `SKIPPED` (any SKIPPED variant counts as completed) — the *next* skill in the pipeline is the current stage. If no skill has run or been skipped, the current stage is `/gauntlette-start`.

If no plan exists, the current stage is `/gauntlette-start`.

### Step 3: Print the overview

Print exactly this, placing a `*` after the skill name that is the current stage (the next one to run). For example if `/gauntlette-eng-review` is done, the current stage is `/gauntlette-fresh-eyes` and you print `/gauntlette-fresh-eyes *`.

```
Preferred gauntlette commands:

/gauntlette-start → /gauntlette-ceo-review → /gauntlette-design-review → /gauntlette-eng-review
    → /gauntlette-fresh-eyes → [/gauntlette-cso-review] → /gauntlette-implement
    → /gauntlette-code-review → /gauntlette-quality-check → /gauntlette-human-review → /gauntlette-ship-it

Legacy aliases still work:
- `/survey-and-plan` and `/help-me-plan` point to `/gauntlette-start`
- `/ceo-review`, `/design-review`, and `/eng-review` work, plus the older `/product-review`, `/ux-review`, and `/arch-review`
- Unprefixed review/build commands still work, but the `/gauntlette-*` names are preferred

1. /gauntlette-start — Create the design doc + active plan, orient on codebase, run the planning interview
2. /gauntlette-ceo-review — Challenge the idea itself (scope, value, risk)
3. /gauntlette-design-review — Visual design review with wireframes and state diagrams
4. /gauntlette-eng-review — Engineering review with Mermaid + ASCII diagrams, failure modes, test plan
5. /gauntlette-fresh-eyes — Independent adversarial review, fresh context
6. /gauntlette-cso-review — [OPTIONAL] Security audit: secrets, supply chain, auth, injection, infra
7. /gauntlette-implement — Build the feature from the plan
8. /gauntlette-code-review — Post-implementation adversarial review
9. /gauntlette-quality-check — E2E browser QA with diff-aware automation
10. /gauntlette-human-review — Checklist for human: verify fixes, authorize deploys, meatspace tasks
11. /gauntlette-ship-it — Test, version bump, changelog, merge, ship
```

If a plan exists, also print:

```
Plan: {path to plan file}
Branch: {branch}
```

If no plan exists, print:

```
No active plan. Run /gauntlette-start to begin.
```

That's it. Don't explain what each skill does beyond the one-liner. Don't offer to run anything. Just print and stop.
