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
Existing disabled/timeout/autoApprove/args/env on those keys are preserved across re-runs.

Options:
  -h, --help     Show this help
  -n, --dry-run  Print targets and actions without writing

Secrets use \${env:VAR} — export keys from ~/.zprofile or ~/.profile (see mcp/env.example.sh).
Risk matrix: mcp/SECURITY.md
EOF
}

main() {
  local dry_run=0
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
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
  done

  install_mcp_settings "$dry_run"
}

main "$@"
