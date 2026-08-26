# MCP security notes (business use)

Server names in this package encode the **runtime data plane**:

| Prefix | Meaning |
|--------|---------|
| `local-` | Process runs on the machine and **does not send tool payloads to a third-party SaaS** by design (or only to **your** self-hosted endpoint). |
| `external-` | Tool use **sends query/content to a vendor API** (even if launched via local `npx`). |

`npx -y …` still implies **npm supply-chain** trust. That is separate from content exfiltration.

## Defaults after `./bin/install-mcp.sh`

- **`local-*`** enabled except **`local-context7`** (disabled placeholder) and **`local-searxng`** (`disabled: true` until `SEARXNG_URL` is set)
- **`external-*`**: `disabled: true` until you opt in

Prefer flipping `"disabled"` in `cline_mcp_settings.json` over the Cline UI toggle ([cline#9065](https://github.com/cline/cline/issues/9065) can rewrite settings when toggling in UI). StreamableHttp `url` fields must be literal valid URLs (never `${env:…}` — Cline CLI does not expand them, and an empty/invalid URL fails the settings file).

## Environment variables

Stdio MCP servers (`local-searxng`, `external-*` with `command`) inherit env from the **Cline host process** (CLI and IDE). Export keys/URLs via [`env.example.sh`](env.example.sh). Do not add identity `"VAR": "${env:VAR}"` blocks in MCP JSON — on Cline CLI those literals overwrite real values. Re-running `./bin/install-mcp.sh` resets package-owned `env` from the template (Bun PATH is materialized at install); `disabled` / `timeout` / `autoApprove` / `args` are preserved.

## Risk matrix

| Server | Data leaves machine? | Notes |
|--------|----------------------|-------|
| `local-playwright` | No (vendor SaaS) | Agent sees DOM/cookies/network; persisted profiles keep logins on disk. Avoid prod + real PII. Prefer isolated mode for sensitive apps. |
| `local-chrome-devtools` | No (vendor SaaS) | Same local privilege: console/network may contain secrets. |
| `local-precision-math` | No | Expressions only. Requires **Bun** on PATH (`#!/usr/bin/env bun`); missing Bun → MCP `-32000 Connection closed`. `install-mcp.sh` materializes `env.PATH` to `$HOME/.bun/bin:$PATH`. |
| `local-context7` | N/A (off) | Disabled placeholder with a literal dummy URL. Prefer `external-context7`. |
| `local-searxng` | To **your** SearXNG (`SEARXNG_URL`) | MCP runs locally; queries hit your instance (local, tunneled, or remote). Upstream engines behind SearXNG still contact the public web. Prefer over Brave/Tavily for privacy/control. |
| `external-brave-search` | Yes → Brave | Search query text. Sanitize prompts. |
| `external-tavily` | Yes → Tavily | Research queries. Sanitize prompts. |
| `external-context7` | Yes → Context7/Upstash | Library + topic queries (usually not full source). Preferred Context7 path. |
| `external-ref` | Yes → Ref | Docs search; can include private sources if configured — strongest review. |
| `external-deepwiki` | Yes → Cognition | Public GitHub repo Q&A; still third party. |

## Self-host options

| Capability | Practical self-host? |
|------------|----------------------|
| Library docs (Context7) | Prefer `external-context7` (stdio). `local-context7` is an unused stub in this package. |
| Web search | Yes — use `local-searxng` + `SEARXNG_URL` (existing instance, SSH tunnel, or [`docker-compose.searxng.yml`](docker-compose.searxng.yml)) |
| Math / Playwright / Chrome DevTools | Already local (math needs Bun installed) |
| DeepWiki / Ref index | Hosted / closed index — remain `external-*` |

## Always true outside MCP

- Whatever the MCP returns can enter the **coding model** context (local or cloud).
- Do not send secrets, private source, customer data, or internal URLs to `external-*` tools unless authorized.
