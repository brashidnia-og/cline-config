---
name: bugbot-review
description: Perform a rigorous Bugbot-style review of Git diffs, pull requests, staged changes, branches, or changed code. Use when the user asks for a code review, PR review, diff review, bugbot review, regression check, or to find bugs in recent changes. Skip for trivial typos/renames/one-line copy fixes.
---

# Bugbot review

Review for high-confidence correctness/security/reliability defects. Do not edit unless the user explicitly asks to fix/apply/patch findings.

## 1. Establish scope

Inspect:
```bash
git status --short
git diff --stat
```
Determine the requested diff source/base. Do not silently assume `origin/main`; prefer user-specified base, PR base, upstream tracking, or an evidence-based merge base.

Create a compact change inventory:
- files changed,
- API/DB/UI/infra/test categories,
- highest-risk files/contracts,
- validation already present in the diff.

## 2. Coverage ledger

Maintain review state in the response/task state rather than modifying the repository by default:

`File | Status | Hunks reviewed | Related context inspected | Findings/notes`

Statuses: Pending, Fully reviewed, Partially reviewed, Skipped: reason, Needs follow-up.

Inspect every non-trivial behavior-affecting hunk. For each ask:
- What behavior/contract changed?
- What inputs/states can reach it?
- What happens on null/invalid/boundary/concurrent input?
- What happens on failure/retry/partial success?

## 3. Mandatory caller/callee tracing

Trace related context when a change affects:
- exported/public APIs/components,
- DB queries/schema/migrations,
- auth/ownership/tenant boundaries,
- money/precision/balances,
- async/concurrency flows,
- serialization/events/cache formats,
- common/shared libraries.

Reviewing only the diff is insufficient when correctness depends on surrounding contracts.

## 4. Risk checklist

Look for:
- authorization vs authentication mistakes,
- tenant/ownership leakage,
- validation/canonicalization gaps,
- transaction scope and isolation mistakes,
- races/check-then-act/lost updates,
- idempotency/retry/duplicate defects,
- backward/forward compatibility problems,
- migration/rollback hazards,
- precision/rounding/unit errors,
- stale cache/hydration/server-client boundary errors,
- error swallowing or success-after-partial-failure,
- resource leaks/cancellation/timeouts,
- secret/sensitive logging/exposure,
- missing tests for risky behavior,
- React effect dependency loops or sync-effect anti-patterns,
- unstable list keys for dynamic collections,
- selecting the entire Redux root state in components,
- non-serializable values in Redux state,
- secrets exposed via `VITE_*` / client bundle env.

## 5. False-positive control

Do not report a hypothetical concern as a bug unless a realistic reachable path is established.

Every defect finding should state:
- severity,
- file/area,
- concrete trigger/state/path,
- violated contract/invariant,
- why existing validation does not prevent it,
- observable consequence,
- confidence (High/Medium/Low),
- concrete suggested fix,
- suggested test.

Separate:
- Confirmed defects,
- Likely defects requiring validation,
- Non-blocking maintainability observations,
- Test gaps.

A missing test alone is not automatically a product bug.

Severity:
- **Critical:** exploitable security, funds/data corruption, auth bypass, outage.
- **High:** serious correctness/core flow/tenant leakage/migration/race risk.
- **Medium:** reachable edge/failure/idempotency/transaction defect with material impact.
- **Low:** minor reachable defect or confusing behavior.

## 6. MCP evidence

Repository behavior must be grounded locally.
- Context7: verify version-specific external API/framework semantics.
- Tavily: current official advisories/release notes/known issues after sanitization.
- Playwright: reproduce changed UI behavior.
- Chrome DevTools: validate network/console/runtime behavior.
- remote-math: independently verify financial/precision/capacity calculations.

External evidence can strengthen a finding but cannot substitute for a reachable local path.

## 7. Validation

Run read-only/targeted validation when it materially confirms a suspected defect and is safe under command rules. Do not “fix” code just to prove a finding.

## 8. Final gate

Apply the universal quality gate from `00-core-global`. Also confirm every finding has a reachable trigger and that severity/confidence are not overstated.

Use structure: Scope, Summary, Diff Coverage, Findings, Validation, Remaining uncertainty.
