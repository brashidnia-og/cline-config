# Example exports for Cline MCP servers in this package.
# Prefer login-shell files so GUI-launched editors inherit them:
#   ~/.zprofile (zsh)  or  ~/.profile (bash)
# Then fully quit and relaunch the IDE (not only "Reload Window").
#
# Copy the lines you need; never commit real keys.
# Cline expands ${env:VAR} from the IDE/CLI process environment (Cline >= 3.43).

# --- local-searxng (preferred web search when enabled) ---
# Point at your SearXNG JSON API. Common setups:
#   - SSH tunnel: remote :8080 -> local :8180
#       ssh -L 8180:127.0.0.1:8080 user@remote
#   - Direct LAN/VPN URL to the remote instance
#   - Local Docker Compose: see mcp/docker-compose.searxng.yml
# Then set "disabled": false on local-searxng in cline_mcp_settings.json.
# export SEARXNG_URL=http://127.0.0.1:8180

# --- external-brave-search ---
# export BRAVE_API_KEY=

# --- external-tavily ---
# export TAVILY_API_KEY=

# --- external-context7 (preferred Context7 path) ---
# export CONTEXT7_API_KEY=
# Then set "disabled": false on external-context7 in cline_mcp_settings.json.

# --- local-context7 ---
# Disabled placeholder only (literal url in template so Cline schema stays valid).
# Prefer external-context7. Do not use unset ${env:...} in streamableHttp url fields.

# --- external-ref ---
# export REF_API_KEY=

# external-deepwiki (public repos) needs no key.
# local-playwright, local-chrome-devtools need no keys.

# --- local-precision-math ---
# Needs Bun on PATH (@nerdo/precision-math-mcp shebang is #!/usr/bin/env bun).
# Install: https://bun.sh — then either export below, or rely on the template's
# PATH env (${env:HOME}/.bun/bin:…). Fully quit and relaunch the IDE after.
# export BUN_INSTALL="$HOME/.bun"
# export PATH="$BUN_INSTALL/bin:$PATH"
