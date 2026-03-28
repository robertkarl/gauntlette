# Gauntlette

Review pipeline for Claude Code. Every feature gets one plan document, refined through multiple personas until it's ready to ship.

This is heavily inspired by gstack.

It's mostly a bunch of prompts and skill.md files, but also includes playwright for headless browser support. This dramatically improves the QA process and web fetch/search behavior.

There is no telemetry, and it includes an uninstaller.

## The Gauntlette

```
/survey → /product-review → /ux-review → /arch-review
    → /fresh-eyes → /implement → /code-review → /quality-check → /ship-it
```

Each skill reads the plan, does its job, and edits the plan with its findings. One document in, one document out — coherent, not a pile of opinions.

## Skills

**Utility:**

| Command | Does what |
|---------|-----------|
| `/gauntlette` | Shows the pipeline, available skills, and current plan status. |

**Core loop** (use these on every feature):

| Command | Persona | Does what |
|---------|---------|-----------|
| `/survey` | Tech Lead | Creates the plan document. Orients on codebase state. |
| `/implement` | Senior Engineer | Builds the feature against the reviewed plan. Tests alongside code. |
| `/code-review` | Adversarial Reviewer | Post-implementation. Finds production bugs. Scales by diff size. |
| `/ship-it` | Release Engineer | Merge, test, review, version bump, changelog, merge to master. |

**Extended pipeline** (use when the feature warrants it):

| Command | Persona | Does what | Auto-skips when |
|---------|---------|-----------|-----------------|
| `/product-review` | Skeptical PM/Founder | Challenges the idea itself. Scope, value, risk. | — |
| `/ux-review` | Senior Designer | ASCII wireframes. Dimension ratings. AI slop audit. | No UI changes |
| `/arch-review` | Staff Engineer | Architecture diagrams. Error paths. Failure modes. | Trivial change |
| `/fresh-eyes` | Fresh-context adversary | Independent subagent review. No shared state. | < 50 lines changed |
| `/quality-check` | QA Engineer | E2E browser testing via playwright-cli. | No browser surface |

## How It Works

### One plan document per feature

`/survey` creates a plan at `~/.gauntlette/{repo}/{branch}.md`. Each subsequent skill reads the full plan, does its review, and edits the document — resolving decisions, adding sections, refining what's already there.

The plan lives **outside your repo** during review. Claude edits it aggressively through multiple passes. Bad edits during review don't touch your working tree.

### Promotion

When `/implement` starts, the plan is promoted: copied to `docs/plans/{branch}.md` inside your repo and the scratch copy is deleted. From that point, `/implement` and `/code-review` work against the in-repo plan. It can be committed alongside your code.

### Review Report

Every plan has a Review Report table at the bottom showing which skills have run, their status, and findings. This is the pipeline status tracker.

## Install

```bash
git clone https://github.com/robertkarl/gauntlette.git
cd gauntlette
./install.sh
```

This symlinks skills into `~/.claude/skills/`. Conflicts with existing installs (e.g. gstack) are skipped, not overwritten.

For browser-based QA (`/quality-check`), also install:

```bash
npx playwright install
```

Add to your project's CLAUDE.md:

```markdown
## Gauntlette
Available skills: /gauntlette, /survey, /product-review, /ux-review, /arch-review, /fresh-eyes, /implement, /code-review, /quality-check, /ship-it
```

## Dependencies

| Dependency | Required by | Install |
|-----------|-------------|---------|
| Claude Code | all skills | `npm install -g @anthropic-ai/claude-code` |
| Git | all skills | comes with your OS |
| playwright-cli | `/quality-check` only | `npm install -g @playwright/cli` |

No Bun. No compiled binaries. No config directories. Plan scratch files live in `~/.gauntlette/` during review.

## Principles

- No telemetry. No analytics. No phone-home. Ever.
- No upgrade checks. No version files. No config directories.
- No "wow, great insight!" — personas are direct, blunt, and rude when warranted.
- ASCII diagrams are mandatory for non-trivial flows.
- Each skill is one self-contained SKILL.md.
- One plan document per feature. Skills edit it, not append to it.
- Plans live outside the repo during review, inside the repo after promotion. The motivation is to prevent bad edits during planning from messing with repo state.
