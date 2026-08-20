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
# timeout / autoApprove / args / env so re-install does not reset toggles.
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

  python3 - "$template" "$dest" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])

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

PRESERVE_KEYS = ("disabled", "timeout", "autoApprove", "args", "env")

for name, cfg in tmpl_servers.items():
    if not isinstance(cfg, dict):
        servers[name] = cfg
        continue
    merged = dict(cfg)
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

# Expand ${env:VAR} like Cline, then ensure streamableHttp/sse urls are valid.
# Prevents "Invalid MCP settings schema" from empty expanded URLs.
validate_mcp_settings_urls() {
  local dest="$1"
  local dry_run="${2:-0}"

  [[ -f "$dest" ]] || return 0
  command -v python3 >/dev/null 2>&1 || die "python3 is required to validate MCP settings"

  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] validate streamableHttp/sse URLs in ${dest}"
  fi

  python3 - "$dest" <<'PY'
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

dest_path = Path(sys.argv[1])
env_pat = re.compile(r"\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}")

def expand(value):
    if isinstance(value, dict):
        return {k: expand(v) for k, v in value.items()}
    if isinstance(value, list):
        return [expand(v) for v in value]
    if isinstance(value, str):
        return env_pat.sub(lambda m: os.environ.get(m.group(1), ""), value)
    return value

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
    transport = cfg.get("type")
    if transport not in ("streamableHttp", "sse"):
        # No explicit remote type: only validate url if present without command (remote-shaped).
        if "url" not in cfg or cfg.get("command"):
            continue
        transport = transport or "remote"
    url = expand(cfg.get("url", ""))
    if not isinstance(url, str) or not is_valid_url(url):
        errors.append(
            f"{name}: invalid {transport} url after env expand: {url!r} "
            f"(use a literal valid URL; never leave streamableHttp url as unset ${{env:...}})"
        )

if errors:
    print(f"MCP URL validation failed for {dest_path}:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    raise SystemExit(1)
PY
}

install_mcp_settings() {
  local dry_run="${1:-0}"
  local template
  template="$(resolve_mcp_template)"
  [[ -f "$template" ]] || die "MCP template missing: $template"

  info "MCP template: ${template}"
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

  # Validate template first so we fail before writing bad URLs.
  validate_mcp_settings_urls "$template" "$dry_run"

  for t in "${targets[@]}"; do
    merge_mcp_settings_file "$template" "$t" "$dry_run"
    if [[ "$dry_run" == "1" ]]; then
      if [[ -f "$t" ]]; then
        validate_mcp_settings_urls "$t" 1
      fi
    else
      validate_mcp_settings_urls "$t" 0
    fi
  done

  if [[ "$dry_run" == "1" ]]; then
    info "MCP dry run complete."
    return
  fi

  info "MCP merge done. Enable external-* servers by setting disabled:false in JSON after exporting keys (see mcp/env.example.sh)."
  info "Prefer editing disabled in JSON over the Cline UI toggle when using \${env:VAR} (UI can rewrite secrets)."
  info "Fully quit and relaunch the IDE after changing shell profile exports."
}
