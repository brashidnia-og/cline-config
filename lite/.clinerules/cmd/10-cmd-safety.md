# Command safety (lite)

Terminal autonomy is for inspection, search, compile/test, and local verification—not destructive, system, or deploy actions.

## Decision rule
Run a command only when its effective behavior is understood, local, non-destructive, scoped, and relevant. Inspect repository scripts before running them. The binary name alone is not safety.

## Generally safe
```bash
pwd ls find rg fd cat head tail git status git diff git log git show
curl -sS --max-time 10 http://localhost:<port>/...
```
Plus repository-documented test/typecheck/lint/build after inspecting the script/task definition.

## Do not auto-run
`sudo`/`su`, system package install, arbitrary deletes, git history rewrite/push/reset --hard, dependency install/lockfile mutation, DB mutation, deploy/publish, cloud mutate (`cdk deploy`, etc.), `curl|sh`, secret env dumps.

Treat shell composition (`&&`, pipes, `xargs`, `eval`) as part of the security boundary—every part must be independently safe.

## Validation
Prefer targeted test → typecheck/lint → broader suite by risk. Inspect exit status and failure output. Do not rerun the same failing command without a new hypothesis.
