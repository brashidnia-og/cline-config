#!/usr/bin/env bash
# Shared helpers for install-full.sh / install-lite.sh
# Installs a profile's .clinerules + .cline/skills into Cline's global locations.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

usage_common() {
  local script_name="$1"
  local profile="$2"
  cat <<EOF
Usage: ${script_name} [options]

Install the ${profile}/ Cline profile into your user (global) Cline directories.

Options:
  -h, --help       Show this help
  -n, --dry-run    Print destinations and actions without copying
  --project DIR    Install into a project root instead of global locations
                   (copies .clinerules/ and .cline/ into DIR)

Global destinations (auto-detected):
  Rules:   macOS  ~/Documents/Cline/Rules
           Linux  \$XDG Documents/Cline/Rules  (or ~/Cline/Rules if Documents is absent)
  Skills:  ~/.cline/skills   (macOS and Linux)

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

  if [[ -n "$project_dir" ]]; then
    [[ -d "$project_dir" ]] || die "project dir not found: $project_dir"
    project_dir="$(cd "$project_dir" && pwd)"
    info "Installing ${profile} into project: ${project_dir}"
    if [[ "$dry_run" == "1" ]]; then
      info "  [dry-run] sync ${rules_src}/ -> ${project_dir}/.clinerules/"
      info "  [dry-run] sync ${profile_root}/.cline/ -> ${project_dir}/.cline/"
      info "Dry run complete."
      return
    fi
    sync_tree "$rules_src" "${project_dir}/.clinerules" 0
    mkdir -p "${project_dir}/.cline"
    sync_tree "${profile_root}/.cline" "${project_dir}/.cline" 0
    info "Done."
    info "  ${project_dir}/.clinerules"
    info "  ${project_dir}/.cline/skills"
    return
  fi

  local os
  os="$(detect_os)"
  [[ "$os" != "unsupported" ]] || die "unsupported OS '$(uname -s)'; only macOS and Linux are supported"

  local rules_dest skills_dest
  rules_dest="$(resolve_global_rules_dir "$os")"
  skills_dest="$(resolve_global_skills_dir)"

  info "Detected OS: ${os}"
  info "Installing profile: ${profile}"
  info "  Rules:  ${rules_dest}"
  info "  Skills: ${skills_dest}"

  sync_tree "$rules_src" "$rules_dest" "$dry_run"
  sync_tree "$skills_src" "$skills_dest" "$dry_run"

  if [[ "$dry_run" == "1" ]]; then
    info "Dry run complete."
    return
  fi

  info "Done. Restart Cline / reload the window if rules or skills do not appear."
}
