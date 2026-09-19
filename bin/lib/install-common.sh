#!/usr/bin/env bash
# Shared helpers for install-full.sh / install-lite.sh
# Installs a profile's .clinerules + .cline/skills into Cline's and OpenCode's global locations.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Default base URL of the local OpenAI-compatible model server, used to
# refresh the OpenCode opencode.jsonc model list (override with $LLM_URL).
LLM_URL_DEFAULT="http://localhost:8000/v1"

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "$*"
}

# Detect OS. Returns: macos | linux | unsupported
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

# Resolve the user Documents directory (OS-aware).
# macOS: ~/Documents
# Linux: xdg-user-dir DOCUMENTS when available, else ~/Documents
resolve_documents_dir() {
  local os="$1"
  local docs=""

  case "$os" in
    macos)
      docs="${HOME}/Documents"
      ;;
    linux)
      if command -v xdg-user-dir >/dev/null 2>&1; then
        docs="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"
      fi
      if [[ -z "${docs:-}" ]]; then
        docs="${HOME}/Documents"
      fi
      ;;
    *)
      die "unsupported operating system (need macOS or Linux)"
      ;;
  esac

  printf '%s' "$docs"
}

# Global rules directory (IDE / docs "Global Rules" location).
# Prefer Documents/Cline/Rules; on Linux fall back to ~/Cline/Rules when
# Documents is missing (matches Cline docs for some WSL/Linux setups).
#
# Only one rules destination is used so Cline does not load the same files
# twice from both Documents/Cline/Rules and ~/.cline/rules.
resolve_global_rules_dir() {
  local os="$1"
  local docs
  docs="$(resolve_documents_dir "$os")"

  if [[ -d "$docs" ]]; then
    printf '%s' "${docs}/Cline/Rules"
    return
  fi

  if [[ "$os" == "linux" ]]; then
    printf '%s' "${HOME}/Cline/Rules"
    return
  fi

  # macOS: still target ~/Documents/Cline/Rules (created on install)
  printf '%s' "${docs}/Cline/Rules"
}

resolve_global_skills_dir() {
  # Same path on macOS and Linux (Cline docs / disk.ts getClineSkillsDirectoryPath)
  printf '%s' "${HOME}/.cline/skills"
}

# OS-aware install hints for a missing tool (prints commands for the detected OS).
# Used by the MCP pre-flight gate (check_required_prerequisites) and the
# read-only checker (report_prerequisites). macOS leads with Homebrew when
# available, otherwise points at the official installer.
install_hint() {
  local tool="$1"
  local os
  os="$(detect_os 2>/dev/null || echo unsupported)"
  case "$tool" in
    node)
      case "$os" in
        macos)
          if command -v brew >/dev/null 2>&1; then
            printf '%s\n' "brew install node" \
                         "# or the official installer: curl -fsSL https://nodejs.org/install.sh | bash"
          else
            printf '%s\n' "Install Node.js LTS: https://nodejs.org  (pkg, or via your package manager)"
          fi
          ;;
        linux)
          printf '%s\n' "sudo apt install nodejs npm   # Debian/Ubuntu; otherwise use your distro's package manager"
          ;;
        *)
          printf '%s\n' "Install Node.js LTS: https://nodejs.org"
          ;;
      esac
      ;;
    python3)
      case "$os" in
        macos)
          if command -v brew >/dev/null 2>&1; then
            printf '%s\n' "brew install python" \
                         "# or the system one: xcode-select --install   (provides /usr/bin/python3)"
          else
            printf '%s\n' "xcode-select --install   # provides python3" \
                         "# or: brew install python"
          fi
          ;;
        linux)
          printf '%s\n' "sudo apt install python3   # Debian/Ubuntu"
          ;;
        *)
          printf '%s\n' "Install python3 via your package manager"
          ;;
      esac
      ;;
    bun)
      case "$os" in
        macos)
          if command -v brew >/dev/null 2>&1; then
            printf '%s\n' "brew install oven-sh/bun/bun" \
                         "# or the official installer: curl -fsSL https://bun.sh/install | bash"
          else
            printf '%s\n' "curl -fsSL https://bun.sh/install | bash" \
                         "# or: brew install oven-sh/bun/bun"
          fi
          ;;
        *)
          printf '%s\n' "curl -fsSL https://bun.sh/install | bash"
          ;;
      esac
      ;;
    *)
      printf '%s\n' "Install '$tool' via your package manager"
      ;;
  esac
}

