# Command execution safety

Terminal autonomy is for inspection, search, compilation, testing, debugging, and local verification—not for destructive/system/deployment actions.

## Default decision rule
A command may be run autonomously only when its effective behavior is understood and it is reasonably scoped, local, non-destructive, and relevant to the current hypothesis or acceptance criterion.

The executable name alone does not make a command safe. Arguments, shell composition, repository scripts, hooks, Gradle tasks, npm scripts, Cargo build scripts, Makefiles, CI tasks, and environment variables can change behavior.

Before an unfamiliar command:
1. State internally what fact it should establish.
2. Prefer the narrowest command that establishes it.
3. Inspect repository-defined task/script definitions first.
4. Determine whether it can mutate source/Git/dependencies/database/external systems or expose secrets.
5. If behavior is unknown or materially state-changing, inspect further or require approval.

## Do not auto-run
Without explicit authorization or clear user intent, do not run commands that:
- elevate privileges (`sudo`, `su`, `doas`),
- install/remove system software,
- delete/truncate arbitrary files,
- rewrite/discard Git history/work,
- add/remove/update project dependencies or lockfiles,
- mutate persistent databases,
- deploy/publish/release artifacts,
- mutate cloud/Kubernetes state or deploy via CDK/CLI,
- change system services,
- terminate unrelated processes,
- transmit secrets/private source to external endpoints.

Do not use `curl ... | sh`, `wget ... | bash`, or equivalent downloaded-code execution.

Compilation and tests may run autonomously only through repository-documented scripts/tasks after inspecting their definitions. Never invent install, deploy, or publish commands.

## Shell composition
Treat `&&`, `||`, `;`, pipes, command substitution, `xargs`, `eval`, `bash -c`, `sh -c`, `source`, and `exec` as part of the security boundary. Every composed operation must independently be safe.

`find ... -delete` is not safe because `find` is allowed. `git status && rm -rf build` is not safe because `git status` is allowed.

## Secrets
Do not dump `.env` or the full process environment when secrets may be present. Avoid exposing values whose names suggest `TOKEN`, `SECRET`, `PASSWORD`, `KEY`, `AUTH`, `COOKIE`, `SESSION`, `CREDENTIAL`, or `PRIVATE`.

## Validation order
Prefer:
1. targeted reproduction/test,
2. nearby tests,
3. compiler/type-check,
4. static analysis/lint,
5. affected-module suite,
6. broader suite when change risk warrants it,
7. browser/runtime verification when behavior requires it.

Always inspect exit status and actual failure/assertion output. Do not repeatedly rerun the same failing command without changing the hypothesis.
