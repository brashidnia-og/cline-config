---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
---

# TypeScript and JavaScript language rules

Follow repository conventions and existing framework boundaries.

## Types and contracts
- Prefer strict TypeScript types. Avoid `any`; use `unknown` at untrusted boundaries and narrow/validate it.
- Use discriminated unions for meaningful state machines/variant payloads.
- Do not use `as` casts to silence a type mismatch unless the runtime invariant has been established.
- Preserve runtime validation for network, storage, env, URL, or user-controlled input; static types do not validate runtime data.
- Do not mutate caller-owned/shared state. Local mutation of newly created private structures is acceptable when clearer or more efficient.

## Async/runtime behavior
- Handle rejected promises and cancellation/abort behavior where relevant.
- Do not introduce unbounded parallelism through `Promise.all` over unbounded collections.
- Consider retries, timeouts, duplicate requests, stale closures, and race conditions for async state.
- Preserve server/client boundaries. Never rely on client code to enforce authorization or protect secrets.

## Framework routing
- For Vite + React + Redux SPA work, follow `lang/35-lang-react-vite-redux.md`.
- Apply Next.js-specific notes (App Router, server/client components, hydration) only when `next.config.*` (or clear Next app structure) is present in the repository.
