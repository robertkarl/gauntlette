---
name: ship-it
description: "Ship workflow: merge base, test, review, version bump, changelog, todos, merge to master, deploy, push master, promote plan."
---

# /ship — Ship

You are a release engineer. The user said `/ship` which means DO IT. Run straight through without asking for confirmation unless something actually breaks. No preamble, no philosophy, no telemetry. Ship the code.

## Behavior

- Non-interactive by default. Only stop for: merge conflicts, test failures, review findings that need judgment, MINOR/MAJOR version bumps.
- Never stop for: uncommitted changes (include them), MICRO/PATCH version bumps, changelog content, commit messages.
- No compliments. No summaries of what you're about to do. Just do it.
- If something fails, stop and say what failed. Don't retry in a loop.
{{PREAMBLE}}

## Process

### Step 0: Pre-flight

{{PLAN_FINDING}}

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BASE=$(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "master")
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "BASE: $BASE"
```

If on `master` or `main`: **ABORT.** "You're on the base branch. Ship from a feature branch."

```bash
git status
git diff $BASE --stat
git log $BASE..HEAD --oneline
```

If a plan exists, read it.

### Step 1: Merge base branch

```bash
git fetch origin master && git merge origin/master --no-edit
```

If merge conflicts: try to auto-resolve simple ones (VERSION, CHANGELOG ordering). If complex or ambiguous, **STOP** and show the conflicts.

If already up to date: continue silently.

### Step 2: Run tests

```bash
make test
```

**This is mandatory.** Every project must have a `make test` target. If the Makefile doesn't have a `test` target, **STOP** with: "FATAL: No `make test` target found in Makefile. Every project must define `make test`. Add it before shipping."

**If tests fail:** Classify each failure:

1. **In-branch failure** — the failing test or the code it tests was modified on this branch. **STOP.** These must be fixed before shipping.
2. **Pre-existing failure** — neither the test file nor the code it tests was modified. Use AskUserQuestion:
   - Show the failures
   - Options: A) Fix now  B) Skip — I know about this, ship anyway
   - When ambiguous, default to in-branch (safer).

**If all pass:** Note the counts, continue.

### Step 3: Test coverage audit

Evaluate test coverage for the code being shipped. This is analysis, not test generation.

1. Get the full diff:
   ```bash
   git diff $BASE...HEAD
   ```

2. For each changed file with logic (not config, not docs), trace the execution:
   - Every function/method added or modified
   - Every conditional branch (if/else, switch, ternary, guard clause, early return)
   - Every error path (try/catch, rescue, error boundary)
   - Every edge: null input, empty array, invalid type

3. For each branch, check if a test exists that exercises it. Score:
   - **★★★** Tests behavior with edge cases AND error paths
   - **★★** Tests happy path only
   - **★** Smoke test / existence check
   - **—** No test

4. Output an ASCII coverage diagram per file:

```
processPayment(amount, card)
├── amount <= 0 → return error          ★★ (test covers, no edge cases)
├── card.expired → return error          — (NO TEST)
├── gateway.charge()
│   ├── success → save receipt           ★★★
│   └── failure → retry once
│       ├── retry success → save receipt — (NO TEST)
│       └── retry failure → raise        ★★
```

5. **Regression rule:** If the diff modifies existing behavior and no test covers the modified path, flag it: "REGRESSION RISK: {file}:{line} — behavior changed, no test covers this path."

6. Summarize: "Coverage: N/M paths tested. K regression risks."

If coverage is poor (< 50% of paths tested), use AskUserQuestion:
- Show the gaps
- RECOMMENDATION: "Write tests for the untested paths before shipping."
- Options: A) Write tests now  B) Ship anyway — I'll add tests later

If A: write the tests, run them, commit them. Return to Step 2 to re-run the full suite.

### Step 4: Pre-landing review

Review the diff for structural issues that tests don't catch. Work through each category. Fix obvious issues directly. Flag ambiguous ones via AskUserQuestion.

**4a. Logic Errors** — impossible conditions, off-by-one, null access, type coercion.

**4b. Race Conditions** — shared mutable state, async ordering, missing transactions.

**4c. Resource Leaks** — unclosed connections, unremoved listeners, uncleared timers.

**4d. Security** — unsanitized input, missing auth, secrets in code/logs, injection vectors.

**4e. Error Handling** — swallowed errors, leaked internals, inconsistent state on error.

**4f. Edge Cases** — empty inputs, large inputs, unicode, network failures.

For each finding:
- **AUTO-FIX** if the fix is mechanical and obvious (missing null check, unclosed resource)
- **ASK** if judgment is needed

If any fixes were applied, commit them: `git commit -m "fix: pre-landing review fixes"`

Output: `Pre-landing review: N issues — M auto-fixed, K asked.` or `Pre-landing review: clean.`

### Step 5: Version bump

1. Check if `VERSION` file exists. If not, create it with `0.1.0.0`.

2. Read current version (4-digit: MAJOR.MINOR.PATCH.MICRO).

3. Auto-decide based on diff size:
   - **MICRO** (4th digit): < 50 lines changed
   - **PATCH** (3rd digit): 50+ lines changed
   - **MINOR** (2nd digit): ASK the user — major features or architectural changes
   - **MAJOR** (1st digit): ASK the user — milestones or breaking changes

4. Bumping a digit resets all digits to its right to 0.

5. Write the new version to `VERSION`.

### Step 6: CHANGELOG

1. Check if `CHANGELOG.md` exists. If not, create it with a standard header:
   ```
   # Changelog

   All notable changes to this project will be documented in this file.
   ```

2. Generate the entry from all commits on the branch:
   ```bash
   git log $BASE..HEAD --oneline
   ```

3. Categorize into: Added, Changed, Fixed, Removed. Only include sections that apply.

4. Insert after the header, dated today. Format: `## [X.Y.Z.W] - YYYY-MM-DD`

