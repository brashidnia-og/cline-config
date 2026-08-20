---
paths:
  - "docs/**"
  - "**/README*"
  - "**/*.mdx"
  - "**/*.adoc"
---

# Documentation policy

Documentation should explain contracts, rationale, operations, and non-obvious behavior—not restate code.

## Document when material
Document as applicable:
- why a non-obvious design/tradeoff exists,
- domain invariants/business rules,
- public contracts and expected errors,
- failure/retry/timeout/cancellation/transaction semantics,
- security assumptions and trust boundaries,
- units/precision/time/ordering constraints,
- compatibility/migration/rollback behavior,
- external limitations/workarounds and removal conditions.

Do not require docstrings on every public symbol. Avoid comments that repeat names/types/control flow. Prefer better names/types when they eliminate the need for explanation.

## README and technical docs
Update setup/build/test/run instructions only from verified repository configuration. Update architecture/operations docs when the change materially changes those contracts.

Use ADRs for consequential durable decisions with alternatives/tradeoffs—not trivial implementation details.

For operationally significant systems document failure symptoms, diagnostic evidence, observability, safe rollback/recovery, and replay/data-repair safeguards where relevant.

## Accuracy gate
Before finalizing docs:
- verify facts against code/config/tests,
- verify commands/paths where practical,
- distinguish current behavior from proposals/future work,
- remove nearby statements made stale by the change,
- do not expose secrets/private data,
- ensure external claims are tied to an underlying source/version/date rather than “the MCP”.

Use Context7 (`external-context7` / `local-context7`) for version-specific library docs, Brave/Tavily (`external-brave-search` / `external-tavily`) for current official public references, Playwright (`local-playwright`) for user-facing UI procedures, Chrome DevTools (`local-chrome-devtools`) for browser diagnostic procedures, and `local-precision-math` for numerical examples when these materially improve correctness.
