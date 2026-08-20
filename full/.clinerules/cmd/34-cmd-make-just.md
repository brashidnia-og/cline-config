---
paths:
  - "**/Makefile"
  - "**/makefile"
  - "**/Justfile"
  - "**/justfile"
---

# Make and Just command policy

Inspect the Makefile/Justfile before running targets. Target names do not prove safety.

## Generally safe inspection
```bash
make -n
make help
just --list
just --summary
```

## Local validation
Run **named** repository targets only after reading their recipes and confirming they are local build/test/check (not deploy/publish/migrate/prod).

## Not auto-approved
Do not automatically run targets suggesting deploy, publish, release, push, prod, migrate, seed, reset, drop, destroy, or cloud mutation.