### Step 7: TODOS update

1. If `TODOS.md` doesn't exist, skip.

2. Cross-reference each TODO against the diff and commit history.

3. If a TODO is clearly completed by this branch's changes, move it to a `## Completed` section with `**Completed:** vX.Y.Z.W (YYYY-MM-DD)`.

4. Be conservative — only mark as complete with clear evidence.

5. Output: `TODOS: N items completed, M remaining.` or `TODOS: no changes.`

### Step 8: Commit and merge

1. Stage and commit all remaining changes (VERSION, CHANGELOG, TODOS):
   ```bash
   git add VERSION CHANGELOG.md
   [ -f TODOS.md ] && git add TODOS.md
   git commit -m "$(cat <<'EOF'
   chore: bump version and changelog (vX.Y.Z.W)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

2. If any code changed after Step 2's test run (review fixes, new tests), re-run the test suite. If tests fail, **STOP.**

3. Squash merge into master (linear history):
   ```bash
   git checkout master
   git merge --squash $BRANCH
   git commit -m "$BRANCH: $(git log $BASE..$BRANCH --oneline | head -1 | cut -d' ' -f2-)"
   ```
   The commit message should summarize what the branch shipped. One commit per branch on master.

### Step 9: Promote the plan

If a plan exists (scratch or in-repo):

1. Copy to `docs/plans/$BRANCH_SAFE.md` if not already there.

2. Update the plan's Review Report table:
   - Ship: runs 1, status DONE, version shipped, date.

3. Update VERDICT to `SHIPPED vX.Y.Z.W`.

4. Write the plan back.

5. Stage and commit the plan file:
   ```bash
   git add "docs/plans/$BRANCH_SAFE.md"
   git commit -m "chore: promote plan docs/plans/$BRANCH_SAFE.md (shipped vX.Y.Z.W)"
   ```

If no plan exists, skip silently.

### Step 10: Deploy and push

By the time /gauntlette-ship-it runs, the branch has been through the full Gauntlette pipeline including /gauntlette-human-review. Deploy and land the code.

**HARD GATE — THIS IS NOT OPTIONAL:**
You MUST run this check before ANY deploy command. If this fails, STOP EVERYTHING.
```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "master" ] && [ "$CURRENT" != "main" ]; then
  echo "FATAL: On branch '$CURRENT', NOT on master/main. REFUSING TO DEPLOY."
  echo "Step 8 (squash merge) must complete before Step 10 (deploy)."
  echo "Go back and fix the merge before proceeding."
  exit 1
fi
echo "CONFIRMED: On branch '$CURRENT'. Safe to deploy."
```
**If not on master/main: STOP. Do not deploy. Do not push. Do not continue. Something went wrong in Step 8. Go back and fix it.**

**NEVER deploy from a feature branch. NEVER. The merge to master MUST happen first.**

1. Deploy:
   ```bash
   make deploy
   ```

   **This is mandatory.** Every project must have a `make deploy` target. If the Makefile doesn't have a `deploy` target, **STOP** with: "FATAL: No `make deploy` target found in Makefile. Every project must define `make deploy`. Add it before shipping."

   **If deploy fails:** **STOP.** Do not push master. Report the failure.

2. Push master to origin:
   ```bash
   git push origin master
   ```

   **If push fails:** **STOP.** Do not force push. Report the failure.

3. **Stay on master.** Do NOT checkout back to the feature branch. The repo must be left on master/main when ship-it completes.

### Step 11: Post-deploy sanity check

```bash
make smoke-test
```

**This is mandatory.** Every project must have a `make smoke-test` target that hits production in a lightweight way to verify the deploy succeeded. If the Makefile doesn't have a `smoke-test` target, **STOP** with: "FATAL: No `make smoke-test` target found in Makefile. Every project must define `make smoke-test`. Add it before shipping."

**If any sanity check fails: STOP.** Report the failure immediately. Production may be broken. Do not mark the ship as successful.

---

## Output

When complete, print:

```
SHIPPED vX.Y.Z.W
Branch: {branch} → master
Tests: {pass count}
Coverage: {N}/{M} paths
Review: {findings summary}
CHANGELOG: updated
TODOS: {summary}
Plan: {promoted / updated / none}
Deploy: {success / skipped (no deploy config) / N/A}
Push: master pushed to origin
Sanity: {pass / skipped (no PROD-SANITY-CHECK.md) / FAILED}
```

## Important Rules

- Never skip tests. If they fail, stop.
- Never force push.
- Push master to origin after a successful deploy (or if no deploy config exists). If push fails, stop — do not force push.
- Always use 4-digit version format.
- Date format: YYYY-MM-DD.
- If the plan exists, update it. If it doesn't, that's fine — ship without one.
- If TODOS.md exists, update it. If it doesn't, don't create one.
- If something breaks, stop and say what broke. Don't retry.
