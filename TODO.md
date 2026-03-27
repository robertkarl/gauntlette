# TODO

- [ ] Fix promotion path: skills promote plans into `.claude/reviews/<featurename>.md` — move out of the `.claude/` directory into a top-level location (e.g. `reviews/` or `plans/`). Affects: arch-review, survey, implement, ship-it, code-review, fresh-eyes, ux-review, product-review, gauntlette-help, quality-check, README.md, docs/designs/2026-03-25-bootstrap.md.

- [ ] Fix promotion timing: plan is promoted into the repo too early. Should only be promoted right before `/implement` runs (i.e. after `/fresh-eyes` completes).

- [ ] Guard against implementing on master: `/implement` should check the current branch and refuse to proceed if on master/main. Prompt the user to create a feature branch first.

- [ ] `/implement` should verify it has a plan before starting: check for a plan file in `~/.gauntlette/<repo>/<branch>.md` (or in-repo location) and refuse if none found. Prompt user to run `/survey` first.

- [ ] After `/implement` completes, Claude should suggest `/code-review` as the next gauntlette step.
