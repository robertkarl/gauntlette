# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2.0] - 2026-03-27

### Added
- `/gauntlette-help` skill — shows pipeline stage, current plan, and next step.
- `TODO.md` — persistent todo tracking for known pipeline bugs.
- HARD GATE instructions added to `survey`, `product-review`, `ux-review`, `arch-review`, `fresh-eyes` to prevent premature implementation.

### Fixed
- Plan promotion path changed from `.claude/reviews/` to `docs/plans/`.
- Plan promotion timing moved from `/arch-review` to `/implement` Step 0 (just before building starts).
- `/implement` now hard-stops if no plan found (was a warning).
- `/implement` on `master`/`main` now auto-checks out a feature branch derived from the plan filename.
- `/implement` on `master`: plan lookup lists scratch plans first to avoid `BRANCH_SAFE=master` mismatch.
- `cp`+`rm` in promotion is now `cp && rm` to prevent scratch deletion on failed copy.
- `/implement` Step 7 now writes to in-repo path explicitly (scratch was deleted during promotion).
- `/fresh-eyes` base branch detection uses `merge-base` fallback instead of hardcoded `main`.
- `/ship-it` plan promotion now stages and commits the plan file (was untracked after merge).
- `/gauntlette-help` stage detection now treats `SKIPPED` statuses as completed.
- `/product-review` NONE error no longer mentions undocumented "specify a plan file" option.
- Stale `.claude/reviews/` files deleted; `.gitignore` updated.

## [0.1.1.0] - 2026-03-26

### Added
- `/ship-it` skill — minimal ship workflow: merge base, run tests, coverage audit, pre-landing review, version bump, changelog, todos update, merge to master, promote plan.
- VERSION file for 4-digit version tracking.
- CHANGELOG.md.

### Changed
- Pipeline diagram and skills table in README updated to include `/ship-it`.
- install.sh updated to install the `ship-it` skill.
