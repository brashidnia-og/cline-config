#!/usr/bin/env bash
# Shared MCP install helpers (merge template into Cline MCP settings files).

set -euo pipefail

# Requires REPO_ROOT, die, info, detect_os from install-common.sh when sourced together.
# Standalone install-mcp.sh sources install-common.sh first.

MCP_TEMPLATE_REL="mcp/cline_mcp_settings.template.json"

resolve_mcp_template() {
  printf '%s' "${REPO_ROOT}/${MCP_TEMPLATE_REL}"
}

# Print candidate cline_mcp_settings.json paths (one per line). Does not require existence.
list_mcp_settings_candidates() {
  local os
  os="$(detect_os)"
  [[ "$os" != "unsupported" ]] || die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"

  local -a bases=()
  case "$os" in
    macos)
      bases=(
        "${HOME}/Library/Application Support/Code"
        "${HOME}/Library/Application Support/Code - Insiders"
        "${HOME}/Library/Application Support/Cursor"
      )
      ;;
    linux)
      bases=(
        "${HOME}/.config/Code"
        "${HOME}/.config/Code - Insiders"
        "${HOME}/.config/Cursor"
      )
      ;;
  esac

  local base
  for base in "${bases[@]}"; do
    printf '%s\n' "${base}/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
  done

  # Cline CLI (common locations)
  printf '%s\n' "${HOME}/.cline/data/settings/cline_mcp_settings.json"
  printf '%s\n' "${HOME}/.cline/mcp.json"
}

