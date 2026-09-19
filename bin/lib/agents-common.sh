#!/usr/bin/env bash
# Shared OpenCode / Cursor agent install helpers.
#
# Source tree (repo root):
#   agents/catalog/<id>.md   — shared frontmatter (description, readonly, shell) + prompt body
#   agents/full.list         — agent ids for the full profile
#   agents/lite.list         — agent ids for the lite profile
#
# Install renders tool-specific frontmatter and writes managed files marked with
# <!-- cline-config:managed -->. Unmarked user agents in the destination are left alone.
# Switching full <-> lite removes managed files that are no longer listed.
#
# Requires REPO_ROOT, die, info from install-common.sh.

set -euo pipefail

AGENTS_MANAGED_MARKER="cline-config:managed"

resolve_agents_catalog_dir() {
  printf '%s' "${REPO_ROOT}/agents/catalog"
}

resolve_agents_list_file() {
  local profile="$1"
  printf '%s' "${REPO_ROOT}/agents/${profile}.list"
}

# Read non-empty, non-comment lines from a profile list file into stdout.
read_agents_list() {
  local list_file="$1"
  [[ -f "$list_file" ]] || die "agents list missing: ${list_file}"
  # strip comments / blanks
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$list_file" | sed '/^$/d'
}

# Render and sync agents for PROFILE into DEST_DIR for TOOL (opencode|cursor).
# dry_run=1 prints actions only.
install_agents_to_dir() {
  local profile="$1"
  local dest_dir="$2"
  local tool="$3"
  local dry_run="${4:-0}"

  local catalog list_file
  catalog="$(resolve_agents_catalog_dir)"
  list_file="$(resolve_agents_list_file "$profile")"

  [[ -d "$catalog" ]] || die "agents catalog missing: ${catalog}"
  [[ "$tool" == "opencode" || "$tool" == "cursor" ]] || die "unknown agent tool: ${tool}"

  if ! command -v python3 >/dev/null 2>&1; then
    if [[ "$dry_run" == "1" ]]; then
      info "  note: python3 not found — agent install to ${dest_dir} would be skipped"
      return 0
    fi
    info "python3 not found — skipping agent install to ${dest_dir}"
    install_hint python3
    return 0
  fi

  local ids=()
  local id
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    ids+=("$id")
  done < <(read_agents_list "$list_file")

  [[ ${#ids[@]} -gt 0 ]] || die "agents list is empty: ${list_file}"

  for id in "${ids[@]}"; do
    [[ -f "${catalog}/${id}.md" ]] || die "agent catalog entry missing: ${catalog}/${id}.md"
  done

  info "  Agents (${tool}): ${#ids[@]} from ${list_file} -> ${dest_dir}/"

  if [[ "$dry_run" == "1" ]]; then
    local preview
    preview="$(printf '%s, ' "${ids[@]}")"
    info "  [dry-run] write managed agents: ${preview%, }"
    if [[ -d "$dest_dir" ]]; then
      info "  [dry-run] remove stale managed agents not in the list (leave unmarked user agents)"
    fi
    return 0
  fi

  mkdir -p "$dest_dir"

  # Remove managed agents that are no longer in the profile list.
  local existing base
  shopt -s nullglob
  for existing in "${dest_dir}"/*.md; do
    [[ -f "$existing" ]] || continue
    if ! grep -q "$AGENTS_MANAGED_MARKER" "$existing" 2>/dev/null; then
      continue
    fi
    base="$(basename "$existing" .md)"
    local keep=0
    for id in "${ids[@]}"; do
      if [[ "$id" == "$base" ]]; then
        keep=1
        break
      fi
    done
    if [[ "$keep" -eq 0 ]]; then
      info "  agents: removing stale managed ${existing}"
      rm -f "$existing"
    fi
  done
  shopt -u nullglob

  # Render each listed agent into the destination.
  python3 - "$catalog" "$dest_dir" "$tool" "$AGENTS_MANAGED_MARKER" "${ids[@]}" <<'PY'
import sys
from pathlib import Path

catalog = Path(sys.argv[1])
dest_dir = Path(sys.argv[2])
tool = sys.argv[3]
marker = sys.argv[4]
ids = sys.argv[5:]

def split_frontmatter(text: str):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, text
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            fm_lines = lines[1:i]
            body = "\n".join(lines[i + 1 :]).lstrip("\n")
            meta = {}
            for line in fm_lines:
                if ":" not in line:
                    continue
                key, val = line.split(":", 1)
                key = key.strip()
                val = val.strip()
                if key in ("readonly", "shell"):
                    meta[key] = val.lower() in ("1", "true", "yes")
                elif key == "description":
                    meta[key] = val
            return meta, body
    return {}, text

def render_opencode(agent_id: str, meta: dict, body: str) -> str:
    readonly = bool(meta.get("readonly", True))
    shell = bool(meta.get("shell", False))
    desc = meta.get("description") or agent_id
    edit = "deny" if readonly else "allow"
    bash = "allow" if shell else ("deny" if readonly else "allow")
    # Write-capable agents still get bash allow so they can run needed commands.
    if not readonly and not shell:
        bash = "allow"
    lines = [
        "---",
        f"description: {desc}",
        "mode: subagent",
        "permission:",
        f"  edit: {edit}",
        f"  bash: {bash}",
        "---",
        "",
        f"<!-- {marker} -->",
        "",
        body.rstrip() + "\n",
    ]
    return "\n".join(lines)

def render_cursor(agent_id: str, meta: dict, body: str) -> str:
    readonly = bool(meta.get("readonly", True))
    desc = meta.get("description") or agent_id
    # Cursor: readonly true when no edits; shell-capable agents still readonly for files.
    ro = "true" if readonly else "false"
    lines = [
        "---",
        f"name: {agent_id}",
        f"description: {desc}",
        "model: inherit",
        f"readonly: {ro}",
        "---",
        "",
        f"<!-- {marker} -->",
        "",
        body.rstrip() + "\n",
    ]
    return "\n".join(lines)

for agent_id in ids:
    src = catalog / f"{agent_id}.md"
    text = src.read_text(encoding="utf-8")
    meta, body = split_frontmatter(text)
    if tool == "opencode":
        out = render_opencode(agent_id, meta, body)
    else:
        out = render_cursor(agent_id, meta, body)
    (dest_dir / f"{agent_id}.md").write_text(out, encoding="utf-8")
    print(f"  agents: wrote {dest_dir / (agent_id + '.md')}")
PY
}

resolve_cursor_global_agents_dir() {
  printf '%s' "${HOME}/.cursor/agents"
}

# Install Cursor agents for a profile (global or project).
install_cursor_agents() {
  local profile="$1"
  local dest_dir="$2"
  local dry_run="${3:-0}"
  install_agents_to_dir "$profile" "$dest_dir" "cursor" "$dry_run"
}

# Install OpenCode agents for a profile (global or project).
install_opencode_agents() {
  local profile="$1"
  local dest_dir="$2"
  local dry_run="${3:-0}"
  install_agents_to_dir "$profile" "$dest_dir" "opencode" "$dry_run"
}
