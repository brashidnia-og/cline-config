#!/usr/bin/env bash
# Install game-development skills to tools that do not use the
# existing Cline/OpenCode profile skill sync. Only directories carrying our
# marker are replaced or removed; personal skills are never overwritten.

set -euo pipefail

GAME_SKILLS=(
  derive-3d-character-specs
  build-3d-game-characters
  game-reference-to-spec
  gameplay-code-quality
  godot-game-development
  game-performance-profiling
)
GAME_SKILL_MARKER=".cline-config-managed"

install_game_skills_to_dir() {
  local profile="$1" dest="$2" tool="$3" dry_run="${4:-0}"
  local source_root="${REPO_ROOT}/full/.cline/skills"
  local skill source target
  info "  Game skills (${tool}): ${dest}/"

  for skill in "${GAME_SKILLS[@]}"; do
    source="${source_root}/${skill}"
    target="${dest}/${skill}"
    [[ -f "${source}/SKILL.md" ]] || die "game skill missing: ${source}/SKILL.md"
    if [[ -e "$target" && ! -f "${target}/${GAME_SKILL_MARKER}" ]]; then
      info "  game skills: leaving unmarked ${target} untouched"
      continue
    fi
    if [[ "$profile" != "full" ]]; then
      if [[ -e "$target" ]]; then
        if [[ "$dry_run" == "1" ]]; then
          info "  [dry-run] remove managed ${target}"
        else
          rm -rf -- "$target"
          info "  game skills: removed managed ${target}"
        fi
      fi
      continue
    fi
    if [[ "$dry_run" == "1" ]]; then
      info "  [dry-run] install ${source} -> ${target}"
      continue
    fi
    mkdir -p "$dest"
    local staged
    staged="$(mktemp -d "${dest}/.${skill}.XXXXXX")"
    cp -a "${source}/." "$staged/"
    printf '%s\n' 'Managed by cline-config. Reinstall replaces this directory.' > "${staged}/${GAME_SKILL_MARKER}"
    if [[ -e "$target" ]]; then
      rm -rf -- "$target"
    fi
    mv -- "$staged" "$target"
    info "  game skills: installed ${target}"
  done
}

install_game_skills_global() {
  local profile="$1" dry_run="${2:-0}" hermes_profile="${3:-}"
  local profile_dir=""
  if [[ -n "$hermes_profile" ]]; then
    [[ "$hermes_profile" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "invalid Hermes profile name: ${hermes_profile}"
    profile_dir="${HOME}/.hermes/profiles/${hermes_profile}"
    [[ -d "$profile_dir" ]] || die "Hermes profile does not exist: ${profile_dir}"
  fi
  install_game_skills_to_dir "$profile" "${HOME}/.cursor/skills" "Cursor" "$dry_run"
  install_game_skills_to_dir "$profile" "${HOME}/.codex/skills" "Codex" "$dry_run"
  install_game_skills_to_dir "$profile" "${HOME}/.hermes/skills/game-development" "Hermes" "$dry_run"
  if [[ -n "$hermes_profile" ]]; then
    install_game_skills_to_dir "$profile" "${profile_dir}/skills/game-development" "Hermes profile ${hermes_profile}" "$dry_run"
  fi
}

install_game_skills_project() {
  local profile="$1" project_dir="$2" dry_run="${3:-0}"
  install_game_skills_to_dir "$profile" "${project_dir}/.cursor/skills" "Cursor" "$dry_run"
  install_game_skills_to_dir "$profile" "${project_dir}/.codex/skills" "Codex" "$dry_run"
  # Hermes uses profile/global skill directories. Project mode deliberately
  # stays inside the project; global Hermes installation uses the global path.
  info "  Hermes skills: use a global install for ~/.hermes/skills/"
}
