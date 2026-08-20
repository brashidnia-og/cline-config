# Cline profiles: full + lite

Local-model-oriented Cline rules and skills. Correctness, evidence, and self-review matter more than raw speed.

| Profile | Use when | Approx always-on rules |
|---------|----------|------------------------|
| [`full/`](full/) | Multi-stack work: Kotlin/JVM, TS/JS, **React+Vite+Redux**, Rust, Python, Docker, AWS CLI/CDK, deep reviews | ~7–9k tokens (all rules enabled) |
| [`lite/`](lite/) | Lean sessions focused on **planning** and **debugging** | ~1.5–2k tokens; +~0.7–1k when a skill loads |

## Install

Cline loads `.clinerules/` and `.cline/skills/` from a project root (nested folders under `.clinerules/` are loaded recursively). Global rules/skills apply across projects.

### Global (recommended after cloning)

Scripts detect **macOS** or **Linux** and copy into Cline’s user directories, then merge MCP servers into Cline settings:

| | macOS | Linux |
|-|-------|-------|
| Rules | `~/Documents/Cline/Rules` | `$XDG Documents/Cline/Rules` (fallback `~/Cline/Rules` if Documents is missing) |
| Skills | `~/.cline/skills` | `~/.cline/skills` |
| MCP | Code / Cursor `…/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` and `~/.cline/data/settings/cline_mcp_settings.json` | same pattern under `~/.config/…` |

```bash
./bin/install-full.sh    # or ./bin/install-lite.sh
./bin/install-full.sh -n # dry-run
./bin/install-full.sh --skip-mcp   # rules/skills only
./bin/install-mcp.sh     # MCP merge only
```

### Project (one repo only)

```bash
./bin/install-full.sh --project /path/to/your-project
./bin/install-lite.sh --project /path/to/your-project
```

Project install copies rules/skills only. MCP config is **global** — run `./bin/install-mcp.sh` separately.

Or manually:
```bash
cp -a full/.clinerules full/.cline /path/to/your-project/
cp -a lite/.clinerules lite/.cline /path/to/your-project/
```

## MCP servers

Template: [`mcp/cline_mcp_settings.template.json`](mcp/cline_mcp_settings.template.json). Naming:

| Prefix | Meaning |
|--------|---------|
| `local-*` | Local data plane (no third-party SaaS for tool payloads) |
| `external-*` | Queries/content go to a vendor API |

Defaults after install: **`local-*` enabled** except **`local-context7`** (disabled placeholder) and **`local-searxng`** (needs `SEARXNG_URL`); **`external-*` installed but disabled**. Toggle by editing `"disabled"` in the JSON (prefer that over the Cline UI toggle when using `${env:…}` — see [cline#9065](https://github.com/cline/cline/issues/9065)). Re-running install upserts package server keys but **preserves** existing `disabled` / `timeout` / `autoApprove` / `args` / `env` on those keys. Never put an unset `${env:…}` in a streamableHttp `url` — Cline validates URLs after env expansion and rejects the whole file.

| Server | Role |
|--------|------|
| `local-playwright` | Browser automation / flow reproduction |
| `local-chrome-devtools` | Console / network / performance |
| `local-precision-math` | Calculations / verification (requires [Bun](https://bun.sh); package shebang is `bun`, not Node) |
| `local-searxng` | Web search via your SearXNG (`SEARXNG_URL`) |
| `local-context7` | Disabled placeholder only — prefer `external-context7` |
| `external-brave-search` / `external-tavily` | Vendor web search / research |
| `external-context7` | Library/API docs (Context7 / Upstash) |
| `external-ref` / `external-deepwiki` | Alternate docs RAG |

**SearXNG (`local-searxng`):** export `SEARXNG_URL` from `~/.zprofile` / `~/.profile` (example with SSH tunnel local `8180` → remote `8080`: `http://127.0.0.1:8180`), set `"disabled": false` on `local-searxng`, keep the tunnel up, fully relaunch the IDE. See [`mcp/env.example.sh`](mcp/env.example.sh). Optional local instance: [`mcp/docker-compose.searxng.yml`](mcp/docker-compose.searxng.yml).

Secrets / URLs: export from login profile using [`mcp/env.example.sh`](mcp/env.example.sh), then **fully quit and relaunch** the IDE. Requires Cline ≥ 3.43 for `${env:VAR}` expansion. Risk matrix: [`mcp/SECURITY.md`](mcp/SECURITY.md).

`local-precision-math` needs [Bun](https://bun.sh) (`npx` alone is not enough — the package’s entrypoint is `#!/usr/bin/env bun`). Without Bun you get `MCP error -32000: Connection closed`. The template prepends `$HOME/.bun/bin` to `PATH` for that server.

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
- Finance MCP *routing* path-gated in `70-domain-finance-mcp.md` (servers not auto-installed)

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
