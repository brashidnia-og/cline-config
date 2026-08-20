# Cline profiles: full + lite

Local-model-oriented Cline rules and skills. Correctness, evidence, and self-review matter more than raw speed.

| Profile | Use when | Approx always-on rules |
|---------|----------|------------------------|
| [`full/`](full/) | Multi-stack work: Kotlin/JVM, TS/JS, **React+Vite+Redux**, Rust, Python, Docker, AWS CLI/CDK, deep reviews | ~7–9k tokens (all rules enabled) |
| [`lite/`](lite/) | Lean sessions focused on **planning** and **debugging** | ~1.5–2k tokens; +~0.7–1k when a skill loads |

## Install

Cline loads `.clinerules/` and `.cline/skills/` from a project root (nested folders under `.clinerules/` are loaded recursively). Global rules/skills apply across projects.

### Global (recommended after cloning)

Scripts detect **macOS** or **Linux** and copy into Cline’s user directories:

| | macOS | Linux |
|-|-------|-------|
| Rules | `~/Documents/Cline/Rules` | `$XDG Documents/Cline/Rules` (fallback `~/Cline/Rules` if Documents is missing) |
| Skills | `~/.cline/skills` | `~/.cline/skills` |

```bash
./bin/install-full.sh    # or ./bin/install-lite.sh
./bin/install-full.sh -n # dry-run
```

### Project (one repo only)

```bash
./bin/install-full.sh --project /path/to/your-project
./bin/install-lite.sh --project /path/to/your-project
```

Or manually:
```bash
cp -a full/.clinerules full/.cline /path/to/your-project/
cp -a lite/.clinerules lite/.cline /path/to/your-project/
```

No manifest or packaging metadata is required. MCP servers (Context7, Tavily, Playwright, Chrome DevTools, etc.) are assumed configured separately—rules do not embed secrets.

## Full layout

```text
full/
├── .clinerules/
│   ├── 00-core-global.md
│   ├── 50-code-style-architecture.md
│   ├── 60-testing-policy.md
│   ├── 70-domain-finance-mcp.md
│   ├── 90-documentation.md
│   ├── cmd/          # command allow/deny policies
│   └── lang/         # language guidelines
└── .cline/skills/    # 7 skills incl. frontend-engineering
```

Highlights in `full/`:
- Expanded cmd whitelists (git fetch, jq/timeout, compose, AWS CLI/CDK read-only, Python, Vite, pnpm/yarn/bun, Make/Just, gh read-only)
- **No Go, no Terraform**
- React + Vite + Redux lang rules + `frontend-engineering` skill
- Finance MCPs path-gated in `70-domain-finance-mcp.md`

## Lite layout

```text
lite/
├── .clinerules/
│   ├── 00-core-global.md
│   ├── 50-verify.md
│   └── cmd/10-cmd-safety.md
└── .cline/skills/
    ├── change-planning/
    └── deep-debugging/
```

Planning and debugging procedures live in **skills** so always-on context stays small.

## Iteration advice

Change one concern at a time and observe local-model behavior. Keep `00-core` from becoming a handbook—push procedures into skills. Prefer path-gated lang/cmd rules in `full/` for stack-specific depth.
