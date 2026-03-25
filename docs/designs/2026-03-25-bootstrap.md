# Rearchitect: Shared Document Model

## The Problem

Gauntlette skills currently write isolated files to `.claude/reviews/`. Each skill produces its own artifact with no structural connection to the others. The "pipeline" is aspirational — skills read from the directory but there's no shared artifact being refined. This makes the pipeline feel ad-hoc rather than cumulative.

The gstack insight: shepherding a single document through multiple rounds of review produces a fundamentally better result than accumulating independent opinions in a folder. Each reviewer sees everything prior reviewers decided, and the document gains coherence as it passes through each gate.

## Resolved Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Document structure | Flexible — skills add sections when relevant, skip when not | Not every feature needs all sections. A bug fix might just be Vision + Implementation + Code Review. The Review Report table provides consistency. |
| Skip philosophy | Scope-driven (skip what's irrelevant) + size-driven scaling (scale expensive steps by diff size) | Follows gstack's pattern. Anti-skip by default — only skip when a step genuinely doesn't apply. User override always wins. |
| Where documents live | `~/.gauntlette/{repo}/` during review, copied to `.claude/reviews/` in-repo when reviews pass | Plans are edited heavily during review — bad edits shouldn't land in the repo. Once the plan clears enough gates, it gets copied into the codebase where it can be committed alongside the code it describes. |
| Plan safety | Plans live in ~/.gauntlette/ during review, promoted to .claude/reviews/ after /arch-review clears | Claude edits plans heavily during review. Bad edits during long sessions shouldn't corrupt the repo. Scratch space outside the repo is the safety net. |
| Rewrite scope | All 8 skills in one pass | The I/O change is the same pattern applied 8 times. Maintaining two I/O patterns (old per-file + new shared doc) across skills is more work than just doing all 8. |
| Product verdict | HOLD | Scope is right. The plan is the smallest thing that delivers the shared document model. No cuts, no expansions. |
| Plan-finding logic | Canonical bash snippet, copied verbatim into all 8 skills | DRY violation by design — skills are self-contained. But the logic must be identical to avoid bugs. |
| Scratch cleanup | Delete scratch copy on promotion (rm after cp) | Prevents split-brain: two divergent copies of the same plan. |
| Stale plan detection | Check status frontmatter; SHIPPED plans are not active | Handles branch name reuse. A SHIPPED plan from a dead branch won't be mistaken for a new active plan. |

## Scope

| # | Item | Effort | Decision | Reasoning |
|---|------|--------|----------|-----------|
| 1 | Rewrite 8 SKILL.md I/O patterns | M | ACCEPTED | Core deliverable. Each skill reads/edits shared doc instead of writing isolated file. |
| 2 | Update README.md | S | ACCEPTED | Review Artifacts section needs to describe the new model. |
| 3 | Add skip/scale logic to skills | S | ACCEPTED | Scope-driven skips and diff-size scaling per the resolved decision. |
| 4 | Prompt engineering for "edit coherently" | M | ACCEPTED | The hard part. Each skill needs careful instructions on how to edit an existing document without trashing it. |
| 5 | ~/.gauntlette/ scratch directory + promotion logic | S | ACCEPTED | mkdir + cp. Skills need to know which location to read/write based on whether the plan has been promoted. |
| 6 | Clean up old review files from master | S | DEFERRED | The per-skill review files from our earlier ad-hoc session can be cleaned up later. |
| 7 | Shared prompting rules in each SKILL.md | S | DEFERRED | Rely on CLAUDE.md for now. Revisit after using the pipeline on real projects. |

## The Design

### One document per feature

The first skill invoked (usually `/survey`) creates a single plan document:

```
~/.gauntlette/{repo-name}/{branch-name}.md
```

Branch name is the default. If on `main` with no branch context, ask for a feature name. Repo name is derived from `basename $(git rev-parse --show-toplevel)`.

Plans live **outside the repo** during review. Claude edits the plan heavily through multiple passes — scope changes, decision reversals, section rewrites. A bad edit during this phase shouldn't corrupt or clutter the working tree. The `~/.gauntlette/` directory is Claude's scratch space.

**Promotion to in-repo:** When the plan passes `/arch-review` (or when the user says "ready to implement"), the plan is copied to `.claude/reviews/{branch-name}.md` inside the repo. From that point, it's part of the project — committable, diffable, reviewable in PRs. `/implement` reads it from the in-repo location.

### Document structure

The document is a **coherent spec**, not a collection of appended sections. Each skill *edits and refines* the document — resolving TBDs, integrating decisions inline, adding detail to existing sections. It should read like one author wrote it.

```markdown
---
status: ACTIVE
---
# {Feature Name}

Created by /survey on {date}
Branch: {branch} | Repo: {repo}

## Vision
{What this is. Who it's for. What success looks like.}
{Written by /survey, refined by /product-review.}

## Resolved Decisions
| Decision | Choice | Reasoning |
|----------|--------|-----------|
| ...      | ...    | ...       |
{Accumulated by every skill. When a skill encounters a TBD or
ambiguity, it resolves it and adds a row here.}

## Scope
| # | Item | Effort | Decision | Reasoning |
|---|------|--------|----------|-----------|
| 1 | ...  | S      | ACCEPTED | ...       |
| 2 | ...  | M      | DEFERRED | ...       |
{Written by /product-review. Refined by later skills that
discover scope issues.}

## UX
{ASCII wireframes. State diagrams. Dimension ratings.}
{Written by /ux-review. May be annotated by /arch-review
if architecture forces UX changes.}

## Architecture
{System diagrams. Data flow. Error paths. Test matrix.}
{Written by /arch-review.}

## Implementation
{Files to modify. Files to delete. Implementation order.
Code details. Checkpoints.}
{Written by /arch-review, refined by /implement as the
actual build reveals deviations from the plan.}

## Gauntlette Review Report

| Review | Trigger | Runs | Status | Findings |
|--------|---------|------|--------|----------|
| Survey | `/survey` | 0 | SKIPPED | Bootstrapping from design doc, not a new codebase |
| Product Review | `/product-review` | 1 | CLEAR | HOLD scope. 4 accepted, 2 deferred. Skip/scale rules added. |
| UX Review | `/ux-review` | 0 | — | — |
| Architecture | `/arch-review` | 1 | CLEAR | 3 issues fixed inline (plan-finding logic, split-brain, stale plans). Implementation order + file table added. |
| Fresh Eyes | `/fresh-eyes` | 0 | — | — |
| Implementation | `/implement` | 0 | — | — |
| Code Review | `/code-review` | 0 | — | — |
| QA | `/quality-check` | 0 | — | — |

**VERDICT:** REVIEWING — product + arch review complete. Ready for /fresh-eyes or /implement.
```

### How skills find the plan

Every skill uses the same plan-finding logic. This snippet must be identical across all 8 SKILL.md files:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
PLAN_INREPO=".claude/reviews/$BRANCH.md"
PLAN_SCRATCH="$HOME/.gauntlette/$REPO/$BRANCH.md"

# Check in-repo first (promoted plan), then scratch
if [ -f "$PLAN_INREPO" ]; then
  echo "PLAN: $PLAN_INREPO (promoted)"
elif [ -f "$PLAN_SCRATCH" ]; then
  echo "PLAN: $PLAN_SCRATCH (scratch)"
else
  echo "PLAN: NONE"
fi
```

If PLAN is NONE and the skill is not `/survey`: warn "No plan found for branch '{branch}'. Run /survey first, or specify a plan file."

If PLAN is NONE and the skill IS `/survey`: create new plan at `$PLAN_SCRATCH` (after `mkdir -p ~/.gauntlette/$REPO`).

If on `main`/`master` with no feature branch: ask the user for a feature name and use that instead of branch name.

### How skills interact with the document

**Key principle: skills EDIT the document, not append to it.**

Each skill reads the full document, understands everything decided so far, and then:
- Adds new sections where they belong structurally
- Resolves open TBDs by filling in decisions
- Refines existing sections with new information
- Adds rows to the Resolved Decisions and Scope tables
- Updates the Review Report table at the bottom
- Updates the `status:` frontmatter

The document should always read coherently top-to-bottom, as if written in one pass. A reader should not be able to tell which skill wrote which paragraph — it should flow.

### What each skill does to the document

`/survey` — **Creates** the document. Writes the frontmatter, title, Vision section with project context, and the empty Review Report table. Sets status: ACTIVE.

`/product-review` — Reads the document. Refines the Vision (sharpens it, challenges it). Fills in the Scope table with accepted/deferred/killed items. Adds to Resolved Decisions. If verdict is KILL, sets status: KILLED and closes the document. Updates its row in the Review Report.

`/ux-review` — Reads the document. Writes the UX section with wireframes, state diagrams, and dimension ratings. May refine the Scope table if design reveals scope issues. Updates its row in the Review Report.

`/arch-review` — Reads the document. Writes the Architecture section. Writes or refines the Implementation section (files to change, order, code details). May annotate the UX section if architecture forces design changes. Fills in error paths, test matrix. Updates its row in the Review Report.

`/fresh-eyes` — Dispatches a subagent with the FULL document. The subagent reviews holistically. Findings get integrated into the relevant sections (not siloed into a "Fresh Eyes" section). Tensions between sections are called out inline. Updates its row in the Review Report.

`/implement` — Reads the document as its spec. Builds the feature. Updates the Implementation section with what was actually built — deviations, additional decisions made during build. Updates its row in the Review Report.

`/code-review` — Reads the document AND the diff. Checks implementation against every section of the spec. Findings get noted in the Review Report. If the code deviates from the plan, flags it inline.

`/quality-check` — Reads the document for context on what to test. Test results go in the Review Report table. Bug details can be added to an appendix or inline.

### Skip and scale rules

**Philosophy: skip what's irrelevant, scale what's expensive.** Inspired by gstack's approach — the marginal cost of completeness is near-zero with AI, so don't skip to save time. Skip only when a step genuinely doesn't apply to the change at hand. User override always wins ("run full review", "skip ux-review", etc.).

**Two types of skip logic:**

**Scope-driven skips** — "this doesn't apply":

| Skill | Auto-skip when | Review Report shows |
|-------|----------------|---------------------|
| `/ux-review` | No UI changes (backend-only, infra, config) | SKIPPED (no UI scope) |
| `/quality-check` | No browser-testable surface | SKIPPED (no browser surface) |
| `/arch-review` | Trivial change (rename, typo fix, docs-only) | SKIPPED (trivial change) |

Each skill determines scope by reading the document's Vision and Scope sections and the git diff (`git diff main...HEAD --name-only`). If the diff only touches `.md` files, backend configs, or non-UI code, UI-focused skills auto-skip.

**Size-driven scaling** — "scale the expensive parts":

| Skill | < 50 lines changed | 50-199 lines | 200+ lines |
|-------|---------------------|--------------|------------|
| `/code-review` | Structured review only. Adversarial subagent **skipped**. | Structured + one adversarial subagent. | Structured + two adversarial subagents (attacker + maintainability). |
| `/fresh-eyes` | **Skipped.** Small changes don't benefit from fresh-context review. | One subagent pass. | One subagent pass (same — fresh-eyes doesn't tier further). |

Line count = insertions + deletions from `git diff main...HEAD --stat`.

**User override:** If the user explicitly requests a step ("run ux-review", "full adversarial", "paranoid review"), honor it regardless of scope or size. The skip rules are defaults, not gates.

### Prerequisite checking

Each skill checks the Review Report table for expected prior runs:

```
/survey:         none (creates the document)
/product-review: Survey DONE
/ux-review:      Survey DONE (skip if no UI scope)
/arch-review:    Survey DONE, Product Review recommended (skip if trivial)
/fresh-eyes:     At least one review DONE (skip if <50 lines)
/implement:      Product Review + Architecture recommended
/code-review:    Implementation DONE (adversarial scales by diff size)
/quality-check:  Implementation DONE (skip if no browser surface)
```

If expected reviews are missing, warn: "This document has no Architecture review yet. /implement will have less context. Run /arch-review first?"

Warning, not gate. User can always skip.

### Status frontmatter

```yaml
---
status: ACTIVE       # being reviewed, pre-implementation
status: IMPLEMENTING # /implement is building it
status: SHIPPED      # passed code review + QA
status: KILLED       # /product-review killed it
---
```

Simple. One field. The Review Report table has the detail.

### Document lifecycle: scratch → in-repo

**During review** (`/survey` through `/arch-review`): the plan lives at `~/.gauntlette/{repo}/{branch}.md`. This is scratch space. Claude can edit aggressively without risk to the codebase. Git doesn't see it. Bad edits don't get accidentally committed.

**Promotion trigger:** After `/arch-review` clears (or when the user explicitly says to promote), the plan is copied to `.claude/reviews/{branch}.md` inside the repo. The skill that promotes it runs:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current)
mkdir -p .claude/reviews
cp ~/.gauntlette/$REPO/$BRANCH.md .claude/reviews/$BRANCH.md
rm ~/.gauntlette/$REPO/$BRANCH.md
```

**After promotion** (`/implement` onward): all skills read and write the in-repo copy. It can be committed, included in PRs, and reviewed by humans. The scratch copy is **deleted** during promotion to prevent split-brain — two divergent copies of the plan.

**Why this matters:** The Edit tool is mechanically safe (exact string match or fail), but Claude can still write contradictory content during long review sessions. Keeping the plan outside the repo during the messy review phase means a bad edit never touches the working tree.

### Multiple runs of the same skill

If a skill has already run (row in Review Report shows a run count > 0), it asks: "This document already has a Product Review (run on {date}). Re-review from scratch or refine the existing review?"

Re-review: rewrites the sections that skill owns.
Refine: edits/adds to existing content without starting over.

### What this replaces

- Per-skill output files (`survey-{date}.md`, `product-review-{date}.md`, etc.) — gone
- The `ls .claude/reviews/` prerequisite pattern — replaced by reading the Review Report table
- "Next step recommendation" at end of each skill — replaced by checking what's missing in the Review Report
- Disconnected review opinions — replaced by one coherent, evolving spec

### What stays the same

- Each SKILL.md is self-contained (no shared code)
- Personas and review methodologies don't change
- ASCII diagrams are mandatory
- Shared prompting rules still apply
- No runtime dependencies, no config, no state files
- install.sh unchanged

### Implementation

**Implementation order:**

1. **Write the canonical plan-finding snippet** and the canonical document template. These are the shared contracts that all skills depend on.

2. **Rewrite `/survey`** first — it creates the document. Until this works, nothing else can be tested.

3. **Rewrite `/product-review`** — the first skill that edits an existing plan. This is where "edit coherently" gets tested for the first time.

4. **Rewrite remaining review skills** (`/ux-review`, `/arch-review`, `/fresh-eyes`) — same edit pattern, different content.

5. **Add promotion logic to `/arch-review`** — after clearing, copy plan to repo, delete scratch.

6. **Rewrite post-promotion skills** (`/implement`, `/code-review`, `/quality-check`) — read from in-repo location.

7. **Update `README.md`** — Review Artifacts section.

8. **Test** — run the full pipeline on gauntlette itself (we're already doing this).

**Files to modify (9 total):**

| File | What changes | Lines affected |
|------|-------------|----------------|
| `survey/SKILL.md` | Plan-finding snippet. Create document with template. Replace "write to disk" step. | ~30 lines rewritten (Steps 2-3) |
| `product-review/SKILL.md` | Plan-finding snippet. Read plan, edit Vision/Scope/Decisions. Replace "write to disk" step. | ~20 lines rewritten (Steps 1, 5) |
| `ux-review/SKILL.md` | Plan-finding snippet. Read plan, add UX section. Skip logic for no-UI scope. Replace "write to disk" step. | ~25 lines rewritten (Steps 1, 6) |
| `arch-review/SKILL.md` | Plan-finding snippet. Read plan, add Architecture/Implementation sections. **Add promotion logic.** Replace "write to disk" step. | ~35 lines rewritten (Steps 1, 7) |
| `fresh-eyes/SKILL.md` | Plan-finding snippet. Read plan, dispatch subagent with full doc. Skip logic for <50 lines. Replace "write to disk" step. | ~20 lines rewritten (Steps 1, 5) |
| `implement/SKILL.md` | Plan-finding snippet (in-repo only). Read promoted plan as spec. Replace "write to disk" step. | ~25 lines rewritten (Steps 1, 7) |
| `code-review/SKILL.md` | Plan-finding snippet (in-repo only). Read plan + diff. Adversarial tier scaling. Replace "write to disk" step. | ~25 lines rewritten (Steps 1, 7-8) |
| `quality-check/SKILL.md` | Plan-finding snippet (in-repo only). Read plan for test context. Skip logic for no-browser. Replace "write to disk" step. | ~20 lines rewritten (Steps 1, 10) |
| `README.md` | Update Review Artifacts section to describe shared document model and ~/.gauntlette/ lifecycle. | ~15 lines rewritten |

**Checkpoint after step 2:** `/survey` creates a valid plan document at `~/.gauntlette/{repo}/{branch}.md` with correct template.

**Checkpoint after step 3:** `/product-review` successfully reads and edits the plan created by `/survey`. Document stays coherent.

**Checkpoint after step 5:** `/arch-review` promotes the plan to `.claude/reviews/` and deletes the scratch copy.

### Complexity check

9 files modified. Zero new files. Zero new dependencies. ~215 lines rewritten across all files. The core methodology of each skill is untouched. The change is in how skills read and write — from "create your own file" to "edit the shared document."
