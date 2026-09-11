#!/usr/bin/env bash
# Generate/refresh the OpenCode global config (opencode.jsonc) by querying
# the local OpenAI-compatible model server's /models endpoint.
#
# See lib/opencode-config-common.sh for the merge/backup semantics: the
# provider.local-llm block is managed (marker-delimited, regenerated on each
# run) while every other setting in the file is preserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"
# shellcheck source=lib/opencode-common.sh
source "${SCRIPT_DIR}/lib/opencode-common.sh"
# shellcheck source=lib/opencode-config-common.sh
source "${SCRIPT_DIR}/lib/opencode-config-common.sh"

usage_opencode_config() {
  cat <<EOF
Usage: install-opencode-config.sh [options]

Generate or refresh the OpenCode global config (\${OPENCODE_CONFIG_DIR:-~/.config/opencode}/${OC_CONFIG_NAME})
from the local OpenAI-compatible model server.

The script queries \$LLM_URL/models (default: ${LLM_URL_DEFAULT}/models) and
(re)generates the "provider.local-llm" block of ${OC_CONFIG_NAME} with that URL
as baseURL, headerTimeout: false (so long local prefills are not aborted), and
one entry per model id the server reports. All other settings in the file are
preserved.

Options:
  -h, --help          Show this help
  -n, --dry-run       Query the server and print the resulting config without writing
      --url URL       Use URL as LLM_URL for this run (overrides the environment)

Environment:
  LLM_URL             Base URL of the OpenAI-compatible server
                      (default: ${LLM_URL_DEFAULT}); the endpoint queried is
                      \$LLM_URL/models
  OPENCODE_CONFIG_DIR Override the OpenCode config directory (else
                      \$XDG_CONFIG_HOME/opencode or ~/.config/opencode)

Notes:
  * The managed block is delimited by "// cline-config:begin local-llm" /
    "// cline-config:end local-llm" comments, so re-runs rewrite only that
    block (and do not create new backups).
  * A user-authored ${OC_CONFIG_NAME} (no markers) is backed up to
    ${OC_CONFIG_NAME}.bak-<timestamp> before the first in-place merge.
  * The script refuses to write while an editor has the file open
    (${OC_CONFIG_NAME}.swp present), and never writes a file that fails
    post-validation (invalid JSON, or a provider block that does not match
    the fetched model list).
  * install-full.sh / install-lite.sh run this script as a best-effort step:
    if the LLM server is unreachable they warn and continue. Run this script
    directly for a hard-failing refresh.
EOF
}

dry_run=0
LLM_URL="${LLM_URL:-${LLM_URL_DEFAULT}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage_opencode_config
      exit 0
      ;;
    -n|--dry-run)
      dry_run=1
      shift
      ;;
    --url)
      [[ $# -ge 2 ]] || die "--url requires a value"
      LLM_URL="$2"
      shift 2
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

refresh_opencode_models "$dry_run" 1 "$LLM_URL"
