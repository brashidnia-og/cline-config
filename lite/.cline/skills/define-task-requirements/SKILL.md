---
name: define-task-requirements
description: Elicit, challenge, and finalize implementation-ready requirements for a bounded task, feature, fix, or change. Use for unclear feature requests, ticket refinement, acceptance criteria, design gaps, and preparing a self-contained feature specification for an autonomous coding agent. Composes into define-product-requirements; does not write implementation code.
---

# Define task requirements

**Mission:** produce a self-contained, testable feature/task contract that a separate builder can execute without asking what behavior, scope, or success means. Read [references/requirements-contract.md](references/requirements-contract.md) for the canonical schema/readiness checklist and [references/git-workspace.md](references/git-workspace.md) for durable, Git-native file naming, status, branch/PR tracking and handoff. Use [assets/requirements-template.md](assets/requirements-template.md) as the structure, not as boilerplate.

## 1. Inspect and restate intent
Recover already-given answers from the request, code, README, existing requirements, issues, tests, constraints, and relevant user decisions. For existing systems trace entry points, callers, integrations, data formats, and behavior before proposing replacements. Identify the real user/actor, problem, desired outcome, existing vs desired behavior, and boundaries. Label VERIFIED (repository evidence), DECIDED (user-authorized intent), PROPOSED (default), and UNKNOWN. Never treat an unreviewed suggestion as a user decision.

## 2. Elicit the full behavioral contract
For all relevant journeys describe trigger, actor, prerequisites, normal flow, outputs, error/cancel/retry/recovery, invalid input, concurrency/races, edge cases, observability and operational consequences. Decide:
- Inclusion/exclusion and priority; exact user-visible workflows and states.
- Functional rules, parameters, limits, persistence, deletion, migrations, compatibility, external services and versions.
- Permissions, authentication/authorization, privacy/security, trust boundaries, abuse/rate/resource limits.
- Performance, device/browser/platform, accessibility, cost, telemetry and reliability budgets (measurable when material).
- Dependencies, rollouts/rollback, test fixtures and environments, feature acceptance and negative cases.
- Existing architectural/API invariants to preserve. Avoid choosing implementation details unless they constrain observable behavior or compatibility.

Use example-driven probing: **what two plausible implementations would disagree about?** Turn each disagreement into a requirement or explicit exclusion. Test stories against at least one success, failure, boundary and recovery example where relevant.

## 3. Gap register and adaptive questions
Keep an ID-tagged gap register with **impact, alternatives, recommendation, owner and disposition**:
- `BLOCKING_PRODUCT_DECISION`: materially different UX, permission, financial/privacy/data-safety behavior, irreversible action, or core scope. Ask user; do not guess.
- `RESEARCH_FIRST`: resolve from files, tests, docs, tool availability, technical evidence. Do not ask the user what code can answer.
- `SAFE_DEFAULT`: low-risk, reversible and bounded. Record the default, rationale, impact, and how to verify; explicitly distinguish from user approval.
- `DEFERRED`: excluded from this task; state consequence and non-goal.

Ask **1–3 related, decision-rich questions per round**, showing a recommended choice and concrete tradeoffs. Update the draft after each response, do not ask answered questions again. For ambiguous requests, show a useful draft before asking. If interaction is unavailable, produce a DRAFT with blockers, not fictitious READY. Escalation is for user decisions, not normal engineering discoveries.

## 4. Author the deliverable
Use the repository's existing task/PRD convention if present; otherwise create `product/work/requirements/YYYYMMDDTHHMMSSZ-task-name.md` (UTC, stable slug; see Git-workspace reference). This tracked file is the **ticket and the prompt**. Follow the [contract](references/requirements-contract.md): metadata with **separate** `requirements_status` and `delivery_status`, context, user stories, scope/non-goals, end-to-end flows, state/data/API/interface rules, nonfunctional/security/compatibility constraints, acceptance cases with stable IDs, verification strategy, dependencies, traceability, decision log, a gap register, and `## Delivery tracking` (actual branch/PR links, status history, owner, next action). Use explicit Gherkin-style Given/When/Then or equally falsifiable examples; include failure assertions, not just happy paths. For greenfield code, specify test *behavior and environment* even if exact commands do not yet exist.

For an existing repository, cite inspected paths/tests/versions; do not fabricate script names or claim tests were run. Every acceptance criterion should map to a test or verification method; mark manual/hardware checks and required evidence distinctly.

## 5. Run the builder-readiness gate
Independently challenge the draft (delegate read-only to `requirements-reviewer` where available): ambiguity, contradictions, missing states, impossible tests, cross-feature dependencies, integration gaps, unknown ownership, security/privacy, impossible budget, migration/rollout, and missing resources. Use realistic adversarial scenarios and counterexamples.

Set `requirements_status: READY` and `delivery_status: "READY TO BUILD"` **only when**:
1. Scope, behavior, precedence, exclusions and owner-approved consequential decisions are resolved.
2. Every in-scope behavior is tied to objectively checkable acceptance IDs, including critical failures.
3. Interfaces, state ownership and external assumptions are specified or safely delegated as bounded implementation choices.
4. Dependencies and prerequisites are feasible; a validation environment or explicit acceptance procedure is stated.
5. No `BLOCKING_PRODUCT_DECISION` or unresolved requirement contradiction remains. Safe defaults are recorded and bounded.
6. An independent builder could implement and verify without a product Q&A.

Otherwise `requirements_status: DRAFT` and `delivery_status: DEFINING` or `BLOCKED`, surface the exact blocking questions and continue only on separable READY work. READY means *requirements are decision-complete*, not that execution can never encounter a new blocker. Never auto-approve risk or production/destructive operations.

## 6. Handoff
Return the absolute or repo-relative requirements path, its status, acceptance coverage, decisions made, defaults, and any blocked dependencies. Do not start product code unless the user also requested implementation. The future builder reads the document as authoritative for product scope, but still checks current repository/runtime facts.
