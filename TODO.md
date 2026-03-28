# TODO

- [x] Fix promotion path: moved from `.claude/reviews/` to `docs/plans/`. All skills updated.

- [x] Fix promotion timing: promotion now fires in `/implement` Step 0, not in `/arch-review`.

- [x] Guard against implementing on master: `/implement` now auto-checkouts a feature branch if on master/main.

- [x] `/implement` should verify it has a plan before starting: hard stop added if no plan found.

- [x] After `/implement` completes, Claude should suggest `/code-review` as the next gauntlette step.
