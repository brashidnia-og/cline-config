# Git command policy

Use Git primarily for state inspection, diff coverage, history/context, and final self-review.

## Generally safe read-only inspection
```bash
git status
git status --short
git diff
git diff --stat
git diff --name-only
git diff --cached
git diff --staged
git log
git log --oneline
git log -p
git show
git show <ref>:path
git blame
git branch
git branch --show-current
git rev-parse
git merge-base
git ls-files
git grep
git remote -v
git tag
git describe
git shortlog -sn
git stash list
git worktree list
git fetch
```

`git fetch` is allowed for read-intent remote update (no merge/rebase/pull). Do not fetch then auto-merge.

Preferred task start/end:
```bash
git status --short
git diff --stat
git diff
```

Existing uncommitted changes are user-owned. Distinguish pre-existing work from agent changes.

## Not auto-approved
Do not automatically run:
```bash
git add
git commit
git push
git pull
git merge
git rebase
git cherry-pick
git revert
git reset
git restore
git checkout
git switch
git clean
git stash
git stash pop
git stash apply
git tag <new-tag>
git branch -D
git worktree add
git worktree remove
```

These mutate repository state, rewrite history, or can alter/discard user work. Use only when explicitly requested/authorized and after confirming scope.