# Hard gate: refuse to run a real MCP merge when required tools are missing,
# printing OS-aware install hints. python3 (merge/validate) and npx/Node
# (stdio servers) are required. Bun is only needed by local-precision-math, so a
# missing Bun is a warning, not a failure. Safe to call from install-mcp.sh.
check_required_prerequisites() {
  local os
  os="$(detect_os)"
  if [[ "$os" == "unsupported" ]]; then
    die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"
  fi

  local -a missing=()
  command -v python3 >/dev/null 2>&1 || missing+=("python3")
  command -v npx     >/dev/null 2>&1 || missing+=("npx")

  if (( ${#missing[@]} > 0 )); then
    info "Missing required tools for the MCP merge: ${missing[*]}"
    local m
    for m in "${missing[@]}"; do
      case "$m" in
        python3) info "  python3:"; install_hint python3 ;;
        npx)     info "  npx (Node.js):"; install_hint node ;;
      esac
      info ""
    done
    die "install the missing tools above, then re-run this command"
  fi

  if ! command -v bun >/dev/null 2>&1 && [[ ! -x "${HOME}/.bun/bin/bun" ]]; then
    info "note: 'bun' is not on PATH. local-precision-math requires Bun (its entrypoint is 'bun', not node)."
    install_hint bun
    info "      Install it to enable that server, or leave local-precision-math disabled."
    info ""
  fi
}

usage_common() {
  local script_name="$1"
  local profile="$2"
  cat <<EOF
Usage: ${script_name} [options]

Install the ${profile}/ profile into your user (global) Cline and OpenCode
directories (and Cursor agent files).

Options:
  -h, --help          Show this help
  -n, --dry-run       Print destinations and actions without copying
  --project DIR       Install into a project root instead of global locations
                       (Cline: copies .clinerules/ + .cline/ into DIR;
                        OpenCode: generates AGENTS.md + .opencode/skills/ + .opencode/agents/;
                        Cursor: writes .cursor/agents/)
  --skip-mcp          Do not merge MCP servers into Cline settings (global only)
  --skip-opencode     Do not generate/install OpenCode AGENTS.md + skills + agents, or
                      refresh the opencode.jsonc model list (Cursor agents still install)
  --force             Project mode only: replace an existing <project>/AGENTS.md
                      (the existing file is backed up first)

Global destinations (auto-detected):
  Cline rules:     macOS  ~/Documents/Cline/Rules
                    Linux  $XDG Documents/Cline/Rules  (or ~/Cline/Rules if Documents is absent)
  Cline skills:    ~/.cline/skills   (macOS and Linux)
  OpenCode rules:  ~/.config/opencode/AGENTS.md   (generated from the profile's .clinerules/)
  OpenCode skills: ~/.config/opencode/skills
  OpenCode agents: ~/.config/opencode/agents   (from agents/catalog + agents/${profile}.list)
  Cursor agents:   ~/.cursor/agents            (same catalog; Cursor frontmatter)
  OpenCode models: ~/.config/opencode/opencode.jsonc   (provider.local-llm block
                    refreshed best-effort from the local LLM server's /models
                    endpoint, default ${LLM_URL_DEFAULT}; override the server
                    URL with the LLM_URL environment variable)

MCP (global install only): merges mcp/cline_mcp_settings.template.json into
Cline IDE/CLI settings. See mcp/SECURITY.md and mcp/env.example.sh.
Or run: ./bin/install-mcp.sh

OpenCode model config: refreshed best-effort via ./bin/install-opencode-config.sh,
which merges the live model list into opencode.jsonc (other settings preserved).
If the LLM server is unreachable the install warns and continues;
--skip-opencode skips this step. Run the script directly for a hard-failing
refresh.

EOF
}

# Best-effort refresh of the global OpenCode model config (opencode.jsonc)
# from the local LLM server. Runs install-opencode-config.sh as a subprocess
# so the refresh stays a fully standalone tool; a failure there (LLM server
# down, an editor has the file open, ...) is downgraded to a warning so the
# rest of the install completes. Run the script directly for a hard-failing
# refresh. (Only called when --skip-opencode was not passed.)
refresh_opencode_config_best_effort() {
  local dry_run="${1:-0}"
  local oc_script
  oc_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../install-opencode-config.sh"
  if [[ ! -f "$oc_script" ]]; then
    info "warning: ${oc_script} not found - skipping the opencode.jsonc model refresh."
    return 0
  fi
  if [[ "$dry_run" == "1" ]]; then
    bash "$oc_script" -n \
      || info "warning: could not refresh the OpenCode model config (opencode.jsonc) - the rest of the install completed; run ./bin/install-opencode-config.sh later to retry."
    return 0
  fi
  bash "$oc_script" \
    || info "warning: could not refresh the OpenCode model config (opencode.jsonc) - the rest of the install completed; run ./bin/install-opencode-config.sh later to retry."
  return 0
}

# Replace DEST with a full copy of SRC tree contents.
sync_tree() {
  local src="$1"
  local dest="$2"
  local dry_run="$3"

  [[ -d "$src" ]] || die "source missing: $src"

  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] sync ${src}/ -> ${dest}/"
    return
  fi

  mkdir -p "$dest"
  # Drop existing entries so switching full <-> lite leaves no stale files.
  find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "${src}/." "$dest/"
}

install_profile() {
  local profile="$1"
  shift

  local dry_run=0
  local project_dir=""
  local skip_mcp=0
  local skip_opencode=0
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage_common "$(basename "$0")" "$profile"
        exit 0
        ;;
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      --project)
        [[ $# -ge 2 ]] || die "--project requires a directory"
        project_dir="$2"
        shift 2
        ;;
      --skip-mcp)
        skip_mcp=1
        shift
        ;;
      --skip-opencode)
        skip_opencode=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
  done

  local profile_root="${REPO_ROOT}/${profile}"
  local rules_src="${profile_root}/.clinerules"
  local skills_src="${profile_root}/.cline/skills"

  [[ -d "$profile_root" ]] || die "profile not found: ${profile_root}"
  [[ -d "$rules_src" ]] || die "missing ${rules_src}"
  [[ -d "$skills_src" ]] || die "missing ${skills_src}"

  # shellcheck source=mcp-common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mcp-common.sh"
  # shellcheck source=agents-common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agents-common.sh"
  # shellcheck source=opencode-common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/opencode-common.sh"

  if [[ -n "$project_dir" ]]; then
    [[ -d "$project_dir" ]] || die "project dir not found: $project_dir"
    project_dir="$(cd "$project_dir" && pwd)"
    info "Installing ${profile} into project: ${project_dir}"
    if [[ "$dry_run" == "1" ]]; then
      info "  [dry-run] sync ${rules_src}/ -> ${project_dir}/.clinerules/"
      info "  [dry-run] sync ${profile_root}/.cline/ -> ${project_dir}/.cline/"
      info "  [dry-run] note: MCP settings are global; run ./bin/install-mcp.sh separately"
    fi
    if [[ "$dry_run" != "1" ]]; then
      sync_tree "$rules_src" "${project_dir}/.clinerules" 0
      mkdir -p "${project_dir}/.cline"
      sync_tree "${profile_root}/.cline" "${project_dir}/.cline" 0
    fi
    if [[ "$skip_opencode" -eq 0 ]]; then
      install_opencode_project "$profile_root" "$project_dir" "$dry_run" "$force"
      refresh_opencode_config_best_effort "$dry_run"
    else
      info "Skipping OpenCode install (--skip-opencode)."
    fi
    install_cursor_agents "$profile" "${project_dir}/.cursor/agents" "$dry_run"
    if [[ "$dry_run" == "1" ]]; then
      info "Dry run complete."
      return
    fi
    info "Done."
    info "  ${project_dir}/.clinerules     (Cline project rules)"
    info "  ${project_dir}/.cline/skills    (Cline project skills)"
    if [[ "$skip_opencode" -eq 0 ]]; then
      info "  ${project_dir}/AGENTS.md       (OpenCode project rules, generated)"
      info "  ${project_dir}/.opencode/skills (OpenCode project skills)"
      info "  ${project_dir}/.opencode/agents (OpenCode project agents)"
    fi
    info "  ${project_dir}/.cursor/agents  (Cursor project agents)"
    info "Note: Cline MCP config is global (not project-local). Run ./bin/install-mcp.sh to merge MCP servers."
    return
  fi

  local os
  os="$(detect_os)"
  [[ "$os" != "unsupported" ]] || die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"

  local rules_dest skills_dest cursor_agents_dest
  rules_dest="$(resolve_global_rules_dir "$os")"
  skills_dest="$(resolve_global_skills_dir)"
  cursor_agents_dest="$(resolve_cursor_global_agents_dir)"

  info "Detected OS: ${os}"
  info "Installing profile: ${profile}"
  info "  Rules:  ${rules_dest}"
  info "  Skills: ${skills_dest}"
  info "  Cursor agents: ${cursor_agents_dest}"

  sync_tree "$rules_src" "$rules_dest" "$dry_run"
  sync_tree "$skills_src" "$skills_dest" "$dry_run"

  if [[ "$skip_opencode" -eq 0 ]]; then
    install_opencode_global "$profile_root" "$dry_run"
    refresh_opencode_config_best_effort "$dry_run"
  else
    info "Skipping OpenCode install (--skip-opencode)."
  fi

  install_cursor_agents "$profile" "$cursor_agents_dest" "$dry_run"

  if [[ "$skip_mcp" -eq 0 ]]; then
    info "Merging MCP servers (use --skip-mcp to skip)..."
    install_mcp_settings "$dry_run"
  else
    info "Skipping MCP merge (--skip-mcp)."
  fi

  if [[ "$dry_run" == "1" ]]; then
    info "Dry run complete."
    return
  fi

  if [[ "$skip_opencode" -eq 0 ]]; then
    info "Done. Restart Cline / OpenCode / Cursor (or reload the window) if rules, skills, or agents do not appear."
  else
    info "Done. Restart Cline / Cursor / reload the window if rules, skills, or agents do not appear."
  fi
}
