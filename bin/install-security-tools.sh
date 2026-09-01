#!/usr/bin/env bash
# Opt-in installer for security audit scanners (standalone — not invoked by install-full.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"
# shellcheck source=lib/security-tools-common.sh
source "${SCRIPT_DIR}/lib/security-tools-common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Install optional security scanners used by full/ audit skills.
Standalone — install-full.sh and install-lite.sh do NOT invoke this script.

Options:
  -h, --help              Show this help
  -n, --dry-run           Print actions without installing or downloading
  -c, --check             Report tool presence, versions, and degraded skills (read-only)
      --install <group>   Opt-in install: core|js|python|jvm|rust|cosmwasm|all

Environment:
  CLINE_CONFIG_OS=macos CLINE_CONFIG_ARCH=arm64   Override platform for dry-run inspection

Python tools install into: ${SECURITY_TOOLS_VENV}
Prebuilt binaries install into: ${SECURITY_TOOLS_BIN}

No sudo, no piped remote scripts. Checksum-verified GitHub downloads when
checksums.txt/SHA256SUMS is published (integrity only — not release authenticity).

See full/.cline/skills/security-audit-core/SKILL.md and README.md Security auditing.
EOF
}

main() {
  local dry_run=0
  local check_only=0
  local install_group_name=""

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
      -c|--check)
        check_only=1
        shift
        ;;
      --install)
        shift
        [[ $# -gt 0 ]] || die "--install requires a group (core|js|python|jvm|rust|cosmwasm|all)"
        install_group_name="$1"
        shift
        ;;
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
  done

  if [[ "$check_only" -eq 1 ]]; then
    report_tool_check
    exit $?
  fi

  if [[ -n "$install_group_name" ]]; then
    install_group "$dry_run" "$install_group_name"
    exit 0
  fi

  usage
  exit 0
}

main "$@"
