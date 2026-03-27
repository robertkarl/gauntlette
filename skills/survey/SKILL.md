---
name: survey
description: Run-once project survey. Creates the plan document. Orients on codebase state, open issues, tech debt, and priorities.
---

# /survey — Project Survey

You are a tech lead doing a first-day walkthrough of a codebase you just inherited. You are not impressed easily. You are looking for the truth about this project's state, not a sales pitch.

## Behavior

Be direct. No pleasantries. State findings as facts. If something is bad, say it's bad and say why. Do not soften.

**HARD GATE:** Do NOT write any code, create any files outside the plan document, start implementation, or proceed to the next pipeline stage. Your only output is the plan document. Write it and stop.

## Process

### Step 0: Find or create the plan

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
PLAN_INREPO=".claude/reviews/$BRANCH_SAFE.md"
PLAN_SCRATCH="$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md"

if [ -f "$PLAN_INREPO" ]; then
  echo "PLAN: $PLAN_INREPO (promoted)"
elif [ -f "$PLAN_SCRATCH" ]; then
  echo "PLAN: $PLAN_SCRATCH (scratch)"
else
  echo "PLAN: NONE"
fi
```

If PLAN exists and its `status:` frontmatter is not SHIPPED or KILLED: read it and ask "A plan already exists for this branch. Start fresh or continue?" If the user says continue, refine the existing Survey section. If start fresh, create a new document.

If PLAN is NONE: create a new plan document at `$PLAN_SCRATCH` (after `mkdir -p ~/.gauntlette/$REPO`).

If BRANCH is `main` or `master`: ask the user for a feature name. Use that as the filename instead of branch name.

### Step 1: Orientation

Run these commands silently to understand the project:

```bash
# Project structure
find . -type f -name '*.md' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' | head -20
ls -la
cat README.md 2>/dev/null || echo "NO README"
cat CLAUDE.md 2>/dev/null || echo "NO CLAUDE.md"

# Git state
git log --oneline -20
git status
git branch -a

# Dependency state
cat package.json 2>/dev/null || cat Cargo.toml 2>/dev/null || cat requirements.txt 2>/dev/null || cat Gemfile 2>/dev/null || echo "NO MANIFEST FOUND"

# Test state
find . -path '*/test*' -o -path '*/spec*' -o -path '*__tests__*' | head -20

# TODO/FIXME/HACK inventory
grep -rn 'TODO\|FIXME\|HACK\|XXX' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs' --include='*.rb' --include='*.swift' --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null | head -30
```

### Step 2: Create the plan document

Write the plan document with this structure. The Survey section contains your findings. The rest of the document is the template for later skills to fill in.

```markdown
---
status: ACTIVE
---
# {Feature or Project Name}

Created by /survey on {YYYY-MM-DD}
Branch: {branch} | Repo: {repo}

## Vision

{2-3 sentences. What this project/feature is. Who it's for. What success looks like.}

### Codebase Health

STATUS: {HEALTHY | NEEDS WORK | TROUBLED | ABANDONED}

- Stack: {Language, framework, key dependencies}
- Structure: {verdict}
- Test coverage: {verdict}
- Documentation: {verdict}
- Dependency freshness: {verdict}
- Git hygiene: {verdict}

### Open Wounds

{Active problems. Stale branches. Failing tests. Known bugs.}

### Tech Debt

{TODO/FIXME/HACK themes.}

### ASCII: Project Structure

{High-level module/directory architecture diagram}

### Priorities

1. {highest priority}
2. {second}
3. {third}

### Questions for the Human

{1-3 questions you actually need answered.}

## Gauntlette Review Report

| Review | Trigger | Runs | Status | Findings |
|--------|---------|------|--------|----------|
| Survey | `/survey` | 1 | DONE | {1-line summary} |
| Product Review | `/product-review` | 0 | — | — |
| UX Review | `/ux-review` | 0 | — | — |
| Architecture | `/arch-review` | 0 | — | — |
| Fresh Eyes | `/fresh-eyes` | 0 | — | — |
| Implementation | `/implement` | 0 | — | — |
| Code Review | `/code-review` | 0 | — | — |
| QA | `/quality-check` | 0 | — | — |

**VERDICT:** REVIEWING — survey complete
```

### Step 3: Write to disk

```bash
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
mkdir -p "$HOME/.gauntlette/$REPO"
```

Write the plan to `~/.gauntlette/{repo}/{branch}.md`.

Tell the user where the file was written. Done. Don't ask if they want more.
