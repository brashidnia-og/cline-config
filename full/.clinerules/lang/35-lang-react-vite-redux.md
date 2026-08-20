---
paths:
  - "**/*.{tsx,jsx}"
  - "**/vite.config.*"
  - "**/vitest.config.*"
  - "**/src/**/*.{ts,tsx}"
  - "**/store/**"
  - "**/features/**"
  - "**/hooks/**"
  - "**/components/**"
---

# React, Vite, and Redux language rules

Follow repository conventions. Prefer Redux Toolkit unless the repo is clearly legacy Redux. For deep UI/feature work activate the `frontend-engineering` skill.

## React
- Function components + hooks only unless the repository already uses class components.
- Obey Rules of Hooks; keep effect dependencies correct and minimal.
- Prefer derived state over synchronizing state in effects; clean up subscriptions and use `AbortController` for fetches.
- Prefer composition and custom hooks over deep prop-drilling explosions.
- Lists: stable keys (not array index for dynamic lists); never mutate props or state.
- Place error boundaries at route/feature edges; do not silently swallow render errors.
- Avoid storing non-serializable values in state that must persist or hydrate.

## Vite
- Expose client config only via `import.meta.env` with `VITE_` prefix; never put secrets in `VITE_*`.
- Prefer ESM imports; respect `public/` vs `src/assets` conventions.
- Trust repository `vite.config.*` for aliases/proxy; do not invent config without inspecting it.
- Keep modules HMR-friendly: avoid surprising top-level side effects that break Fast Refresh.

## Redux (Toolkit-first)
- Prefer `createSlice`, and `createAsyncThunk` or RTK Query as the repo already uses; do not hand-roll switch reducers unless matching existing code.
- Normalize entity collections; keep ephemeral UI state in components; keep server cache in RTK Query or dedicated slices per repo pattern.
- Use memoized selectors (`createSelector`) for derived data; do not select the entire root state in components.
- Rely on Immer inside slices; never mutate state outside reducers.
- Put side effects in thunks, listener middleware, or RTK Query—not ad-hoc `store.dispatch` from deep utilities unless that is an established pattern.
- Keep state serializable (no class instances, Maps, functions, or DOM nodes in the store).

## UI quality
- Accessibility: semantic HTML, labels, keyboard access, sensible focus; ARIA only when needed.
- Follow the existing styling system (CSS modules, Tailwind, MUI, etc.); do not introduce a second system.
- Provide loading, empty, error, and success states for async UI; prevent duplicate submits.
- Prefer existing route-level code splitting; do not add heavy dependencies without need.

## Testing
- Prefer Testing Library + user-event flows over implementation-detail assertions.
- Use MSW (or the repo’s network test boundary) when present; avoid wholesale store mocks when an integration harness exists.
