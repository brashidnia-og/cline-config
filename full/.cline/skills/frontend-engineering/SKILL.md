---
name: frontend-engineering
description: Plan, implement, or review React + Vite + Redux frontend features, UI bugs, state design, accessibility, performance, or component architecture. Use for SPA UI work, Redux Toolkit/RTK Query changes, Vite build issues, or frontend reviews. Skip for trivial typos/renames/one-line copy fixes.
---

# Frontend engineering

Goal: ship correct, accessible UI with clear state ownership, matching repository patterns—not generic React advice.

## 1. Inspect first

Before proposing structure, inspect:
- existing component, routing, and folder conventions,
- store setup (slices vs RTK Query),
- styling system,
- test harness (Vitest, Testing Library, MSW, Playwright),
- installed React/Redux/Vite versions in `package.json`.

Use external-context7 / local-context7 for version-specific APIs after reading installed versions. Do not invent aliases, env keys, or store patterns absent from the repo.

## 2. Define UX and data ownership

Establish:
- user-visible acceptance criteria,
- loading / empty / error / success states,
- what lives in component state vs Redux vs URL vs server cache,
- authz assumptions (never rely on client-only enforcement for secrets or permissions).

## 3. Plan Redux/UI changes

When state changes:
- list slice fields or RTK Query endpoints,
- selectors (memoized where derived),
- thunks/listeners side effects,
- serializability constraints,
- migration impact on persisted state if any.

Prefer the smallest coherent UI + state change that matches existing patterns.

## 4. Implement

- Match the existing styling system; do not add a competing one.
- Obey hooks rules; clean up effects; stable list keys.
- Keep `VITE_*` free of secrets.
- Avoid selecting the entire Redux root state from components.

## 5. Verify

Narrow → broad as risk warrants:
- typecheck (`tsc --noEmit` or repo script),
- targeted Vitest/RTL tests,
- Playwright for critical E2E flows if configured,
- local-playwright / local-chrome-devtools for runtime evidence when UI behavior is unclear.

## 6. Final gate

Apply the universal quality gate from `00-core-global`. Explicitly call out accessibility and bundle risks remaining.
