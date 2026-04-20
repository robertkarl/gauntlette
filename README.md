# Gauntlette

Gauntlette is the structured part of gstack without the ads, upgrade nagging, or lake chatter.

It is a review and delivery pipeline for Claude Code and Codex. Every feature gets:

- a durable design doc in `~/.gauntlette/designs/{repo}/`
- one active plan document that gets refined stage by stage
- browser QA that acts like a real user
- architecture diagrams that render well in markdown

There is no telemetry, no auto-update behavior, and no phone-home.

## Preferred Commands

```
/gauntlette-start → /gauntlette-ceo-review → /gauntlette-design-review → /gauntlette-eng-review
    → /gauntlette-fresh-eyes → [/gauntlette-cso-review] → /gauntlette-implement
    → /gauntlette-code-review → /gauntlette-quality-check → /gauntlette-human-review → /gauntlette-ship-it
```

Legacy aliases still work:

- `/survey-and-plan`, `/survey`, and `/help-me-plan` all map to `/gauntlette-start`
- `/ceo-review`, `/design-review`, and `/eng-review` are supported
- older names like `/product-review`, `/ux-review`, and `/arch-review` still work
- unprefixed stage names like `/quality-check` still work
- `/gauntlette-help` shows the current stage and preferred command names

## What Changed

- Planning is now closer to `gstack-office-hours`: one question at a time, sharper forcing questions, explicit premises, and alternatives generation.
- The kickoff stage writes both a design doc and the active plan.
- QA is now diff-aware and browser-first. It prefers an existing preview or browser session, falls back to local ports, writes evidence into `.gstack/qa-reports/`, and tracks a health score.
- Architecture review now emits Mermaid plus ASCII diagrams.
- The prompts now prefer complete options over shortcuts and use a stricter AskUserQuestion format.
- Install now targets both `~/.claude/skills/` and `~/.codex/skills/`.
- Token reporting is bundled under `gauntlette/bin/estimate-tokens.sh`, so it no longer depends on a separate Moe checkout.

## How It Works

### Planning artifacts

`/gauntlette-start` writes:

- `~/.gauntlette/designs/{repo}/{branch}-design-{timestamp}.md`
- `~/.gauntlette/{repo}/{branch}.md`

The design doc is the durable planning artifact. The plan is the stage-by-stage working document.

### Promotion

When `/gauntlette-implement` starts, the plan is promoted into the repo at `docs/plans/{branch}.md` and the scratch copy is removed.

### Review report

Every plan ends with a **Gauntlette Review Report** table that tracks which stages ran, what they found, and what still needs to happen.

## Install

```bash
git clone https://github.com/robertkarl/gauntlette.git
cd gauntlette
./install.sh
```

`install.sh` regenerates the skill docs, then symlinks gauntlette into:

- `~/.claude/skills/`
- `~/.codex/skills/`

Conflicts with existing installs are skipped, not overwritten.

The shared `gauntlette/` root symlink also carries helper tools like `gauntlette/bin/estimate-tokens.sh`, so install and uninstall pick them up automatically.

## QA Dependency

`/gauntlette-quality-check` reuses the gstack browse binary if it exists at `~/.claude/skills/gstack/browse/dist/browse`.

That gives gauntlette the same click-through web QA flow you liked from gstack, while still working well from Codex or Cursor when a built-in preview pane is already live.

## Repo Instructions Snippet

Add the command list to your repo instructions file, for example `CLAUDE.md` or `AGENTS.md`:

```markdown
## Gauntlette
Preferred commands: /gauntlette-help, /gauntlette-start, /gauntlette-ceo-review, /gauntlette-design-review, /gauntlette-eng-review, /gauntlette-fresh-eyes, /gauntlette-cso-review, /gauntlette-implement, /gauntlette-code-review, /gauntlette-quality-check, /gauntlette-human-review, /gauntlette-ship-it
Legacy aliases: /survey-and-plan, /survey, /help-me-plan, /ceo-review, /design-review, /eng-review, /product-review, /ux-review, /arch-review, /fresh-eyes, /cso-review, /implement, /code-review, /quality-check, /human-review, /ship-it
```

## Principles

- No telemetry. No analytics. No phone-home.
- No upgrade checks. No ads. No auto-update prompts.
- One question at a time. Ask better questions, not more questions.
- Prefer complete implementations over cute shortcuts.
- Planning artifacts live outside the repo during review so bad edits do not dirty the worktree.
- Mermaid plus ASCII diagrams are mandatory for non-trivial architecture.
- QA should use the browser like a user, not excuse itself into unit-test theater.

## Engineering Axioms

1. Main is sacred.
2. Tiny fixes go direct.
3. Test before fix.
4. Run the tests.
5. One branch, one concern.
6. Dead branches are dead.
7. Leave the campsite clean.
8. Simplest thing that works.
9. Read the repo instructions file, the plan, and the tests before you write.
10. Escalate decisions, not problems.
