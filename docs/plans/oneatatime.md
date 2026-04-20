---
status: SHIPPED
---
# One At A Time — Reduce Prompt Overload in Gauntlette Skills

Created by /survey on 2026-03-28
Branch: master | Repo: gauntlette

## Vision

Gauntlette skills dump multiple questions at the user in a single wall of text. The human at the keyboard has to parse a firehose, figure out which question matters most, and respond to all of them at once. Questions at the bottom get buried or ignored. This is the gstack anti-pattern: "ONE THING AT A TIME."

The fix: skills surface one question at a time, only when genuinely blocked — when the skill cannot proceed without user input. Informational findings, obvious defaults, and rhetorical questions get stated inline without pausing. The skill states its recommendation and reasoning before asking, so the user has context to decide quickly.

Success looks like: a user running `/product-review` gets asked one real decision, answers it, the skill continues working, and pauses again only if it hits another genuine ambiguity. Not an exam. Not 15 round-trips. A conversation with a competent colleague who only interrupts when they need to.

### Codebase Health

STATUS: HEALTHY

- Stack: Pure prompt engineering — SKILL.md files (Markdown), bash scripts (install.sh, uninstall.sh). No runtime, no dependencies, no build step.
- Structure: Clean. 10 skills, each self-contained in its own directory. One install script. One design doc. Shared document model works.
- Test coverage: None. There are no tests. Skills are prompt files — testing means running them. This is expected for the project type.
- Documentation: Solid. README is accurate and current. CHANGELOG tracks changes. Design doc in `docs/designs/` explains the shared document model rationale.
- Dependency freshness: N/A — no dependencies beyond Claude Code and git.
- Git hygiene: Clean. 15 commits, clear messages, branches merged and cleaned up. Working tree clean.

### Open Wounds

- TODO.md has 5 items, all checked off. It's a dead file — either delete it or add real items.
- `docs/designs/2026-03-25-bootstrap.md` references the old `.claude/reviews/` path in several places (lines 15, 49, 121, 235-245). The code was updated to `docs/plans/` but the design doc wasn't. Stale documentation.
- Three local branches (`add-ship-it-skill`, `bootstrap`, `bugfixes`) are fully merged but not deleted.

### Tech Debt

- The canonical plan-finding bash snippet is copy-pasted across all 10 SKILL.md files. The design doc acknowledges this as "DRY violation by design" but it already caused bugs (promotion path mismatch, fixed in v0.1.2.0). One more divergence is inevitable.
- `/ship-it` is 269 lines — nearly double the next largest skill. It's doing too many things (merge, test, review, version, changelog, todos, commit, push, PR). Probably fine for now but will be the first skill to break under maintenance.
- Several skills reference `TODOS.md` (with an S) while the actual file is `TODO.md`. Minor but sloppy.

### ASCII: Project Structure

```
gauntlette/
├── skills/                    # The product — 10 SKILL.md files
│   ├── survey/                # Creates plan document
│   ├── product-review/        # Challenges the idea
│   ├── ux-review/             # ASCII wireframes, design ratings
│   ├── arch-review/           # Architecture, data flow, failure modes
│   ├── fresh-eyes/            # Independent subagent review
│   ├── implement/             # Builds the feature (promotes plan to repo)
│   ├── code-review/           # Post-implementation adversarial review
│   ├── quality-check/         # E2E browser testing
│   ├── ship-it/               # Merge, version, changelog, push
│   └── gauntlette-help/       # Pipeline status display
├── docs/
│   ├── designs/               # Historical design docs
│   └── plans/                 # Promoted plan documents (in-repo)
├── install.sh                 # Symlinks skills to ~/.claude/skills/
├── uninstall.sh               # Removes symlinks
├── VERSION                    # 0.1.2.0
├── CHANGELOG.md
├── TODO.md
└── README.md
```

### The Prompt Overload Problem

Current offenders (sampled from SKILL.md files):

1. **`/survey`** — Step 2 dumps Vision, Codebase Health, Open Wounds, Tech Debt, ASCII diagram, Priorities, and "Questions for the Human" all at once. The questions at the bottom get buried.

2. **`/product-review`** — The review process asks the user to evaluate scope items, then presents findings, then asks for a verdict — but it can collapse these into one giant output.

3. **`/arch-review`** — Presents architecture findings, implementation plan, AND asks questions in one pass.

4. **`/fresh-eyes`** — Subagent returns findings and the skill dumps them all with "do you want to address these?" as one blob.

5. **All skills with "Questions for the Human"** — These get appended to the end of long outputs where the user has already lost focus.

