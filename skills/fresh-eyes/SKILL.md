---
name: fresh-eyes
description: Independent adversarial review from a fresh-context subagent. No shared state with prior reviews.
---

# /fresh-eyes — Fresh Eyes Review

This skill dispatches a SUBAGENT with fresh context to review the current plan or implementation. The subagent has NOT seen the prior reviews. That's the point — it catches things you're blind to because you've been staring at this too long.

## Behavior

You (the primary agent) are the orchestrator. You dispatch the subagent, collect its findings, and integrate them into the plan. You do not editorialize the subagent's findings.

## Skip Logic

**Auto-skip for small changes (< 50 lines).** Small changes don't benefit from fresh-context review.

```bash
DIFF_LINES=$(git diff main...HEAD --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
echo "DIFF: $DIFF_LINES lines"
```

If < 50 lines changed: update the Review Report table with `SKIPPED (<50 lines)` and stop.

User override always wins.

## Process

### Step 0: Find the plan

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
PLAN_INREPO=".claude/reviews/$BRANCH.md"
PLAN_SCRATCH="$HOME/.gauntlette/$REPO/$BRANCH.md"

if [ -f "$PLAN_INREPO" ]; then
  echo "PLAN: $PLAN_INREPO (promoted)"
elif [ -f "$PLAN_SCRATCH" ]; then
  echo "PLAN: $PLAN_SCRATCH (scratch)"
else
  echo "PLAN: NONE"
fi
```

If PLAN is NONE: "No plan found for branch '{branch}'. Run /survey first."

Read the full plan document.

### Step 1: Determine what to review

- If there's a diff (implementation exists): review the diff
- If there are review sections but no diff (plan stage): review the plan
- If neither: tell the user there's nothing to review

### Step 2: Dispatch subagent

Use the Agent tool to dispatch a subagent. Do NOT include any findings from prior reviews in the subagent prompt.

**If reviewing a diff:**

> Read the diff for this branch with `git diff main...HEAD`. You are a hostile code reviewer. Your job is to find ways this code will fail in production. Look for: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors, error handling that swallows failures, trust boundary violations. For each finding: describe the problem, show the specific code, classify as CRITICAL / IMPORTANT / MINOR and FIXABLE / INVESTIGATE. No compliments. If you find nothing wrong, say "No issues found."

**If reviewing a plan:**

> Read the file at {plan path}. You are a hostile technical reviewer. Find flaws that will cause problems during implementation or in production. Look for: missing error handling, unstated assumptions, scope creep, over-engineering, under-engineering, security gaps, scalability issues, things that sound good in a doc but don't work in practice. Classify each as CRITICAL / IMPORTANT / MINOR and FIXABLE / INVESTIGATE. No compliments. If the plan is solid, say "No issues found."

### Step 3: Integrate findings into the plan

**Edit the plan, don't create a separate file.**

- **Integrate findings into the relevant sections** — if the subagent found an error path gap, add it to the Architecture section. If it found a scope issue, update the Scope table. Don't silo findings into a "Fresh Eyes" section.
- **For tensions between sections:** add inline notes: "> **[fresh-eyes]:** Prior review said X, but this contradicts Y because Z."
- **Add to Resolved Decisions** if the fresh-eyes findings resolved ambiguities.
- **Update Review Report table** — Fresh Eyes: runs 1, status CLEAR, 1-line summary of findings count by severity.
- **Update VERDICT line.**

### Step 4: Write the plan back

Write the edited plan back to the same location you read it from.

If reviewing a plan: "Fresh eyes complete. Run /implement to start building."

If reviewing a diff: "Fresh eyes complete. Run /code-review for structured review with execution diagrams."
