# Gauntlette

Opinionated feature pipeline for Claude Code. No telemetry, no ads, no update checks, no bloat.

Inspired by gstack's structure. Stripped to essentials.

## The Gauntlette

```
/survey → /product-review → /design-review → /arch-review → /fresh-eyes → /implement → /code-review → /qa
```

Each stage writes findings to `.claude/reviews/` so nothing gets lost. Your feature has to survive every gate.

## Skills

| Command | Persona | Does what |
|---------|---------|-----------|
| `/survey` | Tech Lead | Run-once project survey. Where are we, what's the state of things. |
| `/product-review` | Skeptical PM/Founder | Challenges the feature idea itself. Is this worth building? Scope modes. |
| `/design-review` | Senior Designer | ASCII wireframes of key screens. Rates dimensions 0-10. Blunt. |
| `/arch-review` | Staff Engineer | ASCII data flow diagrams. Architecture, edge cases, failure modes. |
| `/fresh-eyes` | Fresh-context adversary | Clean-context subagent review. No shared state with prior reviews. |
| `/implement` | Senior Engineer | Builds the feature against approved reviews. Tests alongside code. Atomic commits. |
| `/code-review` | Adversarial Reviewer | Post-implementation. Finds production bugs. ASCII execution diagrams. |
| `/qa` | QA Engineer | E2E browser testing via playwright-cli. Click, verify, screenshot. |

## Install

Copy to your Claude Code skills directory:

```bash
cp -r gauntlette ~/.claude/skills/gauntlette
```

For browser-based QA testing, also install:

```bash
npm install -g @playwright/cli
playwright-cli install-skill
```

Add to your project's CLAUDE.md:

```markdown
## Gauntlette
Available skills: /survey, /product-review, /design-review, /arch-review, /fresh-eyes, /implement, /code-review, /qa
Review artifacts are written to .claude/reviews/
Code review adversarial depth scales by diff size: <50 skip, 50-199 standard, 200+ full.

## Browser
Use playwright-cli for all browser interactions. Never use mcp__claude-in-chrome__* tools.
```

## Review Artifacts

Every skill writes its output to `.claude/reviews/{skill}-{date}.md`. These are git-trackable and persist across sessions. The `/code-review` skill checks for stale diagrams from earlier stages.

## Dependencies

| Dependency | Required by | Install |
|-----------|-------------|---------|
| Claude Code v2.1+ | all skills | `npm install -g @anthropic-ai/claude-code` |
| Git | all skills | comes with your OS |
| playwright-cli | `/qa` only | `npm install -g @playwright/cli && playwright-cli install-skill` |

No Bun. No compiled binaries. No config directories. No state files.

## Shared Prompting Rules (all skills follow these)

**One issue, one question.** Never batch multiple issues into a single question. Present one issue, recommend a course of action, explain why, and STOP. Wait for the human to respond before moving to the next issue.

**Re-ground every question.** State the project name, current branch, and what step you're on. Context drifts. Fight it.

**Smart-skip.** If the user's prompt already answers a question you were going to ask, skip it. Don't ask people to repeat themselves.

**Completeness over shortcuts.** AI makes the marginal cost of doing the complete thing near-zero. Recommend the complete option (all edge cases, all error handling, all tests) unless the scope is genuinely an "ocean" (multi-quarter migration). If it's a "lake," boil it.

**See something, say something.** If you notice something wrong during ANY step — not just the step you're on — flag it in one sentence. What you noticed, what the impact is. Then move on. Don't silently pass over issues because they're "not your job right now."

**Iron rule on regressions.** If you broke something that previously worked, write a regression test IMMEDIATELY. No asking. No skipping. Regressions are the highest-priority test.

**Search before building.** Before implementing unfamiliar patterns or infrastructure, search whether the framework/runtime has a built-in. Don't reinvent.

**Complexity threshold.** If a plan or implementation touches 8+ files or introduces 2+ new classes/services, proactively recommend scope reduction. Explain what's overbuilt, propose a minimal version, ask whether to reduce or proceed.

## Principles

- No telemetry. No analytics. No phone-home. Ever.
- No upgrade checks. No version files. No config directories.
- No "wow, great insight!" — personas are direct, blunt, and rude when warranted.
- ASCII diagrams are mandatory for non-trivial flows.
- Each skill is one self-contained SKILL.md. No shared libraries, no binaries.
- Review output is captured to disk, not lost in scrollback.
