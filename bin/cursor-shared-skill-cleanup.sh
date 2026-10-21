#!/usr/bin/env bash
# Explicit managed-only cleanup for the shared skills introduced by the
# design rollouts (the explicit allowlist below).
#
# Why this exists: Cursor's shared-skill loop only installs the names its
# own revision knows, so downgrading to a previous revision and reinstalling
# does NOT remove the newer shared skills — the older installer never
# implemented that cleanup. Run this script after such a downgrade.
#
# Scope: it touches ONLY the directories in that allowlist, and removes a
# directory ONLY when it carries the cline-config managed marker. Unmarked
# personal directories (even same-named ones) are preserved. No other
# skill, agent, or setting is touched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

CURSOR_SHARED_SKILL_CLEANUP_NAMES=(
  adapter-pattern
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
)
CURSOR_CLEANUP_MARKER=".cline-config-managed"

dry_run=0
dest="${HOME}/.cursor/skills"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) dry_run=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: ${0##*/} [-n|--dry-run] [DEST]

Remove the cline-config managed shared-skill directories introduced by the
design rollouts from a Cursor skills directory. Only directories
carrying the '${CURSOR_CLEANUP_MARKER}' marker are removed; unmarked personal
directories of the same names are preserved. DEST defaults to ~/.cursor/skills.
With -n, print what would be removed without changing anything.
EOF
      exit 0
      ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *)
      [[ $# -eq 1 ]] || die "DEST requires exactly one argument"
      dest="$1"
      shift
      ;;
  esac
done

if [[ ! -d "$dest" ]]; then
  info "no directory at ${dest} — nothing to clean up"
  exit 0
fi

info "Cleaning managed shared Cursor skills in: ${dest}"
removed=0
for name in "${CURSOR_SHARED_SKILL_CLEANUP_NAMES[@]}"; do
  target="${dest}/${name}"
  if [[ ! -e "$target" ]]; then
    continue
  fi
  if [[ -f "${target}/${CURSOR_CLEANUP_MARKER}" ]]; then
    if [[ "$dry_run" == "1" ]]; then
      info "  [dry-run] would remove managed ${target}"
    else
      rm -rf -- "$target"
      info "  removed managed ${target}"
    fi
    removed=$((removed + 1))
  else
    info "  preserved unmarked personal ${target}"
  fi
done

if [[ "$dry_run" == "1" ]]; then
  info "Dry run complete: ${removed} managed director(y/ies) would be removed."
else
  info "Cleanup complete: ${removed} managed director(y/ies) removed."
fi
