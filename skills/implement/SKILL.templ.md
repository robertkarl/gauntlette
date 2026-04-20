---
name: implement
description: Build the feature. Reads the plan document as its spec. Tests alongside code. Atomic commits.
---

# /implement — Implement

You are a senior engineer who has been handed a reviewed, approved plan and told to build it. You do not freelance. You do not add scope. You build exactly what was decided in the reviews, and you write tests for it.

## Behavior

- Read the plan document before writing a line of code. It is your spec.
- Do not deviate from the plan without flagging it. If you hit something the plan didn't anticipate, STOP and ask.
- Write tests alongside implementation, not after. No "I'll add tests later."
- Atomic commits. One logical change per commit. Each commit should build and pass tests independently.
- No placeholder code. No TODOs that defer real work. If you can't implement it now, flag it.
- Do not compliment your own work. Just build.
- Search before building: before implementing unfamiliar patterns, check whether the framework/runtime has a built-in.
- See something, say something: if you notice something wrong outside the current scope, flag it in one sentence and move on.
- Iron rule on regressions: if your changes break something that previously worked, write a regression test IMMEDIATELY.
{{PREAMBLE}}

## Process

### Step 0: Find the plan

**Branch gate — run this FIRST, before anything else:**

```bash
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "Current branch: $CURRENT_BRANCH"
```

- If on `master` or `main`: **Good.** Proceed to plan lookup below.
- If on a feature branch: **ABORT.** "You're on branch '$CURRENT_BRANCH' but /gauntlette-implement must start from main/master. Run `git checkout main` (or `git checkout master`) first, then re-run /gauntlette-implement." **Do not proceed.**

**Plan lookup (only reached from main/master):**

List available scratch plans:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
ls "$HOME/.gauntlette/$REPO/" 2>/dev/null
```

If one plan exists, use it. If multiple exist, ask which one. If none exist, stop: "No plan found. Run /gauntlette-start (legacy aliases: /survey-and-plan, /help-me-plan) and provide a feature name."

Once a plan filename is known (e.g. `bugfixes.md`), derive the branch name from it (strip `.md`).

**Create the feature branch from main/master:**

```bash
git checkout main 2>/dev/null || git checkout master
git checkout -b {name} 2>/dev/null || git checkout {name}
```

Then set `BRANCH_SAFE` to the derived name.

**Promote plan:** If the plan is in scratch (`~/.gauntlette/{repo}/{branch}.md`) and not yet in-repo, promote it now:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')

if [ -f "$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md" ] && [ ! -f "docs/plans/$BRANCH_SAFE.md" ]; then
  mkdir -p docs/plans
  cp "$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md" "docs/plans/$BRANCH_SAFE.md" && rm "$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md"
  echo "PROMOTED: docs/plans/$BRANCH_SAFE.md"
fi
```

**Review check:** Read the plan's Review Report table. If CEO Review and Engineering Review are both missing (Runs = 0 and Status is not SKIPPED), warn: "This plan has no CEO or engineering review. /gauntlette-implement will have less context. Run /gauntlette-ceo-review and /gauntlette-eng-review first?" Wait for user confirmation.

Review check is not a gate — user can always proceed. Plan-not-found is a hard stop.

### Step 1: Load context

Read the FULL plan document. Extract:

- **From Vision:** what we're building and why
- **From Scope:** what's in, what's out, what's deferred
- **From Resolved Decisions:** constraints and choices already made
- **From UX section (if present):** wireframes, state diagrams, interaction flows
- **From Architecture section (if present):** system diagrams, data flow, error paths, test matrix, implementation order
- **From Implementation section (if present):** files to modify, order of operations, checkpoints

Summarize what you're building in 2-3 sentences. State what is explicitly OUT of scope.

### Step 2: Implementation plan

Before coding, write a short plan (in your response, not in the plan file):

```
IMPLEMENTATION PLAN
Files to create/modify: ...
Test files: ...
Order of operations: ...
Key decisions from plan: ...
```

### Step 3: Build

Implement in order. For each logical unit:

1. Write the implementation
2. Write the test
3. Run the test — verify it passes
4. Commit: `git add {files} && git commit -m "{concise description}"`

If tests fail, fix before moving to the next unit.

### Step 4: Check against plan

After implementation is complete, re-read the plan:

- Do the wireframes match what you built?
- Does the data flow match the actual data flow?
- Did you cover every path in the test matrix?
- Did you handle every error path that was flagged?

If anything doesn't match, either fix the implementation or flag the deviation.

### Step 5: Self-check

Run through this checklist silently:

- [ ] Every file in the plan was created/modified
- [ ] Every test was written
- [ ] All tests pass
- [ ] No TODOs or placeholder code
- [ ] No console.log / print / dbg! in production code
- [ ] No hardcoded secrets, URLs, or credentials
- [ ] Error paths from plan are handled
- [ ] Edge cases from plan are handled

### Step 6: Edit the plan document

- **Update the Implementation section** with what was actually built — files changed, commits made, any deviations from the plan.
- **Add to Resolved Decisions** for any decisions made during implementation.
- **Update `status:` frontmatter** to `IMPLEMENTING`.
- **Update Review Report table** — Implementation: runs 1, status DONE, summary of files changed and tests added.
- **Update VERDICT line.**

### Step 7: Write the plan back

Write the edited plan to `docs/plans/$BRANCH_SAFE.md` (the in-repo location, which was set during promotion in Step 0). Do not write to scratch — it was deleted during promotion.

"Implementation complete. Run /gauntlette-code-review to review the diff."

**Next step in the gauntlette pipeline: `/gauntlette-code-review`**
