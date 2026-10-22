# Cline profiles: full + lite

Shared engineering rules, skills, agents, and MCP configuration for **Cline, OpenCode, Cursor, Codex, Claude Code, and Hermes**. The `full` and `lite` profiles remain the source of truth; installers render each tool's native format.

| Profile | Use when | Approx always-on rules |
|---------|----------|------------------------|
| [`full/`](full/) | Multi-stack work: Kotlin/JVM, TS/JS, **React+Vite+Redux**, Rust, Python, Docker, AWS CLI/CDK, deep reviews | ~7–9k tokens (all rules enabled) |
| [`lite/`](lite/) | Lean sessions focused on **planning** and **debugging** | ~1.5–2k tokens; +~0.7–1k when a skill loads |

## Install

Cline loads `.clinerules/` and `.cline/skills/` from a project root (nested folders under `.clinerules/` are loaded recursively). OpenCode reads one global `AGENTS.md` and `SKILL.md` skills from `~/.config/opencode/skills/` (global) or `.opencode/skills/` (project). Global rules/skills apply across projects.

### Global (recommended after cloning)

Scripts detect **macOS** or **Linux** and install into the tools' user directories:

| | macOS | Linux |
|-|-------|-------|
| Cline rules | `~/Documents/Cline/Rules` | `$XDG Documents/Cline/Rules` (fallback `~/Cline/Rules` if Documents is missing) |
| Cline skills | `~/.cline/skills` | `~/.cline/skills` |
| OpenCode rules | `~/.config/opencode/AGENTS.md` (generated) | same |
| OpenCode skills | `~/.config/opencode/skills` | same |
| OpenCode agents | `~/.config/opencode/agents` (from `agents/catalog` + profile list) | same |
| Cursor agents | `~/.cursor/agents` (same catalog; Cursor frontmatter) | same |
| Cursor skills | `~/.cursor/skills` (game skills in full; design, state machines, variation, routing, and CLI logging skills in both profiles) | same |
| Codex rules, skills, agents | `~/.codex/AGENTS.md`, `~/.agents/skills`, `~/.codex/agents` | same |
| Claude Code rules, skills, agents | `~/.claude/CLAUDE.md`, `~/.claude/rules`, `~/.claude/skills`, `~/.claude/agents` | same |
| Hermes skills, core rules, delegation guide | `~/.hermes/skills/cline-config`, `~/.hermes/skills/cline-config-core`, `~/.hermes/skills/cline-config-delegation` | same |
| OpenCode models | `~/.config/opencode/opencode.jsonc` (`provider.local-llm` block refreshed best-effort from `$LLM_URL/models`) | same |
| MCP | Cline settings; Codex `~/.codex/config.toml`; Claude `~/.claude.json`; Hermes `~/.hermes/config.yaml` | same |

```bash
./bin/install-full.sh    # or ./bin/install-lite.sh
./bin/install-full.sh -n # dry-run (prints every destination/action, writes nothing)
./bin/install-full.sh --skip-mcp        # rules/skills/agents only
./bin/install-full.sh --skip-opencode   # skip OpenCode; install the other tools
./bin/install-full.sh --skip-codex --skip-claude --skip-hermes  # optional tool filters
./bin/install-mcp.sh     # MCP merge only
./bin/install-security-tools.sh -c   # report security scanners (read-only)
./bin/install-security-tools.sh -n --install all   # dry-run scanner install plan
./bin/install-opencode-config.sh        # refresh opencode.jsonc models from $LLM_URL/models (also run automatically, best-effort, by the two installers)
./bin/install-full.sh --skip-mcp --hermes-profile grok  # install Hermes content into existing profile grok
```

### Project (one repo only)

```bash
./bin/install-full.sh --project /path/to/your-project
./bin/install-lite.sh --project /path/to/your-project
./bin/install-full.sh --project /path/to/your-project --force   # replace an existing project AGENTS.md
```

