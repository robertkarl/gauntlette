---
name: fresh-eyes
description: Independent adversarial review from a fresh-context subagent. No shared state with prior reviews.
---

# /fresh-eyes — Fresh Eyes Review

This skill dispatches a SUBAGENT with fresh context to review the current plan or implementation. The subagent has NOT seen the prior reviews. That's the point — it catches things you're blind to because you've been staring at this too long.

## Behavior

You (the primary agent) are the orchestrator here. You dispatch the subagent, collect its findings, and present them alongside any tensions with prior reviews. You do not editorialize the subagent's findings.

## Process

### Step 1: Gather context for the subagent

```bash
# Collect the current state
BRANCH=$(git branch --show-current)
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "main")

# Check what exists
ls .claude/reviews/ 2>/dev/null
git diff origin/main --stat 2>/dev/null || git diff main --stat 2>/dev/null
```

Determine what to review:
- If there's a diff (implementation exists): review the diff
- If there are review files but no diff (plan stage): review the plan files
- If neither: tell the user there's nothing to review

### Step 2: Dispatch subagent

Use the Agent tool to dispatch a subagent with this prompt. Do NOT include any findings from prior reviews in the subagent prompt:

**If reviewing a diff:**

> Read the diff for this branch with `git diff origin/{base}`. You are a hostile code reviewer. Your job is to find ways this code will fail in production.
>
> Look for: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors that produce wrong results silently, error handling that swallows failures, trust boundary violations, and missing input validation.
>
> For each finding:
> - Describe the problem in one sentence
> - Show the specific code or pattern
> - Classify as CRITICAL (will break), IMPORTANT (likely to break), or MINOR (could break)
> - Classify as FIXABLE (you know the fix) or INVESTIGATE (needs human judgment)
>
> No compliments. No "overall the code looks good." Just the problems.
>
> If you find nothing wrong, say "No issues found" and stop. Do not fabricate findings.

**If reviewing a plan:**

> Read the files in `.claude/reviews/` for this project. You are a hostile technical reviewer. Your job is to find flaws in this plan that will cause problems during implementation or in production.
>
> Look for: missing error handling, unstated assumptions, scope creep, over-engineering, under-engineering, security gaps, scalability issues, and things that sound good in a doc but don't work in practice.
>
> For each finding, classify as CRITICAL / IMPORTANT / MINOR and FIXABLE / INVESTIGATE.
>
> No compliments. Just the problems. If the plan is solid, say "No issues found" and stop.

### Step 3: Present findings

```
FRESH EYES REVIEW — {feature/branch name}
Date: {YYYY-MM-DD}
Type: {DIFF REVIEW | PLAN REVIEW}
Subagent: Claude (fresh context, no prior review state)

FINDINGS
{Present subagent findings verbatim, organized by severity}

CRITICAL
- ...

IMPORTANT
- ...

MINOR
- ...
```

### Step 4: Cross-review tension analysis

Read the prior review files in `.claude/reviews/`. Compare the subagent's findings against them. Flag disagreements:

```
CROSS-REVIEW TENSIONS

{Topic}: Prior review ({which file}) said X. Outside voice says Y.
Assessment: {who's right and why, or "genuinely ambiguous — human decision needed"}
```

If there are no tensions: "No cross-review tensions found. Prior reviews and outside voice are aligned."

### Step 5: Write to disk

```bash
mkdir -p .claude/reviews
DATE=$(date +%Y-%m-%d)
```

Write to `.claude/reviews/fresh-eyes-{DATE}.md`.

### Step 6: Recommend next step

If reviewing a plan: "Reviews complete. Implement the feature, then run `/code-review` on the diff."

If reviewing a diff: "Run `/code-review` for the structured code review with execution diagrams."
