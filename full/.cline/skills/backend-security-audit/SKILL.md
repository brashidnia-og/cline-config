---
name: backend-security-audit
description: Deep security audit for backend APIs and services — JWT/session auth, tenant isolation, SSRF, Spring Boot, Ktor, Node/Express/Fastify/Nest, and Django/FastAPI/Python. Use with security-audit-core for server-side code, microservices, BFFs, and auth middleware. Not for React/browser token storage (frontend-security-audit) or CosmWasm contracts (smart-contract-security-audit).
---

# Backend security audit

Load `security-audit-core` first. This skill covers server-side trust boundaries.

## 1. Cross-cutting controls

### JWT and sessions
- Algorithm confusion: reject `alg:none`; allowlist algorithms; verify `alg` matches JWKS key type.
- `kid` header as injection sink into JWKS URL or key lookup — validate format and resolve only from trusted JWKS.
- Require `aud` + `iss` when the issuer issues multi-audience tokens; reject token-type confusion (access vs ID vs refresh).
- JWKS caching: bound TTL; handle key rotation; fail closed on stale/missing keys.
- Refresh tokens: rotation with family invalidation; detect reuse; bind to client/device where applicable.

### Tenancy and authz
- Tenant boundary enforced **centrally** (middleware/filter) vs ad hoc per query — grep for queries missing tenant predicate.
- Object-level access: user-controlled IDs in path/body must map to ownership check at data layer.
- Idempotency keys scoped per tenant/user; rate limits keyed on authenticated principal + route, not only IP.

### SSRF and outbound HTTP
- Allowlist hosts/schemes; block link-local, metadata IPs, and private ranges after DNS resolution.
- `maxRedirects: 0` or validate each hop; pin resolved IP for the connection.
- Separate webhook URL validation from generic HTTP clients.

## 2. Spring / Spring Boot

- **Actuator:** `SecurityFilterChain` must protect actuator endpoints. CVE-2026-40976: `spring-boot-actuator-autoconfigure` 4.0.0–4.0.5 with `spring-boot-health` absent — fixed 4.0.6; verify filter chain, not only `management.endpoints.web.exposure`.
- `authorizeHttpRequests` rule **order** — first match wins; document permitAll vs authenticated paths.
- `@PreAuthorize` / `@Secured`: self-invocation bypasses proxy; private/final methods skip AOP — enforce at filter or public service boundary.
- Jackson polymorphic typing: `PolymorphicTypeValidator` generic-parameter bypass (GHSA-j3rv-43j4-c7qm; fixed 2.18.8 / 2.21.4 / 3.1.4) — avoid default typing; audit `@JsonTypeInfo`.
- SpEL in `@Value` / custom expressions; SnakeYAML loading; mass assignment via unbounded DTO binding.
- `Sort` / `Pageable` reaching raw `ORDER BY` — injection via `property` parameter.
- CORS: separate dev vs prod config; no `*` with credentials.
- Spring Security 7: `AntPathRequestMatcher` → `PathPatternRequestMatcher` migration — regression-test authorization paths.

## 3. Ktor

- Routes outside `authenticate {}` are public — no deny-by-default.
- `validate {}` must not return a principal unconditionally.
- Cookies: `secure`, `httpOnly`, `SameSite` explicitly set.
- Client sessions: sign **and** encrypt when storing sensitive state.
- `anyHost()` in CORS — treat as finding in production configs.

## 4. Node (Express, Fastify, Nest)

- `trust proxy` misconfiguration bypasses rate limits (`ERR_ERL_PERMISSIVE_TRUST_PROXY`, `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR`); suppressed validators are a finding.
- Prototype pollution: `__proto__`, `constructor`, merge sinks in middleware and template engines.
- `child_process` / `shell: true` with interpolated input; `path.join` does not confine — use `path.resolve` + root check.
- ReDoS in user-supplied regex; redirect-following HTTP clients (SSRF).
- Nest: global `ValidationPipe` with `whitelist` / `forbidNonWhitelisted`; per-route DTO gaps.
- Fastify: schema validation is per-route opt-in — unschema'd routes accept arbitrary JSON.

## 5. Python (Django, FastAPI)

- `manage.py check --deploy` as a gate for production settings.
- Django SQL escape hatches: `.extra()`, `RawSQL`, `cursor.execute` with f-strings.
- Pickle, `yaml.load` (unsafe), `tarfile` path traversal.
- Jinja2: confirm `autoescape` for HTML contexts.
- FastAPI: distinguish **identity** (authenticated) from **ownership** (authorized for resource).
- `Depends()` caching: same instance per request — safe for DB sessions, unsafe for per-user mutable state unless scoped.
- Pydantic v2: `model_construct()` skips validation; `extra="allow"`; lenient coercion on query params.
- Sync blocking I/O inside `async def` — DoS under concurrency.

## 6. Tooling (read-only; see `18-cmd-security-scanners.md`)

Run only if `command -v` succeeds; write output under `.audit/scans/`, digest before triage.

| Tool | Role | Notes |
|------|------|-------|
| semgrep / opengrep | SAST with vendored rules | Registry configs need network; `--metrics=off`. Semgrep Rules License is not OSS. |
| gitleaks | Secret detection | Use `git` / `dir` modes; `detect` subcommand deprecated. |
| osv-scanner | Dependency CVEs | v2 CLI; query lockfiles. |
| trivy | FS / lockfile scan | No cloud upload. |
| detekt | Kotlin AST rules | `ForbiddenMethodCall`; no taint analysis. |
| bandit | Python security | Required for Django `extra()`/`RawSQL` patterns. |
| ruff `--select S` | Python style security | Complements, does not replace, Bandit for framework-specific rules. |
| CodeQL | Deep SAST | License-gated; opt-in only when org permits. |

```bash
command -v osv-scanner >/dev/null && osv-scanner scan -r . -f json -o .audit/scans/osv.json
command -v gitleaks >/dev/null && gitleaks git --log-opts="--no-merges" -v 2>&1 | head -200 > .audit/scans/gitleaks.txt
command -v bandit >/dev/null && bandit -r src -f json -o .audit/scans/bandit.json 2>/dev/null || true
```

Install missing tools with `./bin/install-security-tools.sh --check` / `--install <group>` — never install mid-audit.

## 7. Recent vulnerability classes

_Dated notes fed back from `vulnerability-research` — verify before asserting._

- **2026-02:** Spring Boot actuator auth bypass when health autoconfigure absent (CVE-2026-40976) — confirm `SecurityFilterChain` on `/actuator/**`.
- **Jackson:** PolymorphicTypeValidator generic bypass (GHSA-j3rv-43j4-c7qm) — audit `@JsonTypeInfo` and default typing.
