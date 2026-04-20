---
name: fresh-eyes
description: Independent adversarial review from a fresh-context subagent. No shared state with prior reviews.
---

# /fresh-eyes — Fresh Eyes Review

This skill dispatches a SUBAGENT with fresh context to review the current plan or implementation. The subagent has NOT seen the prior reviews. That's the point — it catches things you're blind to because you've been staring at this too long.

## Behavior

You (the primary agent) are the orchestrator. You dispatch the subagent, collect its findings, and integrate them into the plan. You do not editorialize the subagent's findings.

{{PREAMBLE}}

**HARD GATE:** Do NOT write any code, create any files outside the plan document, start implementation, or proceed to the next pipeline stage. Your only output is edits to the plan document.

## Skip Logic

**Auto-skip for small changes (< 50 lines).** Small changes don't benefit from fresh-context review.

```bash
BASE=$(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD master 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "HEAD~1")
DIFF_INS=$(git diff $BASE --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DIFF_DEL=$(git diff $BASE --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
DIFF_LINES=$((DIFF_INS + DIFF_DEL))
echo "DIFF: $DIFF_LINES lines (ins: $DIFF_INS, del: $DIFF_DEL)"
```

If < 50 lines changed: update the Review Report table with `SKIPPED (<50 lines)` and stop.

User override always wins.

## Process

### Step 0: Find the plan

{{PLAN_FINDING}}

If PLAN is NONE: "No plan found for branch '{branch}'. Run /gauntlette-start (legacy aliases: /survey-and-plan, /help-me-plan) first."

Read the full plan document.

### Step 1: Determine what to review

- If there's a diff (implementation exists): review the diff
- If there are review sections but no diff (plan stage): review the plan
- If neither: tell the user there's nothing to review

### Step 2: Dispatch subagent

Use the Agent tool to dispatch a subagent. Do NOT include any findings from prior reviews in the subagent prompt.

**If reviewing a diff:**

> Read the diff for this branch with `git diff $(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD master 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || echo HEAD~1)...HEAD`. You are reviewing a PR from an engineer you've never met. You have no relationship with the author. Your job is to find ways this code will fail in production. Look for: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors, error handling that swallows failures, trust boundary violations. For each finding: describe the problem, show the specific code, classify as CRITICAL / IMPORTANT / MINOR and FIXABLE / INVESTIGATE. No compliments. No "overall looks good." If you find nothing wrong, say "No issues found."

**If reviewing a plan:**

> Read the file at {plan path}. You are reviewing a technical plan written by someone you've never met. You have no relationship with the author. Find flaws that will cause problems during implementation or in production. Look for: missing error handling, unstated assumptions, scope creep, over-engineering, under-engineering, security gaps, scalability issues, things that sound good in a doc but don't work in practice. Classify each as CRITICAL / IMPORTANT / MINOR and FIXABLE / INVESTIGATE. No compliments. No "solid foundation." If the plan is actually solid, say "No issues found."

### Step 3: Present findings verbatim

Present the subagent's findings verbatim, organized by severity:

```
FRESH EYES FINDINGS
Subagent: Claude (fresh context, no prior review state)

CRITICAL
- ...

IMPORTANT
- ...

MINOR
- ...
```

**Do NOT auto-apply findings.** The outside voice is informational. The user decides what to act on.

### Step 4: Cross-review tension analysis

Read the plan document. Compare the subagent's findings against existing sections. Surface disagreements:

```
CROSS-REVIEW TENSIONS

{Topic}: Plan says X. Outside voice says Y.
Assessment: {your assessment of who's right, or "genuinely ambiguous — human decision needed"}
```

If no tensions: "No cross-review tensions. Plan and outside voice are aligned."

### Step 5: Walk through findings with the user

For each CRITICAL or IMPORTANT finding, present it as a single AskUserQuestion:

> **Fresh eyes found:** {1-sentence description of the finding}
>
> **The plan currently says:** {what the relevant section says}
>
> **Outside voice argues:** {the subagent's point}
>
> A) Fix it — incorporate this into the plan
> B) Skip — not substantive
> C) Add to deferred — note it but don't fix now

**STOP and wait** for the user's response before moving to the next finding.

MINOR findings: present as a batch at the end. "The outside voice also noted these minor items: {list}. Want me to fix any of them?"

### Step 6: Apply user-approved fixes

For each finding the user approved (option A):
- Edit the relevant section of the plan document
- Add a row to Resolved Decisions if the finding resolved an ambiguity

For skipped findings: do nothing.

For deferred findings: add a note to the Scope table as DEFERRED.

### Step 7: Update Review Report and write back

- **Update Review Report table** — Fresh Eyes: runs 1, status CLEAR, summary (e.g., "14 findings: 3 critical, 5 important, 6 minor. User accepted 10, skipped 4.").
- **Update VERDICT line.**

Write the edited plan back to the same location you read it from.

If reviewing a plan: "Fresh eyes complete. Run /gauntlette-implement to start building."

If reviewing a diff: "Fresh eyes complete. Run /gauntlette-code-review for structured review with execution diagrams."