Cline gets `.clinerules/` + `.cline/`; OpenCode gets `.opencode/skills/` + `.opencode/agents/`; Cursor gets `.cursor/agents/`, game skills (full profile), and the shared design/pattern/reliability skills described below plus `subagent-model-routing` and `cli-subagent-progress-logging` (both profiles). Codex gets `.agents/skills/` + `.codex/agents/`; Claude Code gets `CLAUDE.md` + `.claude/rules/`, `.claude/skills/`, and `.claude/agents/`. Codex, OpenCode, and Hermes share the generated project `AGENTS.md`. Project MCP settings go to `.codex/config.toml` and `.mcp.json`; Hermes MCP remains profile-scoped. A personal project `AGENTS.md` or `CLAUDE.md` is preserved unless `--force` is passed (a backup is made first). Hermes skills install in its default or selected profile, even in project mode.

### Codex, Claude Code, and Hermes

- All skills from the selected profile, including supporting files, install into each tool's discovery path. Managed skill directories carry `.cline-config-managed`; personal same-name skills are left alone. Switching profiles removes stale managed skills.
- The generated core delegation guidance (`AGENTS.md` / `CLAUDE.md` / Hermes core skill) points CLI child launches (`hermes chat`, test/build runners) at the `cli-subagent-progress-logging` skill: dual-output `tee` logging with `set -o pipefail` and an outcome + log-path report.
- The agent catalog renders as Codex TOML and Claude Code Markdown subagents. Hermes gets on-demand `cline-config-core` rules and uses `delegate_task` with `cline-config-delegation` for specialist role instructions; Hermes profiles are separate persistent assistants, not named task roles. [Codex agents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [Claude agents](https://code.claude.com/docs/en/sub-agents), [Hermes delegation](https://hermes-agent.nousresearch.com/docs/user-guide/features/delegation).
- MCP entries are translated from the Cline template. Codex and Hermes retain disabled servers as disabled entries. Claude Code receives the three enabled local servers; add optional external servers explicitly when needed, since Claude has no portable disabled-server entry. Existing same-name servers are preserved. Hermes `config.yaml` is backed up before merge; install PyYAML (`python3 -m pip install pyyaml`) for this merge, or pass `--skip-hermes`. The installer never changes the selected model, provider, or credentials.
- The script does not sign in to Hermes. Keep the existing model selection, or run `hermes model` and select **ChatGPT or Codex Subscription** for Codex OAuth, or **Custom endpoint** and enter the OpenAI-compatible `/v1` URL and model name for vLLM or a router. The installed content is provider independent. Hermes currently documents Claude OAuth only for Claude Max with purchased extra usage credits; it does not consume the included Max allowance, and Claude Pro is not supported through that OAuth path. [Hermes provider setup](https://hermes-agent.nousresearch.com/docs/integrations/providers).
- OpenCode also scans `.claude/skills` and `.agents/skills`; its own installed skills take precedence in current OpenCode V2. If a skill loads incorrectly, inspect all three locations and your installed OpenCode version. [OpenCode skill precedence](https://opencode.ai/v2/docs/skills).

### Game development skills

The full profile includes four reusable game-development skills:

| Skill | Use it for |
|-------|------------|
| `game-reference-to-spec` | Turn observations from other games into original, evidence-backed and testable design decisions. |
| `gameplay-code-quality` | Implement small, clear gameplay systems with explicit state ownership, useful reuse, and bounded per-frame work. |
| `godot-game-development` | Build and validate Godot scenes, scripts, resources, input, physics, imports, and target builds using the project's version and conventions. |
| `game-performance-profiling` | Measure a representative baseline, diagnose CPU/GPU/memory/loading bottlenecks, change one cause, and compare on target hardware. |

The read-only `game-performance-reviewer` agent checks profiler evidence and before/after claims in Cursor and OpenCode. The performance skill covers Godot now and includes the shared measurement process for Unity; a Unity-specific development skill will be added when there is a Unity project to validate it against.

### Design patterns and reliability (`full/` and `lite/`)

Both profiles include the following focused guides. Each supports explanation, planning, implementation, and review, starts with repository evidence and a fit check, and defines ownership, failure semantics, and meaningful verification. Examples are illustrative rather than assumed project APIs.

| Skill | Use it for |
|---|---|
| [`adapter-pattern`](full/.cline/skills/adapter-pattern/SKILL.md) | Translate incompatible external/legacy contracts, including types, errors, units, pagination, and capability limits. |
| [`dependency-injection`](full/.cline/skills/dependency-injection/SKILL.md) | Explicit collaborators, scopes/captive dependencies, cycles, container behavior, resource ownership, and wiring verification. |
| [`pipeline-and-chain-of-responsibility`](full/.cline/skills/pipeline-and-chain-of-responsibility/SKILL.md) | Ordered transformations, first-handler chains, and around middleware with explicit stopping and partial-failure semantics. |
| [`command-pattern`](full/.cline/skills/command-pattern/SKILL.md) | Deferred intent, execution-time validation, queued work, and bounded undo/redo history. |
| [`observer-and-events`](full/.cline/skills/observer-and-events/SKILL.md) | Subscription lifetime, event snapshots/order/reentrancy, listener failures, and local versus durable delivery. |
| [`composite-pattern`](full/.cline/skills/composite-pattern/SKILL.md) | Uniform leaf/group operations, tree versus shared-graph ownership, safe mutation, and bounded traversal. |
| [`idempotency-and-retries`](full/.cline/skills/idempotency-and-retries/SKILL.md) | Duplicate requests/effects, ambiguous timeouts, concurrent claims, retention, reconciliation, and retry budgets. |
| [`transactional-outbox`](full/.cline/skills/transactional-outbox/SKILL.md) | Atomic state plus publication intent, relay recovery, duplicate-safe consumers, ordering, and rollout/operations. |
| [`cache-design`](full/.cline/skills/cache-design/SKILL.md) | Identity/isolation, freshness/invalidation, stale fills, stampedes, resource bounds, and outage fallback. |

[`design-for-change`](full/.cline/skills/design-for-change/SKILL.md) owns the broader design and routes only unresolved focused concerns to these skills. It also includes [Factory, Builder, and composition-root guidance](full/.cline/skills/design-for-change/references/construction.md): direct construction versus factories, validated options/builders, dependency scopes, owned/borrowed resources, and partial-construction cleanup. `polymorphism-and-strategy`, `decorator-pattern`, and `state-machine-design` remain focused on interchangeable behavior, additive wrapping, and lifecycle transitions respectively.

The nine guides and the construction guidance each include two reusable scenarios in their skill's `evals/evals.json`: a substantive design case and a counterexample/misuse case. The repository tests validate their metadata, links, profile parity, bundled resources, and real installer destinations; these structural checks do not by themselves establish model-response quality.

`dependency-injection` distinguishes DI from IoC and the Dependency Inversion Principle, and treats containers as optional wiring tools. It covers constructor/function/method injection, captive scoped dependencies (including factory closures), background-job scopes, initialization/cancellation, and owned-versus-borrowed resource cleanup. Factory/Builder/composition-root selection stays in the existing construction reference; there are no separate competing IoC/DIP/container guides. Example prompt: `Use dependency-injection to review singleton/request scope capture and cleanup`.

Example prompts: `Use adapter-pattern to isolate this supplier API`, `Use command-pattern to design conflict-aware undo`, or `Use transactional-outbox to review the commit/publish crash windows`.

### Decorator pattern (`full/` and `lite/`)

[`decorator-pattern`](full/.cline/skills/decorator-pattern/SKILL.md) assesses, implements, and reviews composable wrappers that add behavior while preserving the caller-facing contract. It covers explicit wrapper ordering, delegation frequency, async/streaming behavior, cancellation, resource ownership, construction/DI wiring, and meaningful validation. It compares Decorator with strategies, adapters, proxies, existing middleware, and direct helpers, and distinguishes the structural pattern from language `@decorator` syntax.

`design-for-change` routes additive wrapping decisions to this skill and retains the broader design. A supporting reference illustrates an async timing wrapper and order-sensitive metrics/retry and authorization/cache combinations. Two reusable scenario prompts live in the skill's `evals/evals.json`.

Example prompts: `Use decorator-pattern to add optional metrics around this client` or `Review the authorization/cache/retry wrapper order using decorator-pattern`.

### State machine design (`full/` and `lite/`)

[`state-machine-design`](full/.cline/skills/state-machine-design/SKILL.md) helps recognize implicit lifecycles, design legal transitions, and refactor business/data-processing or gameplay logic incrementally. It compares machines with pipelines, strategies, and existing small switches; the number of branches alone does not justify a rewrite. Supporting references cover modeling choices, async attempts and durable-state migration, sequence testing, and gameplay timing/interruptions.

`design-for-change` routes lifecycle decisions into this skill and keeps ownership of the broader design. `polymorphism-and-strategy`, the lite planning skill, and the full gameplay/Godot skills also route relevant work to it. The skill uses the project's language, engine, and test tools; it adds no runtime dependency.

Example prompts: `Assess whether this job's retry/cancel logic should use a state machine` or `Use state-machine-design to model interruptible character actions and their tests`.

### 2D image to 3D character workflow

The full profile includes two linked skills:

1. `derive-3d-character-specs` reads concept art and writes a project-owned `character_specs.json` plus a readable model plan. It separates visible evidence from invented depth/back details.
2. `build-3d-game-characters` validates that handoff, builds editable assets, exports them, reviews consistent renders, integrates them into a playable engine sandbox, and tracks revisions and completion. It uses procedural modeling, Blender, or cleaned image-to-3D output according to the project and available tools.

The full profile also installs a read-only `character-art-reviewer` agent for Cursor and OpenCode. Invoke the skills by name in Cline, Cursor, Codex, or OpenCode; in Hermes use `/derive-3d-character-specs` and `/build-3d-game-characters`. The successful Godot case is documented inside both skills, but neither skill hard-codes its 18-character roster. The validation script and spec example travel with the skills.

Cursor receives the six game skills in full and 15 shared skills in both profiles: the nine pattern/reliability guides above, `design-for-change`, `decorator-pattern`, `polymorphism-and-strategy`, `state-machine-design`, `subagent-model-routing`, and `cli-subagent-progress-logging`. Codex, Claude Code, and Hermes receive all selected profile skills, including these. `--hermes-profile ID` targets an existing Hermes Bot/profile; the installer leaves that profile's model untouched.

Cursor and the new tool destinations use a `.cline-config-managed` marker. Reinstalling a profile replaces only managed skill directories; switching to lite removes managed full-only skills. An existing unmarked skill of the same name is left untouched with a note. If you downgrade to a revision from before these shared skills were added, that older Cursor installer cannot know to remove them; run `./bin/cursor-shared-skill-cleanup.sh` (or pass a skills directory) to remove managed design/routing skills from the script's explicit allowlist. Keep a copy of the current cleanup script before downgrading. Use `-n` to preview; unmarked same-name personal directories are preserved. The CLI progress-logging skill is outside that cleanup allowlist. OpenCode retains its existing profile-wide replacement behavior.

Or manually (Cline only — the OpenCode `AGENTS.md` is generated by the installer):
```bash
cp -a full/.clinerules full/.cline /path/to/your-project/
cp -a lite/.clinerules lite/.cline /path/to/your-project/
```

### OpenCode

OpenCode consumes a different layout than Cline, so the installer **generates** its inputs from the same profile sources instead of copying them:

| Cline | OpenCode | What the installer does |
|-------|----------|--------------------------|
| Rules dir (`.clinerules/`, per-file toggles) | one global `AGENTS.md` | concatenates every rule file into `AGENTS.md` (top-level, then `cmd/`, then `lang/`), each tagged `<!-- source: … -->` |
| `paths:`-gated rules | no path gating | the frontmatter is stripped and replaced by a prose condition (“apply only when the current work touches … matching `**/…`”) |
| `~/.cline/skills/` + per-skill toggles | `~/.config/opencode/skills/` (or `.opencode/skills/` per project) | the same `SKILL.md` folders, copied verbatim |
| (no Cline agent files) | `agents/*.md` subagents + Cursor `.cursor/agents/` | renders [`agents/catalog/`](agents/catalog/) via profile list into OpenCode + Cursor destinations |
| duplicate skill names: global wins over project | duplicate names **break skill discovery** | same-named project skills are skipped; identical global copies are reported as already present, while differing global copies produce a mismatch warning and are never overwritten. Refresh a cline-config-managed global copy with the global installer; personal global copies remain untouched and shadow the project copy. Collisions with `~/.claude/skills` or `~/.agents/skills` produce a warning (fix with `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` if a skill fails to load) |

Behavior worth knowing:

- `AGENTS.md` is **generated at install time, not stored** in this repo. Its first line carries a `cline-config:generated profile=<name>` marker so the installer can tell generated files from your own.
- Re-running the installer regenerates `AGENTS.md` (global and project). A pre-existing file **without** the marker (your own notes) is backed up to `AGENTS.md.bak-<timestamp>` first.
- The OpenCode skills directory is **replaced wholesale** on every install (same policy as the Cline side, so switching `full` ↔ `lite` leaves no stale skills). Personal skills you keep in `~/.config/opencode/skills/` are removed by a profile switch.
- Skill validation runs before anything is written: `name` must match the directory and match `^[a-z0-9]+(-[a-z0-9]+)*$` (≤64 chars); `description` must be ≤1024 chars. A profile violating these rules aborts the install.
- Generating `AGENTS.md` needs `python3`. Without it the Cline install still completes and the OpenCode step is skipped with a hint (or pass `--skip-opencode` to silence it).
- The global dir honors `XDG_CONFIG_HOME`; set `OPENCODE_CONFIG_DIR` to point the installer elsewhere.
- MCP servers are **not** exported to OpenCode yet (OpenCode reads `opencode.json`); that is a planned follow-up. The Cline MCP merge is unaffected.
- The `provider.local-llm` model list in `opencode.jsonc` is refreshed by `./bin/install-opencode-config.sh` (see [OpenCode model config](#opencode-model-config)); both installers run it best-effort.

### OpenCode model config

`./bin/install-opencode-config.sh` generates/refreshes the `provider.local-llm` block in `~/.config/opencode/opencode.jsonc` (honors `OPENCODE_CONFIG_DIR`, else `$XDG_CONFIG_HOME`, else `~/.config`) from the local OpenAI-compatible server:

```bash
./bin/install-opencode-config.sh            # uses $LLM_URL (default http://localhost:8000/v1)
LLM_URL=http://10.0.0.5:8000/v1 ./bin/install-opencode-config.sh
./bin/install-opencode-config.sh -n         # dry-run: query the server, print the resulting config, write nothing
./bin/install-opencode-config.sh --url URL  # one-off override of $LLM_URL
```

Semantics:

- Queries `$LLM_URL/models` and sets `options.baseURL` to `$LLM_URL` plus `options.headerTimeout: false` (local prefills can exceed OpenCode’s default header wait), writing one `"models"` entry per reported model id (sorted) — the config always mirrors the server.
- Each model is marked `"reasoning": true` and gets four OpenCode **variants** that set vLLM’s per-request `thinking_token_budget`: `2048`, `4096`, `8192`, `32768`. The base model (no variant) leaves the budget unset (unlimited). Select as `local-llm/<model>` or `local-llm/<model>#4096` (etc.).
- **Merges, does not clobber:** every other setting in `opencode.jsonc` (permissions, agents, other providers, …) is preserved byte-for-byte. The managed block is delimited by `// cline-config:begin local-llm` / `// cline-config:end local-llm` comments; re-runs rewrite only that block.
- A user-authored file (no markers) is backed up to `opencode.jsonc.bak-<timestamp>` before the first in-place merge; marker-bearing files are regenerated in place (no new backups).
- Refuses to write while an editor has the file open (`opencode.jsonc.swp` present), and never writes a file that fails post-validation (invalid JSON, or a provider block that does not match the fetched model list / expected variants).
- Standalone runs **hard-fail** (non-zero exit, file untouched) when the server is down, unreachable, or reports zero models.
- `install-full.sh` / `install-lite.sh` run this step **best-effort**: if the LLM server is unreachable they print a warning and the rest of the install still completes (`--skip-opencode` skips it).

### OpenCode subagents

Installers ship named specialist agents from [`agents/catalog/`](agents/catalog/) (profile lists: [`agents/full.list`](agents/full.list), [`agents/lite.list`](agents/lite.list)). Destinations:

| Scope | OpenCode | Cursor |
|-------|----------|--------|
| Global | `~/.config/opencode/agents/` | `~/.cursor/agents/` |
| Project (`--project`) | `<project>/.opencode/agents/` | `<project>/.cursor/agents/` |

Managed files carry `<!-- cline-config:managed -->`; unmarked agents you add yourself are left alone. Switching `full` ↔ `lite` removes managed agents not in the new list. Official docs: [opencode.ai/docs/agents](https://opencode.ai/docs/agents), [cursor.com/docs/subagents](https://cursor.com/docs/subagents).

**ELI5:** the primary agent is the foreman. A subagent gets a **fresh context**, does noisy search/review work there, and returns a **short report** so the main window does not fill up. Invoke with `@explore …` or ask the primary to use Task; parallel A/B/C is model-driven (multiple Task calls in one turn), not guaranteed.

**Skills + subagents:** each skill stays one methodology playbook. `00-core-global` picks **Delegated** (named `@agent`/Task on OpenCode/Cursor), **Research-assist** (Cline `use_subagents` for search only), or **Solo** (fallback / user said “solo”). Skills with a **Subagent fan-out** section name which agents handle noisy phases; the primary keeps ledgers, verdicts, and the final gate. Say “solo” or “no subagents” to force Solo for that turn. Sub-agents launched as CLI children (e.g. `hermes chat`, test/build runners) follow the `cli-subagent-progress-logging` skill instead — native sub-agent tools keep their own progress/result mechanisms.

**Track in OpenCode TUI:** child sessions; `<Leader>+Down` enter first child, `Left`/`Right` cycle, `Up` parent. Web UI is thinner.

**Cline:** no named agent files are installed. Use skills plus Cline’s built-in read-only `use_subagents` research feature.

**`full` agents (17):**

| Agent | Role | Edits? |
|-------|------|--------|
| `explore` | Codebase map / search | No |
| `general` | Multi-step child worker | Yes |
| `planner` | Design before edits | No |
| `architecture-reviewer` | Independent design challenge for substantial changes | No |
| `code-reviewer` | Diff/PR review | No |
| `security-auditor` | Security pass | No |
| `debugger` | Root-cause diagnosis | No |
| `test-runner` | Run tests, summarize | Shell |
| `verifier` | Confirm work is done | Shell |
| `docs-writer` | Documentation | Docs only |
| `bash` | Noisy shell isolation | Shell |
| `browser-tester` | UI / browser MCP | Tools |
| `scout` | External deps/docs | No |
| `orchestrator` | Fan-out + synthesize | No |
| `db-reader` | Schema/SQL/data paths | No |
| `character-art-reviewer` | Visual QA of character specs and renders | No |
| `game-performance-reviewer` | Review profiling evidence and performance claims | No |

**`lite`:** `explore`, `planner`, `debugger`, `general`, `code-reviewer`, `orchestrator`, `scout`.

Same names as some product built-ins (`explore` / `general` / `scout` / `bash`) so `@explore` still works with our local-model prompts. Do not confuse `planner` with OpenCode’s primary `plan` agent (Tab).

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

## Security auditing (`full/`)

Five audit skills replace the old generic `security-review` skill:

| Skill | Use for |
|-------|---------|
| `security-audit-core` | Methodology, `.audit/` workspace, ledger, scanner triage, severity, report |
| `backend-security-audit` | JVM/Kotlin/Spring/Ktor, Node, Python APIs |
| `frontend-security-audit` | React/Vite/Redux, CSP, wallets, SIWE, supply chain |
| `smart-contract-security-audit` | CosmWasm / Provenance contracts |
| `vulnerability-research` | CVE/advisory research and feedback into this repo |

**Routing:** load `security-audit-core` first, then exactly one stack skill. `bugbot-review` stays for diff/PR review.

**Scanners:** read-only forms are allowlisted in `full/.clinerules/cmd/18-cmd-security-scanners.md`. Install tools opt-in (not part of `install-full.sh`):

```bash
./bin/install-security-tools.sh -c              # what is missing
./bin/install-security-tools.sh --install core  # gitleaks, osv-scanner, trivy, semgrep
./bin/install-security-tools.sh --install rust  # cargo-audit, cargo-deny, cosmwasm-check, cargo-llvm-cov
```

**Search MCP prerequisite:** `vulnerability-research` prefers `local-searxng` or `external-brave-search` / `external-tavily` for fresh advisories. All search MCPs ship disabled — without one, audits fall back to lockfile + offline DBs and must say so in the report.

## Checkpointed analysis (`full/` and `lite/`)

Two composable skills for repository-scale work that exceeds one useful model context (especially local models with bounded per-step reasoning):

| Skill | Use for |
|-------|---------|
| `checkpointed-analysis` | Orchestrator: bounded investigate → semantic checkpoint → continue loops |
| `persistent-analysis-store` | Schema for gitignored `.ai/analysis/` (`STATE.md` as index; component docs on disk) |

**Routing:** load `checkpointed-analysis` (it pulls in `persistent-analysis-store`), then optionally one domain skill (`architecture-review`, `deep-debugging`, `change-planning`, or `security-audit-core` + one stack skill). Checkpoint after meaningful progress — not on a fixed reasoning-token interval. Do not stop after writing a checkpoint.

Prompt shape: `Analyze X with checkpointing` or `Design a plan for Y using checkpointed-analysis`.

## Sub-agent model routing (`full/` and `lite/`)

`subagent-model-routing` is lead-only guidance for a strong main-thread model working with more limited workers (local vLLM/llama.cpp/Ollama models, small or quantized models). It covers what the lead keeps versus delegates, picking a worker from the models you say are active, concurrency and single-writer state, reasoning/answer budgets with a truncation probe, a fixed worker brief and report schema, stop rules, and lead verification. It never goes into worker prompts.

Prompt shape: `Active models: lead = <hosted model>; workers = <local-a>, <local-b> (200k ctx, 8k reasoning). Use subagent-model-routing to audit X.`

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
└── .cline/skills/    # 34 skills incl. design/pattern/reliability guides, game development, security auditing, checkpointing, frontend-engineering, CLI sub-agent logging, sub-agent model routing
```

OpenCode `AGENTS.md` is generated from `.clinerules/` at install time; skills are copied from `.cline/skills/`; named subagents come from [`agents/catalog/`](agents/catalog/) (see [OpenCode](#opencode) and [OpenCode subagents](#opencode-subagents)).

Highlights in `full/`:
- Expanded cmd whitelists (git fetch, jq/timeout, compose, AWS CLI/CDK read-only, Python, Vite, pnpm/yarn/bun, Make/Just, gh read-only)
- **No Go, no Terraform**
- React + Vite + Redux lang rules + `frontend-engineering` skill
- Security auditing skills (core + backend/frontend/contract/research) + `18-cmd-security-scanners.md`
- Checkpointed analysis + persistent analysis store (`.ai/analysis/`)
- Optional CosmWasm lang rules (`45-lang-cosmwasm.md`, path-gated)
- Finance MCP *routing* path-gated in `70-domain-finance-mcp.md` (servers not auto-installed)

## Lite layout

```text
lite/
├── .clinerules/
│   ├── 00-core-global.md
│   ├── 50-verify.md
│   └── cmd/10-cmd-safety.md
└── .cline/skills/
    ├── adapter-pattern/
    ├── cache-design/
    ├── change-planning/
    ├── checkpointed-analysis/
    ├── cli-subagent-progress-logging/
    ├── command-pattern/
    ├── composite-pattern/
    ├── deep-debugging/
    ├── decorator-pattern/
    ├── dependency-injection/
    ├── design-for-change/
    ├── idempotency-and-retries/
    ├── observer-and-events/
    ├── persistent-analysis-store/
    ├── pipeline-and-chain-of-responsibility/
    ├── polymorphism-and-strategy/
    ├── state-machine-design/
    ├── subagent-model-routing/
    └── transactional-outbox/
```

Planning, debugging, design selection, and long-running checkpointed investigation live in **skills** so always-on context stays small. `design-for-change` is for nontrivial code-level responsibility/variation choices; `decorator-pattern` handles composable additive wrappers; `polymorphism-and-strategy` is conditional on genuinely varying behavior; `state-machine-design` handles lifecycle/event-order modeling and refactoring. Both profiles include these skills. `cli-subagent-progress-logging` (in both profiles) keeps CLI-launched children auditable: combined output mirrored to a per-run log, `set -o pipefail` so a failed child is not masked by a successful `tee`, and a concise outcome + log-path report.

## Iteration advice

Change one concern at a time and observe local-model behavior. Keep `00-core` from becoming a handbook—push procedures into skills. Prefer path-gated lang/cmd rules in `full/` for stack-specific depth. In the generated OpenCode `AGENTS.md`, path-gated rules become prose conditions, so keep their `paths:` lists meaningful when read as prose.

## Configuration guidance tests

After changing profile skills, agents, or renderers, run the focused source-tree and disposable-renderer regression suites:

```bash
python3 tests/test_multitool.py
python3 tests/test_design_guidance.py
```

The wrapper dry-runs show installer destinations without writing and skip live MCP/OpenCode model refreshes:

```bash
./bin/install-full.sh -n --skip-mcp --skip-opencode
./bin/install-lite.sh -n --skip-mcp --skip-opencode
```

Renderer tests use temporary homes/projects; do not use a live user configuration as a test sandbox.
