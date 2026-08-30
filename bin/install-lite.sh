#!/usr/bin/env bash
# Install the lite/ profile into global Cline + OpenCode locations (or --project for Cline only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

install_profile "lite" "$@"
