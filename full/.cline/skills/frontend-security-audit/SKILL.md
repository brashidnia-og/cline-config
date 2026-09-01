---
name: frontend-security-audit
description: Security audit for React + Vite + Redux frontends — XSS sinks, CSP, env leakage, npm supply chain, JWT/cookie storage (RFC 10017), WalletConnect/Reown, SIWE, and Cosmos/Provenance wallet flows. Use with security-audit-core for browser clients and wallet integrations. Not for pure backend APIs (backend-security-audit) or smart contracts (smart-contract-security-audit).
---

# Frontend security audit

Load `security-audit-core` first. This skill covers browser trust boundaries and client bundles.

## 1. Token and session storage (RFC 10017)

Ranked preference:
1. **BFF** — tokens never reach the browser JS runtime.
2. **In-memory access** + `HttpOnly` `Secure` `SameSite` refresh cookie.
3. **`localStorage` / `sessionStorage`** — XSS = full account compromise; only with strict CSP and no third-party scripts.

Cookie flag matrix: `HttpOnly`, `Secure`, `SameSite=Lax|Strict` for session cookies. **CSRF protection required** whenever any cookie carries auth (double-submit, same-site, or custom header).

Audit: where tokens are set, cleared on logout, and invalidated on `accountsChanged` / account switch.

## 2. React XSS sinks

Inspect:
- `dangerouslySetInnerHTML`, `innerHTML` assignments,
- `href` / `src` with `javascript:` or `data:` from user input,
- prop spreading (`{...props}`) onto DOM nodes,
- markdown/SVG renderers without sanitization,
- `window.__CONFIG__` / inline JSON bootstrap scripts.

Prefer framework escaping; use a maintained sanitizer (DOMPurify) when HTML is required.

## 3. Vite and build artifacts

- `import.meta.env.VITE_*` is **public** and statically inlined — audit every reference; never put secrets in `VITE_` vars.
- `build.sourcemap`: `false` or `hidden` in production.
- **Scan built `dist/`** for API keys, internal URLs, and tokens — not only source tree.

```bash
rg -n 'api[_-]?key|secret|password|Bearer ' dist/ 2>/dev/null | head -50
```

## 4. CSP for Vite/React

Production CSP should use per-response **nonce** + `strict-dynamic` (and `'self'`). `html.cspNonce` in Vite config is a placeholder — replace server-side per request.

`unsafe-eval` acceptable in **dev** only. Audit `frame-ancestors` for wallet/signature iframes.

## 5. Redux and client state

- Persisted auth slices (`redux-persist`) — what is stored and under which key.
- Redux DevTools enabled in production builds.
- Cache keys must include tenant/user/wallet address where applicable.
- Clear sensitive slices on logout **and** on wallet account change.

## 6. `postMessage` and embedding

- Exact-origin allowlists for `message` listeners; validate `event.origin` and `event.source`.
- `frame-ancestors` / `X-Frame-Options` on pages that host signature prompts.

## 7. Supply chain (OWASP A03)

Controls that mattered in 2025–26:
- Release-age gating: `min-release-age`, `minimumReleaseAge`, `npmMinimalAgeGate`.
- Lifecycle-script blocking defaults per package manager (`ignore-scripts` where safe).
- Provenance attestation proves build reproducibility, **not** that the commit was authorized.

```bash
command -v osv-scanner >/dev/null && osv-scanner scan -r . -f json -o .audit/scans/osv-frontend.json
npm audit --json > .audit/scans/npm-audit.json 2>/dev/null || true
```

Do not run `npm audit fix` autonomously (mutates lockfile; may run package scripts).

## 8. WalletConnect / Reown (EVM)

- `projectId` origin allowlist — misconfiguration allows cross-origin abuse.
- Verify API is wallet-side; app must still validate chain, recipient, and amounts.
- Pairing-URI phishing — educate/display domain binding in UI.
- Minimum namespace/method scoping in session proposals.
- Revalidate `chainId` after `session_update` and before signing.
- `personal_sign` vs EIP-712: blind signing risks — `Permit` / `Permit2` unlimited-allowance drainers; prefer ERC-7730 clear-signing descriptors when available.

### SIWE checklist
- Server-controlled `domain` and `uri`.
- Single-use nonce; cleared after verify; rate-limit `/nonce` and `/verify`.
- Include `chainId`, `expirationTime`; verify EIP-1271 for contract wallets.
- Encrypted session cookies after verify.
- `accountsChanged` must invalidate **server** session, not only client state.

## 9. Cosmos / Provenance wallet flows

- **ADR-36 `signArbitrary`:** no chain binding, ordering, or replay protection — bind domain, nonce, expiry, and intended action in the message yourself.
- `signOptions`: audit `preferNoSetFee`, `preferNoSetMemo`, `disableBalanceCheck` — user may pay unexpected fees.
- `experimentalSuggestChain` with attacker-controlled RPC/denoms — chain hijack.
- `@provenanceio/walletconnect-js` `signJWT`: wallet-generated, ~24h default — verify signature, derive address, enforce your own `aud`/`nonce`; treat custom `bridge` as untrusted relay.
- Group/authz: distinguish "signed message" from "authorized to act for" (`prohibitGroups` where applicable).

## 10. Browser evidence tools

Use `local-playwright` for controlled authz flows (test accounts only). Use `local-chrome-devtools` for cookies, network, CSP, and bundle inspection. Never exfiltrate real tokens to external MCPs.

## 11. Tooling

| Tool | Role |
|------|------|
| eslint-plugin-security | Express/Node patterns in frontend tooling |
| eslint-plugin-no-unsanitized | DOM XSS sinks |
| osv-scanner / npm audit | Dependency leads (triage required) |

Project-local ESLint plugins: `npm i -D eslint-plugin-security eslint-plugin-no-unsanitized` (document in report; do not install globally mid-audit).
