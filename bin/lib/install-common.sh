#!/usr/bin/env bash
# Shared helpers for install-full.sh / install-lite.sh
# Installs a profile's .clinerules + .cline/skills into Cline global locations,
# and generates OpenCode AGENTS.md + skills under ~/.config/opencode/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_AGENTS_PY="${LIB_DIR}/generate-opencode-agents.py"

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

# OpenCode global config dir ($XDG_CONFIG_HOME/opencode or ~/.config/opencode).
resolve_opencode_config_dir() {
  local base="${XDG_CONFIG_HOME:-${HOME}/.config}"
  printf '%s' "${base}/opencode"
}

resolve_opencode_agents_path() {
  printf '%s' "$(resolve_opencode_config_dir)/AGENTS.md"
}

resolve_opencode_skills_dir() {
  printf '%s' "$(resolve_opencode_config_dir)/skills"
}

# Count .md files under a .clinerules tree (for dry-run messaging).
count_rule_files() {
  local rules_dir="$1"
  find "$rules_dir" -type f -name '*.md' | wc -l | tr -d ' '
}

# Generate OpenCode AGENTS.md from a profile's .clinerules.
generate_opencode_agents() {
  local profile="$1"
  local rules_src="$2"
  local dest="$3"
  local dry_run="$4"

  command -v python3 >/dev/null 2>&1 || die "python3 is required to generate OpenCode AGENTS.md"
  [[ -f "$GENERATE_AGENTS_PY" ]] || die "generator missing: ${GENERATE_AGENTS_PY}"

  local count
  count="$(count_rule_files "$rules_src")"

  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] generate AGENTS.md from ${count} rule file(s) -> ${dest}"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  python3 "$GENERATE_AGENTS_PY" \
    --rules-dir "$rules_src" \
    --profile "$profile" \
    -o "$dest"
  info "  Generated AGENTS.md (${count} rule file(s)) -> ${dest}"
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

Install the ${profile}/ profile into global Cline and OpenCode directories.
Cline rules/skills are copied as-is. OpenCode AGENTS.md is generated by
concatenating .clinerules (path-gated files become always-on with scope notes).

Options:
  -h, --help         Show this help
  -n, --dry-run      Print destinations and actions without copying
  --project DIR      Install into a project root (Cline only: .clinerules/ + .cline/)
  --skip-mcp         Do not merge MCP servers into Cline settings (global only)
  --skip-opencode    Install Cline (+ MCP) only; skip ~/.config/opencode/
  --skip-cline       Install OpenCode only; skip Cline Rules/skills and MCP

Global Cline destinations (auto-detected):
  Rules:   macOS  ~/Documents/Cline/Rules
           Linux  \$XDG Documents/Cline/Rules  (or ~/Cline/Rules if Documents is absent)
  Skills:  ~/.cline/skills   (macOS and Linux)

Global OpenCode destinations:
  Rules:   \$XDG_CONFIG_HOME/opencode/AGENTS.md  (default ~/.config/opencode/AGENTS.md)
  Skills:  \$XDG_CONFIG_HOME/opencode/skills/

MCP (global Cline install only): merges mcp/cline_mcp_settings.template.json into
Cline IDE/CLI settings. See mcp/SECURITY.md and mcp/env.example.sh.
Or run: ./bin/install-mcp.sh

