#!/usr/bin/env bash
# Merge this package's MCP server template into Cline MCP settings (IDE + CLI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"
# shellcheck source=lib/mcp-common.sh
source "${SCRIPT_DIR}/lib/mcp-common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Merge mcp/cline_mcp_settings.template.json into Cline MCP settings files.
Package-owned server keys (local-*, external-*) are upserted; other servers are left alone.
Existing disabled/timeout/autoApprove/args on those keys are preserved across re-runs.
env is taken from the template (Bun PATH materialized at install) so configs work on
both Cline CLI and the IDE extension — stdio servers inherit the host process env.

Options:
  -h, --help         Show this help
  -n, --dry-run      Print targets and actions without writing
  -c, --check        Read-only pre-flight: report OS, required/optional tools
                      (python3, node/npx, bun), relevant env vars, and the settings
                      files a merge would touch. Writes nothing. Exit 0 = all
                      required tools present; exit 1 = at least one is missing.
      --install-bun  If Bun is missing, install it via the official installer before
                      merging (downloads + runs a remote script; explicit opt-in).

Export keys/URLs from ~/.zprofile, ~/.profile, or ~/.config/environment.d/ (see mcp/env.example.sh).
Risk matrix: mcp/SECURITY.md
EOF
}

main() {
  local dry_run=0
  local check_only=0
  local install_bun=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      -c|--check|--verify)
        check_only=1
        shift
        ;;
      --install-bun)
        install_bun=1
        shift
        ;;
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
  done

  # Read-only pre-flight: report state and exit; never touch settings files.
  if [[ "$check_only" -eq 1 ]]; then
    if [[ "$install_bun" -eq 1 ]]; then
      maybe_install_bun
    fi
    run_mcp_check
    exit $?
  fi

  if [[ "$install_bun" -eq 1 ]]; then
    maybe_install_bun
  fi

  install_mcp_settings "$dry_run"
}

main "$@"
