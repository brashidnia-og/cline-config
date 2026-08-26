# Example exports for Cline MCP servers in this package.
# Stdio MCP children inherit the Cline host process environment (CLI and IDE).
# Prefer login-shell / session environment so both CLI and GUI-launched editors see them:
#   ~/.zprofile (zsh)  or  ~/.profile (bash)
#   Linux GUI: ~/.config/environment.d/*.conf  (then re-login or reboot)
# Then fully quit and relaunch Cline / the IDE (not only "Reload Window").
#
# Copy the lines you need; never commit real keys.
# Do not put ${env:VAR} passthroughs in MCP settings JSON — Cline CLI does not
# expand them and they overwrite real process env with the literal string.

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
# Then set "disabled": false on external-brave-search in cline_mcp_settings.json.

# --- external-tavily ---
# export TAVILY_API_KEY=
# Then set "disabled": false on external-tavily in cline_mcp_settings.json.

# --- external-context7 (preferred Context7 path) ---
# export CONTEXT7_API_KEY=
# Then set "disabled": false on external-context7 in cline_mcp_settings.json.

# --- local-context7 ---
# Disabled placeholder only (literal url in template so Cline schema stays valid).
# Prefer external-context7. Never put ${env:...} in streamableHttp url fields.

# --- external-ref ---
# export REF_API_KEY=
# Then set "disabled": false on external-ref in cline_mcp_settings.json.

# external-deepwiki (public repos) needs no key.
# local-playwright, local-chrome-devtools need no keys.

# --- local-precision-math ---
# Needs Bun on PATH (@nerdo/precision-math-mcp shebang is #!/usr/bin/env bun).
# Install: https://bun.sh — then either export below, or rely on install-mcp.sh
# materializing PATH to $HOME/.bun/bin:$PATH for that server. Fully quit and
# relaunch Cline/IDE after installing Bun.
# export BUN_INSTALL="$HOME/.bun"
# export PATH="$BUN_INSTALL/bin:$PATH"