EOF
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
  local skip_cline=0

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
      --skip-cline)
        skip_cline=1
        shift
        ;;
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
  done

  if [[ "$skip_cline" -eq 1 && "$skip_opencode" -eq 1 ]]; then
    die "cannot use both --skip-cline and --skip-opencode"
  fi

  local profile_root="${REPO_ROOT}/${profile}"
  local rules_src="${profile_root}/.clinerules"
  local skills_src="${profile_root}/.cline/skills"

  [[ -d "$profile_root" ]] || die "profile not found: ${profile_root}"
  [[ -d "$rules_src" ]] || die "missing ${rules_src}"
  [[ -d "$skills_src" ]] || die "missing ${skills_src}"

  # shellcheck source=mcp-common.sh
  source "${LIB_DIR}/mcp-common.sh"

  if [[ -n "$project_dir" ]]; then
    if [[ "$skip_cline" -eq 1 ]]; then
      die "--project is Cline-only; do not combine with --skip-cline"
    fi
    if [[ "$skip_opencode" -eq 0 ]]; then
      info "Note: --project installs Cline files only (OpenCode global install is skipped)."
    fi
    [[ -d "$project_dir" ]] || die "project dir not found: $project_dir"
    project_dir="$(cd "$project_dir" && pwd)"
    info "Installing ${profile} into project: ${project_dir}"
    if [[ "$dry_run" == "1" ]]; then
      info "  [dry-run] sync ${rules_src}/ -> ${project_dir}/.clinerules/"
      info "  [dry-run] sync ${profile_root}/.cline/ -> ${project_dir}/.cline/"
      info "  [dry-run] note: MCP settings are global; run ./bin/install-mcp.sh separately"
      info "Dry run complete."
      return
    fi
    sync_tree "$rules_src" "${project_dir}/.clinerules" 0
    mkdir -p "${project_dir}/.cline"
    sync_tree "${profile_root}/.cline" "${project_dir}/.cline" 0
    info "Done."
    info "  ${project_dir}/.clinerules"
    info "  ${project_dir}/.cline/skills"
    info "Note: Cline MCP config is global (not project-local). Run ./bin/install-mcp.sh to merge MCP servers."
    return
  fi

  local os
  os="$(detect_os)"
  [[ "$os" != "unsupported" ]] || die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"

  local rules_dest skills_dest
  rules_dest="$(resolve_global_rules_dir "$os")"
  skills_dest="$(resolve_global_skills_dir)"

  local oc_config oc_agents oc_skills
  oc_config="$(resolve_opencode_config_dir)"
  oc_agents="$(resolve_opencode_agents_path)"
  oc_skills="$(resolve_opencode_skills_dir)"

  info "Detected OS: ${os}"
  info "Installing profile: ${profile}"

  if [[ "$skip_cline" -eq 0 ]]; then
    info "Cline:"
    info "  Rules:  ${rules_dest}"
    info "  Skills: ${skills_dest}"
    sync_tree "$rules_src" "$rules_dest" "$dry_run"
    sync_tree "$skills_src" "$skills_dest" "$dry_run"
  else
    info "Skipping Cline install (--skip-cline)."
  fi

  if [[ "$skip_opencode" -eq 0 ]]; then
    info "OpenCode:"
    info "  AGENTS: ${oc_agents}"
    info "  Skills: ${oc_skills}"
    generate_opencode_agents "$profile" "$rules_src" "$oc_agents" "$dry_run"
    sync_tree "$skills_src" "$oc_skills" "$dry_run"
  else
    info "Skipping OpenCode install (--skip-opencode)."
  fi

  # MCP is Cline-only; skip when not installing Cline.
  if [[ "$skip_cline" -eq 1 ]]; then
    if [[ "$skip_mcp" -eq 0 ]]; then
      info "Skipping MCP merge (Cline install skipped)."
    fi
  elif [[ "$skip_mcp" -eq 0 ]]; then
    info "Merging MCP servers (use --skip-mcp to skip)..."
    install_mcp_settings "$dry_run"
  else
    info "Skipping MCP merge (--skip-mcp)."
  fi

  if [[ "$dry_run" == "1" ]]; then
    info "Dry run complete."
    return
  fi

  info "Done."
  if [[ "$skip_cline" -eq 0 ]]; then
    info "  Restart Cline / reload the window if rules or skills do not appear."
  fi
  if [[ "$skip_opencode" -eq 0 ]]; then
    info "  Start a new OpenCode session to pick up AGENTS.md and skills under ${oc_config}."
  fi
}
