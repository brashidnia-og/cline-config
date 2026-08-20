---
name: security-review
description: Perform a focused application security review of code, diffs, designs, APIs, authentication/authorization, sensitive data, browser/server boundaries, dependencies, or infrastructure configuration. Use when the user asks for a security audit/review, auth check, tenant isolation review, vulnerability assessment, or when a change is explicitly security-sensitive. Skip for trivial typos/renames/one-line copy fixes.
---

# Security review

Goal: identify concrete reachable security failures and propose practical fixes without confusing theoretical possibilities with exploitable paths.

## 1. Define assets and trust boundaries

Identify:
- protected data/actions,
- users/roles/tenants/services,
- entry points and untrusted inputs,
- authentication boundary,
- authorization/ownership enforcement points,
- persistence/external-service/browser boundaries,
- secrets and privileged credentials.

Trace a real request/data path before making findings.

## 2. Core review areas

As applicable inspect:
- authentication/session/token validation,
- authorization, ownership, tenant isolation,
- object-level access control and user-controlled IDs,
- input validation/canonicalization,
- SQL/command/template/HTML injection,
- XSS/CSRF/CORS/cookie settings,
- SSRF/open redirects/outbound URL validation,
- file/path traversal and upload handling,
- deserialization/parser abuse,
- secret exposure and sensitive logs,
- cryptographic misuse/key/nonce/randomness handling,
- rate limits/resource exhaustion,
- replay/idempotency,
- dependency/supply-chain exposure,
- overly broad infrastructure permissions,
- debug/admin endpoints and environment separation.

Do not rely on UI/client checks as security enforcement.

## 3. Evidence and finding threshold

For a finding establish:
- attacker-controlled input/capability,
- reachable path,
- missing/broken control,
- impact,
- confidence,
- safe reproduction or test when appropriate.

Separate confirmed vulnerabilities from defense-in-depth suggestions. Do not inflate severity for hypothetical chains that require unsupported assumptions.

## 4. Browser security

Use local-playwright for controlled user-flow/authz checks in test/non-production accounts.
Use local-chrome-devtools to inspect cookies, network requests, CORS/CSP behavior, client-bundle exposure, and console/runtime evidence when needed.

Never expose real tokens/cookies/secrets in reports or external tools. Do not perform destructive or unauthorized actions against production systems.

## 5. External research

Use external-context7 / local-context7 for version-specific security configuration semantics of frameworks/libraries.
Use external-brave-search / external-tavily for current official advisories/CVEs/release notes when freshness matters. Prefer vendor/maintainer/NVD-like primary sources and verify installed versions locally.

An advisory does not prove exploitability in this repository; determine whether the vulnerable feature/path/version is actually present.

## 6. Dependency findings

When audit tools flag packages:
- identify the installed transitive/direct version,
- verify whether affected code is reachable/used,
- understand fixed versions and compatibility,
- avoid dependency upgrades with large unrelated blast radius unless necessary.

## 7. Remediation quality

Prefer fixes that enforce the invariant at the authoritative boundary:
- server-side authz near data/action access,
- parameterized queries/structured APIs,
- allowlists and canonicalization at trust boundaries,
- least-privilege credentials,
- secure defaults and explicit failure.

Do not “fix” security by hiding errors, filtering only obvious strings, or relying on obscurity.

## 8. Verification

Create regression tests for reachable vulnerabilities when safe and practical. Verify negative cases: unauthorized user, wrong tenant, malformed input, replay/duplicate, missing/expired credentials, boundary values.

Do not run exploit-like destructive tests against unknown/non-test environments.

## 9. Final gate

Apply the universal quality gate from `00-core-global`. Confirm findings are reachable, authn vs authz is distinguished, and severity matches demonstrated impact.

Report scope, coverage, confirmed findings, lower-confidence concerns, validation, and remaining uncertainty.
