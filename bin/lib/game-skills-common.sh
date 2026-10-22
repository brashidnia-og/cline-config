#!/usr/bin/env bash
# Install skills to tools that do not use the existing Cline/OpenCode
# profile skill sync (Cursor has no generated rules file, so installed
# skills are its only cline-config guidance besides agents). Only
# directories carrying our marker are replaced or removed; personal
# skills are never overwritten.
#
# GAME_SKILLS: game-development skills, full profile only (removed on lite).
# CURSOR_SHARED_SKILLS: non-game skills Cursor receives in every profile.

set -euo pipefail

GAME_SKILLS=(
  derive-3d-character-specs
  build-3d-game-characters
  game-reference-to-spec
  gameplay-code-quality
  godot-game-development
  game-performance-profiling
)
CURSOR_SHARED_SKILLS=(
  adapter-pattern
  dependency-injection
  pipeline-and-chain-of-responsibility
  command-pattern
  observer-and-events
  composite-pattern
  idempotency-and-retries
  transactional-outbox
  cache-design
  design-for-change
  decorator-pattern
  polymorphism-and-strategy
  state-machine-design
  subagent-model-routing
  cli-subagent-progress-logging
)
GAME_SKILL_MARKER=".cline-config-managed"

# Replace DEST/SKILL with a managed copy of SOURCE (staged, then renamed).
# An existing unmarked personal directory is left untouched.
install_managed_cursor_skill() {
    local source="$1" dest="$2" skill="$3" dry_run="${4:-0}"
    local target staged
    target="${dest}/${skill}"
    if [[ -e "$target" && ! -f "${target}/${GAME_SKILL_MARKER}" ]]; then
        info "  Cursor skills: leaving unmarked ${target} untouched"
        return
    fi
    if [[ "$dry_run" == "1" ]]; then
        info "  [dry-run] install ${source} -> ${target}"
        return
    fi
    mkdir -p "$dest"
    staged="$(mktemp -d "${dest}/.${skill}.XXXXXX")"
    cp -a "${source}/." "$staged/"
    printf '%s\n' 'Managed by cline-config. Reinstall replaces this directory.' > "${staged}/${GAME_SKILL_MARKER}"
    if [[ -e "$target" ]]; then
        rm -rf -- "$target"
    fi
    mv -- "$staged" "$target"
    info "  Cursor skills: installed ${target}"
}

install_game_skills_to_dir() {
    local profile="$1" dest="$2" tool="$3" dry_run="${4:-0}"
    local source_root="${REPO_ROOT}/full/.cline/skills"
    local skill source target
    info "  Skills (${tool}): ${dest}/"

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
        install_managed_cursor_skill "$source" "$dest" "$skill" "$dry_run"
    done

    # Shared (non-game) skills: installed for every profile.
    for skill in "${CURSOR_SHARED_SKILLS[@]}"; do
        source="${REPO_ROOT}/${profile}/.cline/skills/${skill}"
        [[ -f "${source}/SKILL.md" ]] || die "shared Cursor skill missing: ${source}/SKILL.md"
        install_managed_cursor_skill "$source" "$dest" "$skill" "$dry_run"
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
  # Codex and Hermes receive all profile skills through multitool.py.
}

install_game_skills_project() {
  local profile="$1" project_dir="$2" dry_run="${3:-0}"
  install_game_skills_to_dir "$profile" "${project_dir}/.cursor/skills" "Cursor" "$dry_run"
  # Codex receives all profile skills under .agents/skills through multitool.py.
}
