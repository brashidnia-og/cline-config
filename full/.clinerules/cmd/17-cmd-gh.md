---
paths:
  - "**/.github/**"
  - "**/PULL_REQUEST_TEMPLATE*"
---

# GitHub CLI (gh) read-only policy

Use `gh` for inspection of PRs, issues, and workflow runs when the repository uses GitHub.

## Generally safe
```bash
gh pr view
gh pr diff
gh pr list
gh issue view
gh issue list
gh run list
gh run view
gh api repos/:owner/:repo --jq .default_branch
```

## Not auto-approved
Do not automatically run `gh pr create`, `gh pr merge`, `gh pr review --approve`, `gh release create`, `gh secret set`, or other mutating/authz-sensitive commands. Do not pass tokens or dump secrets via `gh api`.
