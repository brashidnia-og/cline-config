---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/package.json"
  - "**/package-lock.json"
  - "**/npm-shrinkwrap.json"
  - "**/pnpm-lock.yaml"
  - "**/yarn.lock"
  - "**/bun.lock"
  - "**/bun.lockb"
---

# Node, npm, pnpm, yarn, bun, and npx command policy

Inspect `package.json` scripts and relevant config before executing unfamiliar package-manager commands. Repository scripts are executable code. Prefer the lockfile’s package manager (`npm` / `pnpm` / `yarn` / `bun`).

## Generally safe inspection
```bash
node --version
npm --version
npx --version
pnpm --version
yarn --version
bun --version
npm list
npm ls
npm explain
npm view
npm outdated
npm audit
npm config get
npm pkg get
pnpm list
yarn list
bun pm ls
node --check <file>
```
Some inspection commands contact the registry but should not mutate project state.

## Local validation after script inspection
Commonly acceptable when definitions are local build/test/check only:
```bash
npm test
npm run test
npm run test:unit
npm run test:integration
npm run lint
npm run typecheck
npm run check
npm run build
pnpm test
pnpm run lint
pnpm run typecheck
pnpm run build
yarn test
yarn lint
yarn build
bun test
bun run lint
bun run build
```

Prefer targeted repository-owned tools when present:
```bash
npx tsc --noEmit
npx eslint <target>
npx prettier --check <target>
npx vitest run path/to/test.ts
npx vitest run -t "specific behavior"
npx jest path/to/test.ts
npx jest -t "specific behavior"
```

Do not assume `test`, `build`, or `check` is safe solely from its name—inspect the script body first.

## npx
`npx` can download and execute packages. Automatically use it only when the package is already declared/installed by the repository or explicitly approved. Do not execute arbitrary newly downloaded packages as an exploratory shortcut.

## Not auto-approved
Do not automatically run `npm|pnpm|yarn|bun` install/add/remove/update/`ci`, link, publish, login/logout, init, version, or other dependency/registry mutations. Do not use `eslint --fix` or `prettier --write` merely for inspection.
