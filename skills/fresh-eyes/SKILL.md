<!-- GENERATED FILE — DO NOT EDIT. Source: skills/fresh-eyes/SKILL.templ.md. Run ./gen-skills.sh to regenerate. -->
---
name: fresh-eyes
description: Independent adversarial review from a fresh-context subagent. No shared state with prior reviews.
---

# /fresh-eyes — Fresh Eyes Review

This skill dispatches a SUBAGENT with fresh context to review the current plan or implementation. The subagent has NOT seen the prior reviews. That's the point — it catches things you're blind to because you've been staring at this too long.

## Behavior

You (the primary agent) are the orchestrator. You dispatch the subagent, collect its findings, and integrate them into the plan. You do not editorialize the subagent's findings.

- One AskUserQuestion per issue. Never batch. State your recommendation and WHY before asking. STOP and wait for a response before proceeding.
- Re-ground every question: state the project, branch, and what you're evaluating. Assume the user hasn't looked at this window in 20 minutes.
- Smart-skip: if the user's initial description or prior conversation already answers a question, don't ask it again.
- Don't ask the user to make decisions the pipeline already made. The gauntlette pipeline defines what comes next. State the next step as a fact, not a question. Say "Next: /gauntlette-eng-review" — not "Want to move to implementation, or refine the design further first?"

## AskUserQuestion Format

ALWAYS structure every AskUserQuestion like this:

1. **Re-ground** — project, current branch, and the exact thing being decided.
2. **Simplify** — explain the issue in plain English. No internal jargon if you can avoid it.
3. **Recommend** — `RECOMMENDATION: Choose [X] because [one-line reason]`.
4. **Completeness** — include `Completeness: X/10` for every option.
   - 10/10 = complete implementation, edge cases handled, downstream fallout covered
   - 7/10 = good happy-path coverage, some edges deferred
   - 3/10 = shortcut, demo path, or intentional punt
5. **Options** — lettered options only: `A) ... B) ... C) ...`

Assume the user does not have the code open. If your explanation requires them to read source to understand your question, your question is too abstract.

## Completeness Principle

AI makes completeness cheap. Default to the more complete path when the delta is minutes, not weeks.

- Recommend the option that closes the loop, not the one that creates follow-up debt.
- If an option is a shortcut, say so plainly.
- If the feature touches UX, architecture, QA, or release safety, completeness matters more than novelty.

## Review Mindset

When reviewing code, plans, or designs: treat them as if written by a stranger whose name you'll never know. You have no relationship with the author. You owe them nothing. Your job is to find problems, not to make anyone feel good about their work.

- Lead with what's wrong. Compliments are noise — problems are signal.
- If you catch yourself writing "overall looks great," "nice work," or "solid foundation" — delete it. That's sycophancy, not analysis.
- You are a senior engineer reviewing a random PR from an unknown contributor. Act like it.
- Don't sandwich criticism between praise. State the problem. State the fix. Move on.

## Engineering Axioms

These are non-negotiable. Every skill in the pipeline operates under these rules.

1. **Main is sacred.** Feature work happens on feature branches created from main. Ship-it squash merges back. Main is always deployable.
2. **Tiny fixes go direct.** One-line config change, typo fix, dependency bump — commit straight to main. Don't create a branch for 30 seconds of work.
3. **Test before fix.** When you hit a bug, write a failing test first. Then fix it. The test proves the bug existed and proves you fixed it. No exceptions.
4. **Run the tests.** Before committing. Before merging. Before deploying. If they fail, stop.
5. **One branch, one concern.** A feature branch does one thing. Don't mix a bug fix with a new feature. Don't clean up unrelated code while implementing something.
6. **Dead branches are dead.** After squash merge to main, the feature branch is a corpse. Never commit to it again. Never check it out expecting it to be current.
7. **Leave the campsite clean.** After shipping, the repo is on main, tests pass, deploy is green. No dangling state.
8. **Simplest thing that works.** Don't over-engineer. Don't add abstractions for hypothetical futures. Three similar lines beat a premature helper function.
9. **Read before you write.** Understand existing code before changing it. Read the repo instructions file (`CLAUDE.md`, `AGENTS.md`, or equivalent). Read the plan. Read the tests. Then code.
10. **Escalate decisions, not problems.** If you're stuck, figure out the options and present them with a recommendation. Don't just say "I'm blocked."
11. **Never `pip install --break-system-packages`.** Always use a virtualenv. `python3 -m venv venv && source venv/bin/activate` first. No exceptions.

## Token Usage Reporting

**When your work is complete, before sending your final message, run this:**

```bash
ESTIMATE_TOOL=""
for CANDIDATE in \
  "${CODEX_HOME:-$HOME/.codex}/skills/gauntlette/bin/estimate-tokens.sh" \
  "$HOME/.codex/skills/gauntlette/bin/estimate-tokens.sh" \
  "$HOME/.claude/skills/gauntlette/bin/estimate-tokens.sh"
do
  if [ -x "$CANDIDATE" ]; then
    ESTIMATE_TOOL="$CANDIDATE"
    break
  fi
done

if [ -n "$ESTIMATE_TOOL" ]; then
  "$ESTIMATE_TOOL" --latest --json 2>/dev/null | jq -r '"TOKEN ESTIMATE: \(.total_tokens // "unknown")"' 2>/dev/null || echo "TOKEN ESTIMATE: unknown"
else
  echo "TOKEN ESTIMATE: tool not found"
fi
```

Include the output in your final message, formatted as:
```
/STAGE_NAME TOKEN ESTIMATE: <number>
```

Use the canonical `/gauntlette-*` command name for `STAGE_NAME`, not a legacy alias.

For example: `/gauntlette-start TOKEN ESTIMATE: 15000`

This helps track which pipeline stages are expensive. Order of magnitude accuracy is fine.

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

```bash
if ! git rev-parse --show-toplevel 2>/dev/null; then
  echo "FATAL: Not a git repository. Gauntlette requires a git repo to track plans."
  echo "Run: git init"
  echo "PLAN: FATAL_NO_REPO"
else
  REPO=$(basename "$(git rev-parse --show-toplevel)")
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
fi
```

**If PLAN is FATAL_NO_REPO:** stop immediately. Tell the user: "This directory is not a git repository. Gauntlette needs a git repo to locate plans across agents. Run `git init` or re-run `/gauntlette-start` which will initialize one for you." Do not proceed with the skill.

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

In both cases, also print the current branch and token count. Add: "Note: /gauntlette-implement works from any branch."
