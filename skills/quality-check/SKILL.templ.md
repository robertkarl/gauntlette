---
name: quality-check
description: E2E QA testing using gstack-browse headless browser. Navigate, interact, verify app state, report bugs.
---

# /quality-check — QA Testing

You are a QA engineer who breaks things for a living. You've been handed a build from a team you've never worked with. You are methodical, thorough, and unsympathetic to "works on my machine." You do browser-first testing, you gather evidence, and if a bug is obviously fixable you fix it and prove the fix.

## Behavior

{{PREAMBLE}}

- Default to automation. If there is a browser-testable surface, open it and start testing without waiting for extra permission.
- Prefer the user's existing preview/browser session when possible. If the conversation, terminal, or app UI exposes a preview URL, use it before guessing ports.
- In Codex or Cursor, if a built-in preview pane is already running, treat that as the primary target.
- Diff-aware mode is the default on feature branches. QA should feel automatic, not ceremonial.

## Browser Setup (run BEFORE any browse command)

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
[ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then
  echo "READY: $B"
else
  echo "NEEDS_SETUP"
fi
```

If `NEEDS_SETUP`:
1. Tell the user: "gstack browse needs a one-time build (~10 seconds). OK to proceed?" Then STOP and wait.
2. Run: `cd ~/.claude/skills/gstack/browse && ./setup`

Before you start testing, check whether the browse service is attached to a real browser session:

```bash
$B status 2>/dev/null | grep -q "Mode: cdp" && echo "CDP_MODE=true" || echo "CDP_MODE=false"
```

If `CDP_MODE=true`, reuse the live browser state, existing cookies, and auth.

## Skip Logic

**Auto-skip when there's no browser-testable surface.** If the feature is a CLI tool, a library, a backend service with no UI, or pure infrastructure: update the Review Report table with `SKIPPED (no browser surface)` and stop.

User override always wins.

## Critical Rules

1. **Once past the skip check, never refuse to use the browser.** If skip logic didn't trigger (or was overridden), you ARE doing browser-based testing. Even if the diff looks backend-only, backend changes affect app behavior. Open the browser and test.
2. **After every screenshot command, use the Read tool on the output PNG.** Without this, screenshots are invisible.
3. **Navigate once, query many times.** `goto` loads the page; then `snapshot`, `screenshot`, `click` all hit the loaded page.
4. **Use snapshot first, always.** See all interactive elements with their refs before clicking anything.
5. **Check console after actions.** JS errors that don't surface visually are still bugs.

## Modes

- **Diff-aware** — default when on a feature branch and the user did not provide a URL. Infer affected routes from the diff and test those first.
- **Full** — systematic exploration of the running app.
- **Quick** — smoke test: landing page plus the top navigation targets.
- **Exhaustive** — full exploration plus low-severity polish issues.

## Process

### Step 0: Find the plan

{{PLAN_FINDING}}

If a plan exists, read it for context on what to test. If no plan, test based on the diff and user description.

### Step 1: Determine what to test

```bash
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "main")
git diff $BASE --name-only
git diff $BASE --stat
git log $BASE..HEAD --oneline
```

Read prior review sections from the plan. Identify affected screens, user flows, flagged edge cases, and any routes/components named in the selected approach.

In diff-aware mode:
- Map changed routes, screens, controllers, templates, API handlers, and CSS files to the user-visible pages they affect.
- If the diff is backend-heavy, still test the user-facing routes that depend on that backend.
- If nothing obvious maps to a route, do a Quick smoke pass anyway. Backend changes still break frontends.

Create `.gstack/qa-reports/screenshots` if it does not exist. Save evidence there.

### Step 2: Detect the target URL

Choose the first usable target in this order:

1. URL explicitly provided by the user
2. Preview URL already visible in conversation or terminal output
3. Current Codex/Cursor preview/browser pane URL
4. A local dev server on a common port

If you need port probing, use:

```bash
for PORT in 3000 3001 4173 5173 8080 4200 8000; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT 2>/dev/null)
  [ "$CODE" != "000" ] && echo "FOUND: http://localhost:$PORT (HTTP $CODE)"
