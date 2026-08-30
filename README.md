# Cline + OpenCode profiles: full + lite

Local-model-oriented rules and skills for **Cline** and **OpenCode**. Correctness, evidence, and self-review matter more than raw speed.

Cline sources under `full/` and `lite/` are the source of truth. Install scripts copy them into Cline’s global dirs and **generate** OpenCode’s `AGENTS.md` by concatenating `.clinerules` (path-gated Cline rules become always-on sections with scope notes).

| Profile | Use when | Approx always-on rules |
|---------|----------|------------------------|
| [`full/`](full/) | Multi-stack work: Kotlin/JVM, TS/JS, **React+Vite+Redux**, Rust, Python, Docker, AWS CLI/CDK, deep reviews | Cline: ~7–9k tokens (path-gated). OpenCode: all rules always-on (~same size or larger) |
| [`lite/`](lite/) | Lean sessions focused on **planning** and **debugging** | ~1.5–2k tokens; +~0.7–1k when a skill loads |

## Install

Cline loads `.clinerules/` and `.cline/skills/` from a project root (nested folders under `.clinerules/` are loaded recursively). Global rules/skills apply across projects.

OpenCode loads global rules from `~/.config/opencode/AGENTS.md` and skills from `~/.config/opencode/skills/*/SKILL.md`.

### Global (recommended after cloning)

Scripts detect **macOS** or **Linux** and install into **both** Cline and OpenCode user directories, then merge MCP servers into Cline settings:

| | macOS | Linux |
|-|-------|-------|
| Cline Rules | `~/Documents/Cline/Rules` | `$XDG Documents/Cline/Rules` (fallback `~/Cline/Rules` if Documents is missing) |
| Cline Skills | `~/.cline/skills` | `~/.cline/skills` |
| OpenCode Rules | `~/.config/opencode/AGENTS.md` | `$XDG_CONFIG_HOME/opencode/AGENTS.md` (default `~/.config/opencode/AGENTS.md`) |
| OpenCode Skills | `~/.config/opencode/skills` | same under `$XDG_CONFIG_HOME` |
| MCP (Cline only) | Code / Cursor `…/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` and `~/.cline/data/settings/cline_mcp_settings.json` | same pattern under `~/.config/…` |

```bash
./bin/install-full.sh    # or ./bin/install-lite.sh
./bin/install-full.sh -n # dry-run
./bin/install-full.sh --skip-mcp        # rules/skills only (both tools)
./bin/install-full.sh --skip-opencode   # Cline (+ MCP) only
./bin/install-full.sh --skip-cline      # OpenCode only
./bin/install-mcp.sh                    # MCP merge only
```

Requires `python3` to generate OpenCode `AGENTS.md`.

After install: reload Cline / start a **new** OpenCode session so `AGENTS.md` and skills are picked up.

### Project (Cline only)

```bash
./bin/install-full.sh --project /path/to/your-project
./bin/install-lite.sh --project /path/to/your-project
```

Project install copies Cline rules/skills only (no OpenCode project files). MCP config is **global** — run `./bin/install-mcp.sh` separately.

Or manually for Cline:
```bash
cp -a full/.clinerules full/.cline /path/to/your-project/
cp -a lite/.clinerules lite/.cline /path/to/your-project/
```

### OpenCode generation notes

- `AGENTS.md` is **generated at install time** from `.clinerules/**/*.md` (sorted). Do not hand-edit the installed file; re-run the install script.
- Cline `paths:` frontmatter is stripped; a scope note is prepended so OpenCode still sees intended file globs.
- Blatant “running through Cline” wording is rewritten to tool-agnostic phrasing in the generated file only.
- **Token cost:** OpenCode has no path-conditional loading, so the `full` profile puts lang/cmd rules always-on. Prefer `lite` for small OpenCode contexts, or use `--skip-opencode` if you only want Cline.

### macOS notes

The scripts are cross-platform and detect macOS automatically, but macOS has two
quirks worth knowing before relying on environment variables:

1. **GUI-launched editors don't inherit your shell env.** VS Code / Cursor /
   Cline opened from the Dock or Spotlight do not read `~/.zprofile`, so exported
   keys/URLs (`SEARXNG_URL`, `BRAVE_API_KEY`, …) won't reach the MCP servers.
   Either launch the editor from a terminal (`code .` / `cursor .`), or use
   `launchctl setenv VAR value`. Details in [`mcp/env.example.sh`](mcp/env.example.sh).
   `local-precision-math` is exempt — its `PATH` is pinned by the installer.
2. **Bun** is only needed by `local-precision-math`. If it's missing, install it
   with `curl -fsSL https://bun.sh/install | bash` or `brew install oven-sh/bun/bun`,
   or run `./bin/install-mcp.sh --install-bun` to do it for you (explicit opt-in).

Verify a fresh machine **before** writing anything with the read-only pre-flight:

```bash
./bin/install-mcp.sh --check     # reports OS, python3/npx/bun, env vars, target files
```

## MCP servers

Template: [`mcp/cline_mcp_settings.template.json`](mcp/cline_mcp_settings.template.json). Naming:

| Prefix | Meaning |
|--------|---------|
| `local-*` | Local data plane (no third-party SaaS for tool payloads) |
| `external-*` | Queries/content go to a vendor API |

Defaults after install: **`local-*` enabled** except **`local-context7`** (disabled placeholder) and **`local-searxng`** (needs `SEARXNG_URL`); **`external-*` installed but disabled**. Toggle by editing `"disabled"` in the JSON (prefer that over the Cline UI toggle — see [cline#9065](https://github.com/cline/cline/issues/9065)). Re-running install upserts package server keys but **preserves** existing `disabled` / `timeout` / `autoApprove` / `args` (not `env` — template/`install-mcp.sh` owns `env` so CLI+IDE stay compatible). StreamableHttp `url` fields must be literal valid URLs (never `${env:…}`).

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

**SearXNG (`local-searxng`):** export `SEARXNG_URL` from `~/.zprofile` / `~/.profile` (or Linux `~/.config/environment.d/*.conf` for GUI apps; example with SSH tunnel local `8180` → remote `8080`: `http://127.0.0.1:8180`), set `"disabled": false` on `local-searxng`, keep the tunnel up, fully relaunch Cline/IDE. See [`mcp/env.example.sh`](mcp/env.example.sh). Optional local instance: [`mcp/docker-compose.searxng.yml`](mcp/docker-compose.searxng.yml).

Secrets / URLs: export into the **host process** environment using [`mcp/env.example.sh`](mcp/env.example.sh), then **fully quit and relaunch** Cline/IDE. Stdio MCP servers inherit that env on both Cline CLI and the IDE extension (do not use `${env:VAR}` passthroughs in MCP JSON — CLI does not expand them). Risk matrix: [`mcp/SECURITY.md`](mcp/SECURITY.md).

`local-precision-math` needs [Bun](https://bun.sh) (`npx` alone is not enough — the package’s entrypoint is `#!/usr/bin/env bun`). Without Bun you get `MCP error -32000: Connection closed`. `install-mcp.sh` materializes `PATH` to `$HOME/.bun/bin:$PATH` for that server.

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
