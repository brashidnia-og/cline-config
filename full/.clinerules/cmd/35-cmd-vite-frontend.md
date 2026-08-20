---
paths:
  - "**/vite.config.*"
  - "**/vitest.config.*"
  - "**/playwright.config.*"
  - "**/index.html"
  - "**/src/main.{tsx,jsx,ts,js}"
  - "**/src/App.{tsx,jsx,ts,js}"
---

# Vite frontend command policy

Inspect `package.json` scripts and Vite/Vitest/Playwright configs before running. Prefer the lockfile’s package manager.

## Generally safe local validation
When scripts are local-only build/test/dev:
```bash
npm run dev
pnpm dev
yarn dev
npm run build
pnpm build
yarn build
vite build
npm run preview
pnpm preview
yarn preview
vite preview
vitest run
vitest run path/to/test
vitest related
npx playwright test
```

Use `timeout` for long-running `dev` servers when only a smoke check is needed. Prefer targeted Vitest paths over full suites by default.

## Not auto-approved
- Deploying preview builds to external hosts
- Installing new Vite plugins or frontend dependencies to silence errors
- Production CDN/CloudFront invalidations or AWS deploys for static assets unless explicitly requested
- `playwright test --ui` unless the user wants an interactive session