## Resolved Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| What gets serialized | Questions only, not findings/analysis | User confirmed: the problem is batched questions, not batched output. Findings can be presented together. |
| When to pause | Only when genuinely blocked | Over-correction (15+ round-trips) is worse than the current problem. Pause only when the skill literally cannot proceed without user input. Obvious defaults and rhetorical questions are stated inline. |
| Implementation approach | Template system: SKILL.templ.md + build script generates SKILL.md | Learned from gstack: shared rules live in a preamble, injected at build time. Fixes the DRY problem for this rule AND the plan-finding snippet AND future shared rules. |
| Canonical wording | Standardize on product-review's phrasing | Three skills already have the rule with slightly different wording. Pick one, use it everywhere. product-review's is the most complete. |
| "Questions for the Human" template section | Remove from survey template | This section actively invites Claude to batch questions at the end of a wall of text. Replace with sequential AskUserQuestion calls. |
| gauntlette-help | Exempt — no interaction | Display-only skill. No questions, no decisions. Adding the rule would be noise. |
| Don't ask what the pipeline already decided | Skills state the next step, not offer it as a choice | The pipeline order exists so the user doesn't have to decide what comes next. "Next: /product-review" not "Want to move to implementation, or refine the design further first?" |

## Scope

| # | Item | Effort | Decision | Reasoning |
|---|------|--------|----------|-----------|
| 1 | Write `gen-skills.sh` build script — reads `SKILL.templ.md`, resolves `{{PREAMBLE}}` and `{{PLAN_FINDING}}`, writes `SKILL.md` | M | ACCEPTED | Single bash script, no dependencies. Resolves the DRY problem for all shared content. |
| 2 | Write `preamble.md` — shared rules injected into every interactive skill | S | ACCEPTED | Contains: one-at-a-time rule, don't-ask-what-pipeline-decides rule, re-ground rule, smart-skip rule. |
| 3 | Write `plan-finding.md` — shared plan-finding bash snippet | S | ACCEPTED | The canonical snippet that was copy-pasted 10 times. Now lives in one file. |
| 4 | Convert all 10 SKILL.md to SKILL.templ.md + generated SKILL.md | M | ACCEPTED | Each skill gets a markdown-friendly template file with `{{PREAMBLE}}` and `{{PLAN_FINDING}}` placeholders. The generated SKILL.md is what Claude Code reads. |
| 5 | Audit and rewrite multi-question anti-patterns in templates | M | ACCEPTED | "Questions for the Human" in survey, inconsistent AskUserQuestion usage, unsolicited next-step questions. Fix in the templates. |
| 6 | Update install.sh to run gen-skills.sh | S | ACCEPTED | Generated SKILL.md files need to exist after install. |

### Priorities

1. Write the canonical instruction block — the exact wording that goes into each SKILL.md.
2. Audit all 10 skills for existing multi-question patterns and rewrite them.
3. Test by running the pipeline on a real feature.

## Architecture

### System Diagram

```
USER
  │
  ├── types /survey, /product-review, etc.
  │
  ▼
CLAUDE CODE HARNESS
  │
  ├── loads SKILL.md from ~/.claude/skills/{name}/
  │
  ▼
SKILL.md (prompt)                    ← EDIT POINT: add rule here
  │
  ├── ## Behavior section            ← canonical block goes here
  ├── ## Process steps               ← rewrite multi-question patterns
  │
  ▼
CLAUDE (LLM)
  │
  ├── decides when to use AskUserQuestion vs. inline statement
  │
  ▼
USER sees one question at a time
```

No new components. No new files. No new dependencies. The entire change is prompt text in existing SKILL.md files.

### Audit: Current State of Each Skill

```
Skill              Has rule?  Wording matches canonical?  Anti-patterns found
─────────────────  ─────────  ──────────────────────────  ──────────────────────────
survey             NO         —                           "Questions for the Human" template
product-review     YES        YES (canonical source)      None
ux-review          YES        SHORTER (missing reco+why)  None
arch-review        YES        SHORTER (missing "proceed") None
fresh-eyes         YES        CUSTOM (walk-through style) Minor batch at end is fine
implement          NO         —                           "STOP and ask" but no serialization rule
code-review        NO         —                           "present via AskUserQuestion" but no serialization
quality-check      NO         —                           No AskUserQuestion rule at all
ship-it            NO         —                           Inconsistent — some steps ask, some don't
gauntlette-help    N/A        —                           Display only, exempt
```

### Canonical Instruction Block

This exact text goes into the `## Behavior` section of every skill (except gauntlette-help):

```
- One AskUserQuestion per issue. Never batch. Recommend + WHY. STOP and wait for a response before proceeding.
- Re-ground every question: state the project, branch, and what you're evaluating.
- Smart-skip: if the user's initial description already answers a question, skip it.
```

For skills without a `## Behavior` section, add one after the persona description.

