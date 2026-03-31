<!-- GENERATED FILE — DO NOT EDIT. Edit SKILL.md.tmpl instead. Run ./gen-skills.sh to regenerate. -->
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
- One AskUserQuestion per issue. Never batch. State your recommendation and WHY before asking. STOP and wait for a response before proceeding.
- Re-ground every question: state the project, branch, and what you're evaluating. Assume the user hasn't looked at this window in 20 minutes.
- Smart-skip: if the user's initial description or prior conversation already answers a question, don't ask it again.
- Don't ask the user to make decisions the pipeline already made. The gauntlette pipeline defines what comes next. State the next step as a fact, not a question. Say "Next: /arch-review" — not "Want to move to implementation, or refine the design further first?"

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
9. **Read before you write.** Understand existing code before changing it. Read the CLAUDE.md. Read the plan. Read the tests. Then code.
10. **Escalate decisions, not problems.** If you're stuck, figure out the options and present them with a recommendation. Don't just say "I'm blocked."
11. **Never `pip install --break-system-packages`.** Always use a virtualenv. `python3 -m venv venv && source venv/bin/activate` first. No exceptions.

## Process

### Step 0: Pre-flight

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

Detect and run the project's test suite:

```bash
# Detect test infrastructure
[ -f package.json ] && grep -q '"test"' package.json 2>/dev/null && echo "TEST_CMD: npm test"
[ -f Makefile ] && grep -q '^test:' Makefile 2>/dev/null && echo "TEST_CMD: make test"
[ -f Gemfile ] && echo "TEST_CMD: bundle exec rake test"
([ -f pytest.ini ] || [ -f pyproject.toml ]) && echo "TEST_CMD: pytest"
[ -f go.mod ] && echo "TEST_CMD: go test ./..."
[ -f Cargo.toml ] && echo "TEST_CMD: cargo test"
ls jest.config.* vitest.config.* 2>/dev/null && echo "TEST_CMD: npx vitest run"
```

Run the detected test command. If multiple test suites exist, run them all.

**If tests fail:** Classify each failure:

1. **In-branch failure** — the failing test or the code it tests was modified on this branch. **STOP.** These must be fixed before shipping.
2. **Pre-existing failure** — neither the test file nor the code it tests was modified. Use AskUserQuestion:
   - Show the failures
   - Options: A) Fix now  B) Skip — I know about this, ship anyway
   - When ambiguous, default to in-branch (safer).

**If all pass:** Note the counts, continue.

**If no test infrastructure found:** Note "No tests detected" and continue.

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

By the time /ship-it runs, the branch has been through the full Gauntlette pipeline including /human-review. Deploy and land the code.

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

1. Detect and run the project's deploy command:
   ```bash
   # Detect deploy infrastructure
   [ -f deploy.sh ] && echo "DEPLOY_CMD: ./deploy.sh"
   [ -f Makefile ] && grep -q '^deploy:' Makefile 2>/dev/null && echo "DEPLOY_CMD: make deploy"
   [ -f fly.toml ] && echo "DEPLOY_CMD: fly deploy"
   [ -f vercel.json ] && echo "DEPLOY_CMD: vercel --prod"
   [ -f netlify.toml ] && echo "DEPLOY_CMD: netlify deploy --prod"
   [ -f render.yaml ] && echo "DEPLOY_CMD: render deploy"
   ```

   Run the detected deploy command. If multiple are found, prefer `deploy.sh` (project-specific) over generic platform CLIs.

   **If deploy fails:** **STOP.** Do not push master. Report the failure.

   **If no deploy infrastructure found:** Skip deploy, continue to push.

2. Push master to origin:
   ```bash
   git push origin master
   ```

   **If push fails:** **STOP.** Do not force push. Report the failure.

3. **Stay on master.** Do NOT checkout back to the feature branch. The repo must be left on master/main when ship-it completes.

### Step 11: Post-deploy sanity check

**This step is mandatory if `PROD-SANITY-CHECK.md` exists in the repo root.**

1. Check for the file:
   ```bash
   [ -f PROD-SANITY-CHECK.md ] && echo "SANITY_CHECK: found" || echo "SANITY_CHECK: none"
   ```

2. If found, read it and execute the smoke tests described in it. These are typically short Playwright CLI commands that load production pages and verify basic functionality.

3. **If any sanity check fails: STOP.** Report the failure immediately. Production is broken. Do not mark the ship as successful.

4. If all checks pass, note it in the output.

If `PROD-SANITY-CHECK.md` does not exist, skip silently.

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