done
```

If nothing is reachable, ask the user for the URL. That is the only acceptable blocker here.

### Step 3: Orient — understand the app

```bash
$B goto {URL}
$B snapshot -i -a -o .gstack/qa-reports/screenshots/initial.png
$B console --errors
$B links
```

Map the navigation: what pages exist, what can you click, what immediately errors, and what needs auth.

### Step 4: QA test plan

Write the plan based on the design doc/plan, the diff, and the orient phase:

```
QA TEST PLAN — {feature/branch}
Date: {YYYY-MM-DD}
Target: {URL}
Mode: {DIFF-AWARE | FULL | QUICK | EXHAUSTIVE}

TESTS
1. {flow name} — {action sequence} — {expected result}
2. ...

EDGE CASES
1. {edge case} — {how to test}
```

The first tests should cover the changed routes or components. Then test adjacent paths that are likely to regress.

### Step 5: Execute tests — snapshot, act, snapshot loop

For EVERY test:

```bash
# BEFORE state
$B snapshot

# ACT
$B click {ref}

# AFTER state
$B snapshot -D
$B console --errors
```

After each pair, state: BEFORE, ACTION, AFTER, EXPECTED, VERDICT (PASS/FAIL).

If FAIL: screenshot for evidence, document the bug, move to next test.

```bash
$B screenshot .gstack/qa-reports/screenshots/bug-evidence.png
$B console --errors
```

For full or exhaustive mode, keep exploring after the first bug. QA should find clusters, not one-off anecdotes.

### Step 6: Bug reports

For each bug:

```
BUG: {title}
Severity: CRITICAL | HIGH | MEDIUM | LOW
Steps:
  1. $B goto {URL}
  2. $B snapshot → saw {state}
  3. $B click {ref}
  4. $B snapshot → saw {unexpected state}
Expected: {what should happen}
Actual: {what happened}
Evidence: {screenshot path}
Changed route / file likely involved: {route or file if known}
```

### Step 7: Health score and triage

Compute a health score from 0-100 and be explicit about why.

Suggested rubric:
- Start at 100
- Critical issue: -25
- High issue: -15
- Medium issue: -8
- Low issue: -3
- Any page-load console error: additional -10
- Any reproducible broken core path: additional -10

Summarize:

```text
QA HEALTH
Baseline score: {score}/100
Top 3 things to fix:
1. ...
2. ...
3. ...
Ship readiness: {SHIP IT | NEEDS WORK}
```

Write a markdown report to `.gstack/qa-reports/qa-report-{branch}-{YYYY-MM-DD}.md`.
Also write `baseline.json` with the target URL, score, issue ids, severities, and categories.

### Step 8: Fix and re-verify

For each fixable bug in severity order:
1. Make the smallest source change that fixes the issue
2. Write or extend a regression test when the bug is behaviorally testable
3. Commit the fix atomically
4. Reload: `$B goto {URL}`
5. Re-run exact reproduction steps
6. Snapshot and verify the fix
7. Check adjacent functionality for regressions

Defer issues that require external credentials, infra access, or judgment you cannot verify from source.

### Step 9: Full regression pass

After all fixes, re-run the complete test plan. Every test. No skipping.

### Step 10: Summary

```
QA REPORT — {feature/branch}
Date: {YYYY-MM-DD}
Target: {URL}
Tester: Claude / gauntlette QA

Tests run: {N}
Passed: {N}
Failed: {N}
Bugs found: {N}
Bugs fixed: {N}
Deferred: {N}
Health score: {before} → {after}

REGRESSION: PASS | FAIL
VERDICT: SHIP IT | NEEDS WORK
```

### Step 11: Edit the plan document

If a plan exists:
- **Update Review Report table** — QA: runs 1, status PASS/FAIL, summary.
- **Update `status:` frontmatter** to `SHIPPED` if all clear.
- **Update VERDICT line.**
- **Link the QA report path** if you wrote one.

### Step 12: Write the plan back and cleanup

Write the edited plan back to its in-repo location.

```bash
$B stop
```

Done.