# Paths that should receive a merge: existing files, or known dirs we will create.
# Prefer: every existing settings file; if none exist, create under ~/.cline/data/settings/
# and any editor globalStorage whose parent User/globalStorage already exists.
resolve_mcp_merge_targets() {
  local -a existing=()
  local -a creatable=()
  local path parent gs_parent

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ -f "$path" ]]; then
      existing+=("$path")
      continue
    fi
    parent="$(dirname "$path")"
    # Create under Cline CLI settings always (mkdir later).
    if [[ "$path" == "${HOME}/.cline/data/settings/cline_mcp_settings.json" ]]; then
      creatable+=("$path")
      continue
    fi
    # Skip ~/.cline/mcp.json unless it already exists (CLI layout varies).
    if [[ "$path" == "${HOME}/.cline/mcp.json" ]]; then
      continue
    fi
    # Editor: only if globalStorage parent already exists (IDE was used).
    gs_parent="$(dirname "$(dirname "$parent")")"
    if [[ -d "$gs_parent" ]]; then
      creatable+=("$path")
    fi
  done < <(list_mcp_settings_candidates)

  if ((${#existing[@]} > 0)); then
    printf '%s\n' "${existing[@]}"
    # Also create CLI settings if missing so CLI users get a copy.
    local cli="${HOME}/.cline/data/settings/cline_mcp_settings.json"
    local found_cli=0
    local e
    for e in "${existing[@]}"; do
      if [[ "$e" == "$cli" ]]; then
        found_cli=1
        break
      fi
    done
    if [[ "$found_cli" -eq 0 ]]; then
      printf '%s\n' "$cli"
    fi
    return
  fi

  if ((${#creatable[@]} > 0)); then
    printf '%s\n' "${creatable[@]}"
    return
  fi

  # Fallback: always at least the CLI settings path
  printf '%s\n' "${HOME}/.cline/data/settings/cline_mcp_settings.json"
}

# Merge template mcpServers into dest JSON. Upserts package-owned keys; leaves
# unrelated servers alone. When a key already exists, keep user disabled /
# timeout / autoApprove / args so re-install does not reset toggles.
# env comes from the template (materialized) so broken IDE-only ${env:VAR}
# passthroughs are repaired for Cline CLI compatibility.
BUN_PATH_TOKEN="__CLINE_CONFIG_BUN_PATH__"

merge_mcp_settings_file() {
  local template="$1"
  local dest="$2"
  local dry_run="$3"

  [[ -f "$template" ]] || die "MCP template missing: $template"

  if [[ "$dry_run" == "1" ]]; then
    if [[ -f "$dest" ]]; then
      info "  [dry-run] merge MCP servers into ${dest}"
    else
      info "  [dry-run] create ${dest} from template (merge)"
    fi
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    cp -a "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required to merge MCP settings"
  fi

  python3 - "$template" "$dest" "$BUN_PATH_TOKEN" <<'PY'
import json
import os
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])
bun_path_token = sys.argv[3]

bun_path_value = f"{Path.home()}/.bun/bin:{os.environ.get('PATH', '')}"

def materialize(value):
    if isinstance(value, dict):
        return {k: materialize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [materialize(v) for v in value]
    if isinstance(value, str):
        return value.replace(bun_path_token, bun_path_value)
    return value

with template_path.open(encoding="utf-8") as f:
    template = json.load(f)

tmpl_servers = template.get("mcpServers")
if not isinstance(tmpl_servers, dict):
    raise SystemExit("template missing mcpServers object")

if dest_path.is_file():
    with dest_path.open(encoding="utf-8") as f:
        try:
            dest = json.load(f)
        except json.JSONDecodeError as e:
            raise SystemExit(f"invalid JSON in {dest_path}: {e}") from e
    if not isinstance(dest, dict):
        raise SystemExit(f"{dest_path} root must be a JSON object")
else:
    dest = {}

servers = dest.get("mcpServers")
if servers is None:
    servers = {}
    dest["mcpServers"] = servers
elif not isinstance(servers, dict):
    raise SystemExit(f"{dest_path}: mcpServers must be an object")

# env is intentionally not preserved: template (after materialize) is source of truth
PRESERVE_KEYS = ("disabled", "timeout", "autoApprove", "args")

for name, cfg in tmpl_servers.items():
    if not isinstance(cfg, dict):
        servers[name] = materialize(cfg)
        continue
    merged = materialize(dict(cfg))
    existing = servers.get(name)
    if isinstance(existing, dict):
        for key in PRESERVE_KEYS:
            if key in existing:
                merged[key] = existing[key]
    servers[name] = merged

with dest_path.open("w", encoding="utf-8") as f:
    json.dump(dest, f, indent=2)
    f.write("\n")
PY

  info "  merged MCP servers -> ${dest}"
}

# Ensure streamableHttp/sse urls are literal valid URLs (no ${env:} placeholders).
# Also reject any leftover ${env:VAR} in package-owned servers — Cline CLI does
# not expand them and would overwrite real process env with the literal string.
validate_mcp_settings_urls() {
  local dest="$1"
  local dry_run="${2:-0}"
  local package_names_csv="${3:-}"

  [[ -f "$dest" ]] || return 0
  command -v python3 >/dev/null 2>&1 || die "python3 is required to validate MCP settings"

  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] validate MCP settings in ${dest}"
  fi

  python3 - "$dest" "$package_names_csv" "$BUN_PATH_TOKEN" <<'PY'
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

dest_path = Path(sys.argv[1])
package_csv = sys.argv[2]
bun_path_token = sys.argv[3]
package_names = {n for n in package_csv.split(",") if n} if package_csv else set()
env_lit_pat = re.compile(r"\$\{env:")

def walk_strings(value, path=""):
    if isinstance(value, dict):
        for k, v in value.items():
            yield from walk_strings(v, f"{path}.{k}" if path else k)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from walk_strings(v, f"{path}[{i}]")
    elif isinstance(value, str):
        yield path, value

def is_valid_url(s: str) -> bool:
    try:
        u = urlparse(s)
        return bool(u.scheme and u.netloc)
    except Exception:
        return False

with dest_path.open(encoding="utf-8") as f:
    data = json.load(f)

servers = data.get("mcpServers")
if not isinstance(servers, dict):
    raise SystemExit(f"{dest_path}: mcpServers must be an object")

errors = []
for name, cfg in servers.items():
    if not isinstance(cfg, dict):
        continue
    check_env_lit = (not package_names) or (name in package_names)
    if check_env_lit:
        for path, s in walk_strings(cfg):
            if bun_path_token and bun_path_token in s:
                # Allowed only in the committed template before materialize.
                if dest_path.name == "cline_mcp_settings.template.json":
                    continue
                errors.append(f"{name}.{path}: unresolved install token {bun_path_token!r}")
            if env_lit_pat.search(s):
                errors.append(
                    f"{name}.{path}: contains ${{env:...}} which Cline CLI does not expand "
                    f"(omit identity env passthroughs; inherit from the host process)"
                )
    transport = cfg.get("type")
    if transport not in ("streamableHttp", "sse"):
        if "url" not in cfg or cfg.get("command"):
            continue
        transport = transport or "remote"
    url = cfg.get("url", "")
    if not isinstance(url, str) or not is_valid_url(url):
        errors.append(
            f"{name}: invalid {transport} url: {url!r} "
            f"(use a literal valid URL; never use ${{env:...}} in streamableHttp url)"
        )

if errors:
    print(f"MCP settings validation failed for {dest_path}:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    raise SystemExit(1)
PY
}

package_mcp_server_names() {
  local template
  template="$(resolve_mcp_template)"
  python3 - "$template" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
servers = data.get("mcpServers") or {}
print(",".join(servers.keys()))
PY
}

# Report (non-fatal) prerequisite status as a checklist. Returns 0 if all
# required tools (python3, node/npx) are present, 1 otherwise. Used by --check
# and by dry-runs, where a missing tool is reported but must not abort the run.
report_prerequisites() {
  local os
  os="$(detect_os 2>/dev/null || echo unsupported)"
  if [[ "$os" == "unsupported" ]]; then
    info "  OS:        unsupported ($(uname -s))"
    return 1
  fi
  info "  OS:         ${os}"
  local rc=0

  if command -v python3 >/dev/null 2>&1; then
    info "  python3:   OK"
  else
    rc=1
    info "  python3:   MISSING  (required: merge/validate MCP settings)"
    install_hint python3
  fi

  if command -v npx >/dev/null 2>&1; then
    info "  node/npx:  OK"
  else
    rc=1
    info "  node/npx:  MISSING  (required: stdio MCP servers launch via npx)"
    install_hint node
  fi

  if command -v bun >/dev/null 2>&1 || [[ -x "${HOME}/.bun/bin/bun" ]]; then
    info "  bun:       OK       (needed only by local-precision-math)"
  else
    info "  bun:       MISSING  (local-precision-math will fail; other servers unaffected)"
    install_hint bun
  fi

  return "$rc"
}

# Report which optional API keys / URLs are exported in the host environment.
# Read-only. Stdio MCP servers inherit these from the Cline host process, so they
# must be exported in the login shell / app environment (see mcp/env.example.sh).
report_env_vars() {
  if [[ -n "${SEARXNG_URL:-}" ]]; then
    info "  SEARXNG_URL:       set    -> local-searxng"
  else
    info "  SEARXNG_URL:       unset  -> local-searxng (SearXNG JSON API URL, e.g. http://127.0.0.1:8180)"
  fi
  if [[ -n "${BRAVE_API_KEY:-}" ]]; then
    info "  BRAVE_API_KEY:     set    -> external-brave-search"
  else
    info "  BRAVE_API_KEY:     unset  -> external-brave-search (Brave Search API key)"
  fi
  if [[ -n "${TAVILY_API_KEY:-}" ]]; then
    info "  TAVILY_API_KEY:    set    -> external-tavily"
  else
    info "  TAVILY_API_KEY:    unset  -> external-tavily (Tavily research API key)"
  fi
  if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
    info "  CONTEXT7_API_KEY:  set    -> external-context7"
  else
    info "  CONTEXT7_API_KEY:  unset  -> external-context7 (Context7/Upstash API key)"
  fi
  if [[ -n "${REF_API_KEY:-}" ]]; then
    info "  REF_API_KEY:       set    -> external-ref"
  else
    info "  REF_API_KEY:       unset  -> external-ref (Ref docs API key)"
  fi
}

# --install-bun: if Bun is not already present, install it with the official
# non-interactive installer (installs to $HOME/.bun on both macOS and Linux), then
# verify it lands on PATH. Explicit opt-in: it downloads and runs a remote script.
# After install, the local-precision-math server's PATH is pinned by the merge, so
# it works even for a GUI-launched IDE.
maybe_install_bun() {
  if command -v bun >/dev/null 2>&1 || [[ -x "${HOME}/.bun/bin/bun" ]]; then
    info "Bun already present: $({ command -v bun 2>/dev/null || echo "${HOME}/.bun/bin/bun"; })"
    return 0
  fi

  local os
  os="$(detect_os)"
  if [[ "$os" == "unsupported" ]]; then
    die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"
  fi

  info "Bun not found. Installing with the official Bun installer (https://bun.sh) ..."
  info "  (this downloads and runs a remote script -- proceed only if you trust bun.sh)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://bun.sh/install | bash
  else
    die "curl or wget is required to install Bun (see https://bun.sh/install)"
  fi

  if command -v bun >/dev/null 2>&1 || [[ -x "${HOME}/.bun/bin/bun" ]]; then
    info "Bun installed successfully."
  else
    die "Bun installer ran but 'bun' is not on PATH. Add \$HOME/.bun/bin to PATH (see mcp/env.example.sh) and relaunch."
  fi
}

# --check / --verify: read-only pre-flight. Reports the OS, required/optional
# tools, relevant environment variables, and the settings files a merge would
# touch. Never writes. Returns 0 if all required prerequisites are present, else 1.
run_mcp_check() {
  local template
  template="$(resolve_mcp_template)"
  if [[ ! -f "$template" ]]; then
    die "MCP template missing: $template"
  fi

  local os
  os="$(detect_os 2>/dev/null || echo unsupported)"
  if [[ "$os" == "unsupported" ]]; then
    info "MCP pre-flight check: unsupported OS '$(uname -s)'. Only macOS and Linux are supported."
    return 1
  fi

  info "MCP pre-flight check (read-only; nothing is written)"
  info "Template: ${template}"
  info ""

  info "Prerequisites:"
  local pre_rc=0
  report_prerequisites || pre_rc=1
  info ""

  info "Environment variables (export per mcp/env.example.sh, then FULLY relaunch Cline/IDE):"
  report_env_vars
  info ""

  info "MCP settings targets a merge would touch:"
  local t
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    if [[ -f "$t" ]]; then
      info "  [exists]  ${t}"
    else
      info "  [create]  ${t}"
    fi
  done < <(resolve_mcp_merge_targets)
  info "  [Codex]  ${HOME}/.codex/config.toml"
  info "  [Claude] ${HOME}/.claude.json"
  info "  [Hermes] ${HOME}/.hermes/config.yaml"
  info ""

  if [[ "$pre_rc" -eq 0 ]]; then
    info "Result: all required prerequisites present. Ready to install."
  else
    info "Result: one or more required prerequisites are MISSING (see hints above)."
  fi
  return "$pre_rc"
}

install_mcp_settings() {
  local dry_run="${1:-0}"
  local template
  template="$(resolve_mcp_template)"
  [[ -f "$template" ]] || die "MCP template missing: $template"

  info "MCP template: ${template}"

  # Fail fast (with OS-aware install hints) before touching any settings file.
  # A real merge requires python3 + npx and warns if Bun is missing; a dry-run
  # only reports and never aborts on a missing tool.
  if [[ "$dry_run" == "1" ]]; then
    info "Pre-flight checks (dry-run, non-fatal):"
    report_prerequisites || true
    info ""
  else
    check_required_prerequisites
  fi

  local targets=()
  local t
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    targets+=("$t")
  done < <(resolve_mcp_merge_targets)

  if ((${#targets[@]} == 0)); then
    die "no MCP settings targets resolved"
  fi

  info "MCP merge targets:"
  for t in "${targets[@]}"; do
    info "  - ${t}"
  done

  local package_names
  package_names="$(package_mcp_server_names)"

  # Validate template first so we fail before writing bad URLs.
  validate_mcp_settings_urls "$template" "$dry_run" "$package_names"

  for t in "${targets[@]}"; do
    merge_mcp_settings_file "$template" "$t" "$dry_run"
    # Validate destinations only after a real write (dry-run does not merge).
    if [[ "$dry_run" != "1" ]]; then
      validate_mcp_settings_urls "$t" 0 "$package_names"
    fi
  done

  if [[ "$dry_run" == "1" ]]; then
    info "MCP dry run complete."
    return
  fi

  if [[ -n "${SEARXNG_URL:-}" ]]; then
    info "SEARXNG_URL is set (${SEARXNG_URL}). Set local-searxng disabled:false in MCP settings to enable web search."
  else
    info "SEARXNG_URL is unset. Export it (see mcp/env.example.sh), then set local-searxng disabled:false."
  fi

  info "MCP merge done. Stdio MCP servers inherit env from the Cline host process (CLI and IDE)."
  info "Export keys/URLs in your login environment (mcp/env.example.sh), then fully quit and relaunch Cline/IDE."
  info "Enable servers by setting disabled:false in JSON (prefer that over the Cline UI toggle)."
}
