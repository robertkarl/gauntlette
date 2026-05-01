```bash
if ! git rev-parse --show-toplevel 2>/dev/null; then
  echo "FATAL: Not a git repository. Gauntlette requires a git repo to track plans."
  echo "Run: git init"
  echo "PLAN: FATAL_NO_REPO"
else
  REPO=$(basename "$(git rev-parse --show-toplevel)")
  BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
  BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
  PLAN_INREPO="docs/plans/$BRANCH_SAFE.md"
  PLAN_SCRATCH="$HOME/.gauntlette/$REPO/$BRANCH_SAFE.md"

  if [ -f "$PLAN_INREPO" ]; then
    echo "PLAN: $PLAN_INREPO (promoted)"
  elif [ -f "$PLAN_SCRATCH" ]; then
    echo "PLAN: $PLAN_SCRATCH (scratch)"
  else
    echo "PLAN: NONE"
  fi
fi
```

**If PLAN is FATAL_NO_REPO:** stop immediately. Tell the user: "This directory is not a git repository. Gauntlette needs a git repo to locate plans across agents. Run `git init` or re-run `/gauntlette-start` which will initialize one for you." Do not proceed with the skill.