### Anti-Pattern Rewrites

**survey/SKILL.md:**
- Remove `### Questions for the Human` from the plan template (lines 104-106)
- Add `## Behavior` section with canonical block after line 8
- Replace the template's question section with: after writing the plan, ask questions one at a time via AskUserQuestion

**implement/SKILL.md:**
- Add canonical block to existing `## Behavior` section (after line 19)
- Line 13 "STOP and ask" already hints at it — make it explicit

**code-review/SKILL.md:**
- Add canonical block to existing `## Behavior` section (after line 16)
- Line 76 "present via AskUserQuestion" is already close — tighten it

**quality-check/SKILL.md:**
- Add `## Behavior` section after line 8 with canonical block
- QA has no existing interaction pattern — the block establishes one

**ship-it/SKILL.md:**
- Add canonical block to existing `## Behavior` section (after line 15)
- Lines 73-76 (test failures) and 120-123 (coverage) already use AskUserQuestion correctly — the block just makes the rule universal

**ux-review/SKILL.md:**
- Replace line 16 with full canonical wording (currently shorter version)

**arch-review/SKILL.md:**
- Replace line 16 with full canonical wording (currently shorter version)

### Error Paths

The only failure mode: Claude ignores the instruction during long outputs. This is inherent to prompt engineering — no mitigation beyond clear, prominent placement in the Behavior section. Placing the rule as the FIRST bullet in Behavior maximizes salience.

### Test Plan

```
Component           | Happy Path          | Edge Case
────────────────────┼─────────────────────┼──────────────────────────
survey              | Asks questions 1x   | On master (asks feature name)
product-review      | Already works       | 10 challenge Qs (some skipped)
ux-review           | Asks per dimension  | Auto-skip (no UI)
arch-review         | Asks per issue      | Auto-skip (trivial)
fresh-eyes          | Walks findings 1x   | < 50 lines (auto-skip)
implement           | Stops on deviation  | Plan not found (hard stop)
code-review         | Asks per finding    | Small diff (no adversarial)
quality-check       | Asks per bug        | No browser surface (skip)
ship-it             | Asks on failures    | Clean run (no questions)
```

No automated tests possible — manual run of pipeline is the test.

## Implementation

### New files

| File | Purpose |
|------|---------|
| `shared/preamble.md` | Shared interaction rules injected via `{{PREAMBLE}}` |
| `shared/plan-finding.md` | Canonical plan-finding bash snippet injected via `{{PLAN_FINDING}}` |
| `gen-skills.sh` | Build script: resolves templates → SKILL.md |
| `skills/*/SKILL.templ.md` | Templates (10 files, one per skill) |

### Files that become generated (do not edit directly)

All `skills/*/SKILL.md` — generated from `SKILL.templ.md` by `gen-skills.sh`.

### Implementation order

1. Write `shared/preamble.md` and `shared/plan-finding.md`
2. Write `gen-skills.sh`
3. Convert each skill: rename SKILL.md → SKILL.templ.md, insert `{{PREAMBLE}}` and `{{PLAN_FINDING}}`, apply anti-pattern fixes
4. Run `gen-skills.sh` to generate all SKILL.md files
5. Verify generated output matches expected content
6. Update install.sh

## Gauntlette Review Report

| Review | Trigger | Runs | Status | Findings |
|--------|---------|------|--------|----------|
| Survey | `/survey` | 1 | DONE | Skills dump walls of text with buried questions. Need "one at a time" interaction pattern. |
| Product Review | `/product-review` | 1 | CLEAR | HOLD scope. 4 items accepted, 0 deferred. Pause only when genuinely blocked — not every question mark. |
| UX Review | `/ux-review` | 0 | — | — |
| Architecture | `/arch-review` | 1 | CLEAR | 9 files, 0 new. Canonical block for 9 skills. Survey template anti-pattern removal. No issues found. |
| Fresh Eyes | `/fresh-eyes` | 0 | — | — |
| Implementation | `/implement` | 1 | DONE | Template system: gen-skills.sh + shared/ + 10 `SKILL.templ.md` files. Preamble injected into 9 skills. |
| Code Review | `/code-review` | 1 | PASS | 12 adversarial findings. Fixed 5: preamble example, generated-file header, placeholder validation, survey orientation restore, survey flow contradiction. Skipped 7 (pre-existing, out of scope, or not bugs). |
| QA | `/quality-check` | 0 | SKIPPED (no browser surface) | Pure prompt engineering — SKILL.md templates, bash scripts, shared markdown. No UI to test. |
| Ship | `/ship-it` | 1 | DONE | Shipped v0.1.3.0 on 2026-03-28. |

**VERDICT:** SHIPPED v0.1.3.0
