#!/usr/bin/env bash
# Shared helpers for install-security-tools.sh — opt-in security scanner installs.

set -euo pipefail

# Requires REPO_ROOT, die, info, detect_os from install-common.sh when sourced.

SECURITY_TOOLS_VENV="${SECURITY_TOOLS_VENV:-${HOME}/.local/share/cline-config/venv}"
SECURITY_TOOLS_BIN="${SECURITY_TOOLS_BIN:-${HOME}/.local/bin}"

# Override for dry-run inspection from Linux: CLINE_CONFIG_OS=macos CLINE_CONFIG_ARCH=arm64
detect_platform_os() {
  if [[ -n "${CLINE_CONFIG_OS:-}" ]]; then
    echo "$CLINE_CONFIG_OS"
    return
  fi
  detect_os
}

detect_platform_arch() {
  if [[ -n "${CLINE_CONFIG_ARCH:-}" ]]; then
    echo "$CLINE_CONFIG_ARCH"
    return
  fi
  local raw
  raw="$(uname -m)"
  case "$raw" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "$raw" ;;
  esac
}

sha256_of() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die "need sha256sum or shasum to verify downloads"
  fi
}

download_url() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    die "need curl or wget to download $url"
  fi
}

ensure_local_bin_on_path_hint() {
  case ":${PATH}:" in
    *":${SECURITY_TOOLS_BIN}:"*) return 0 ;;
  esac
  info "warning: ${SECURITY_TOOLS_BIN} is not on PATH."
  info "  Add to ~/.profile or ~/.zprofile:"
  info "    export PATH=\"${SECURITY_TOOLS_BIN}:\$PATH\""
}

python_tools_hint() {
  info "  Python security tools were not installed. Use one of:"
  info "    sudo apt install python3-venv"
  info "    ./bin/install-security-tools.sh --install python"
  info "  Or install uv (no sudo): curl -LsSf https://astral.sh/uv/install.sh | sh"
  info "    then: uv tool install semgrep bandit ruff pip-audit"
}

venv_is_usable() {
  [[ -f "${SECURITY_TOOLS_VENV}/bin/activate" ]] && \
    { [[ -x "${SECURITY_TOOLS_VENV}/bin/pip" ]] || [[ -x "${SECURITY_TOOLS_VENV}/bin/pip3" ]]; }
}

ensure_venv() {
  local dry_run="${1:-0}"
  if venv_is_usable; then
    return 0
  fi
  if [[ -d "$SECURITY_TOOLS_VENV" ]]; then
    info "  removing incomplete venv: $SECURITY_TOOLS_VENV"
    rm -rf "$SECURITY_TOOLS_VENV"
  fi
  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] would create venv: $SECURITY_TOOLS_VENV"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || {
    info "  error: python3 required for Python security tools"
    return 1
  }
  if ! python3 -m venv "$SECURITY_TOOLS_VENV" 2>"${SECURITY_TOOLS_VENV}.err"; then
    if grep -q ensurepip "${SECURITY_TOOLS_VENV}.err" 2>/dev/null; then
      rm -rf "$SECURITY_TOOLS_VENV"
      rm -f "${SECURITY_TOOLS_VENV}.err"
      info "  error: python3-venv package is not installed on this system"
      return 1
    fi
    rm -f "${SECURITY_TOOLS_VENV}.err"
    info "  error: failed to create venv at $SECURITY_TOOLS_VENV"
    return 1
  fi
  rm -f "${SECURITY_TOOLS_VENV}.err"
  if ! venv_is_usable; then
    rm -rf "$SECURITY_TOOLS_VENV"
    info "  error: venv created but pip/activate missing (install python3-venv)"
    return 1
  fi
  info "  created venv: $SECURITY_TOOLS_VENV"
  return 0
}

venv_pip_install() {
  local dry_run="$1"
  shift
  local pkgs=("$@")
  if [[ "$dry_run" == "1" ]]; then
    if command -v uv >/dev/null 2>&1; then
      info "  [dry-run] would uv tool install: ${pkgs[*]}"
    fi
    info "  [dry-run] would pip install in venv: ${pkgs[*]}"
    return 0
  fi
  if ! ensure_venv 0; then
    return 1
  fi
  # shellcheck disable=SC1091
  source "${SECURITY_TOOLS_VENV}/bin/activate"
  python3 -m pip install --upgrade pip >/dev/null
  python3 -m pip install --upgrade "${pkgs[@]}"
  deactivate 2>/dev/null || true
  mkdir -p "$SECURITY_TOOLS_BIN"
  local entry
  for entry in "${SECURITY_TOOLS_VENV}/bin/"*; do
    [[ -f "$entry" ]] || continue
    [[ -x "$entry" ]] || continue
    ln -sf "$entry" "${SECURITY_TOOLS_BIN}/$(basename "$entry")"
  done
  info "  pip installed: ${pkgs[*]} -> ${SECURITY_TOOLS_BIN}"
  return 0
}

# Prefer uv tool install (PEP 668-safe); fall back to dedicated venv + pip.
install_python_packages() {
  local dry_run="$1"
  shift
  local pkgs=("$@")
  local pkg failed=0

  if [[ "$dry_run" == "1" ]]; then
    venv_pip_install 1 "${pkgs[@]}"
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    mkdir -p "$SECURITY_TOOLS_BIN"
    for pkg in "${pkgs[@]}"; do
      if command -v "$pkg" >/dev/null 2>&1; then
        info "  ${pkg}: already on PATH"
        continue
      fi
      info "  uv tool install ${pkg}"
      if uv tool install "$pkg"; then
        # uv defaults to ~/.local/bin on Linux; ensure symlinks exist.
        local uv_bin="${HOME}/.local/bin/${pkg}"
        if [[ -x "$uv_bin" ]]; then
          ln -sf "$uv_bin" "${SECURITY_TOOLS_BIN}/${pkg}"
        fi
      else
        failed=1
      fi
    done
    if [[ "$failed" -eq 0 ]]; then
      return 0
    fi
    info "  uv tool install failed for some packages; trying venv fallback"
  fi

  if venv_pip_install 0 "${pkgs[@]}"; then
    return 0
  fi
  python_tools_hint
  return 1
}

tool_version() {
  local cmd="$1"
  shift || true
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>/dev/null | head -1 || echo "present"
  else
    echo "missing"
  fi
}

# --- GitHub release binary install ---
# Asset/checksum globs are matched against the latest release asset list (API),
# so versioned filenames (e.g. gitleaks_8.30.1_linux_x64.tar.gz) keep working.

gh_asset_glob_gitleaks() {
  local os="$1" arch="$2"
  case "$os" in
    linux)
      case "$arch" in
        amd64) echo "gitleaks_*_linux_x64.tar.gz" ;;
        arm64) echo "gitleaks_*_linux_arm64.tar.gz" ;;
        *) die "unsupported arch for gitleaks: $arch" ;;
      esac
      ;;
    macos)
      case "$arch" in
        arm64) echo "gitleaks_*_darwin_arm64.tar.gz" ;;
        amd64) echo "gitleaks_*_darwin_x64.tar.gz" ;;
        *) die "unsupported arch for gitleaks: $arch" ;;
      esac
      ;;
    *) die "unsupported OS for gitleaks: $os" ;;
  esac
}

gh_checksum_glob_gitleaks() {
  echo "gitleaks_*_checksums.txt"
}

gh_asset_glob_osv_scanner() {
  local os="$1" arch="$2"
  case "$os" in
    linux)
      case "$arch" in
        amd64) echo "osv-scanner_linux_amd64" ;;
        arm64) echo "osv-scanner_linux_arm64" ;;
        *) die "unsupported arch for osv-scanner: $arch" ;;
      esac
      ;;
    macos)
      case "$arch" in
        arm64) echo "osv-scanner_darwin_arm64" ;;
        amd64) echo "osv-scanner_darwin_amd64" ;;
        *) die "unsupported arch for osv-scanner: $arch" ;;
      esac
      ;;
    *) die "unsupported OS for osv-scanner: $os" ;;
  esac
}

gh_checksum_glob_osv_scanner() {
  echo "osv-scanner_SHA256SUMS"
}

gh_asset_glob_trivy() {
  local os="$1" arch="$2"
  case "$os" in
    linux)
      case "$arch" in
        amd64) echo "trivy_*_Linux-64bit.tar.gz" ;;
        arm64) echo "trivy_*_Linux-ARM64.tar.gz" ;;
        *) die "unsupported arch for trivy: $arch" ;;
      esac
      ;;
    macos)
      case "$arch" in
        arm64) echo "trivy_*_macOS-ARM64.tar.gz" ;;
        amd64) echo "trivy_*_macOS-64bit.tar.gz" ;;
        *) die "unsupported arch for trivy: $arch" ;;
      esac
      ;;
    *) die "unsupported OS for trivy: $os" ;;
  esac
}

gh_checksum_glob_trivy() {
  echo "trivy_*_checksums.txt"
}

# resolve_gh_release_assets <repo> <asset_glob> [checksum_glob]
# Prints: tag<TAB>asset_name<TAB>checksum_name (checksum_name may be empty)
resolve_gh_release_assets() {
  local repo="$1" asset_glob="$2" checksum_glob="${3:-}"
  command -v python3 >/dev/null 2>&1 || die "python3 required to resolve GitHub release assets"
  python3 - "$repo" "$asset_glob" "$checksum_glob" <<'PY'
import fnmatch
import json
import sys
import urllib.request

repo, asset_glob, checksum_glob = sys.argv[1:4]
url = f"https://api.github.com/repos/{repo}/releases/latest"
with urllib.request.urlopen(url, timeout=60) as resp:
    data = json.load(resp)
tag = data["tag_name"]
names = [a["name"] for a in data.get("assets", [])]
asset_matches = sorted(n for n in names if fnmatch.fnmatch(n, asset_glob))
if not asset_matches:
    raise SystemExit(
        f"no release asset matching {asset_glob!r} in {repo} {tag} "
        f"(available: {', '.join(names[:8])}{'...' if len(names) > 8 else ''})"
    )
checksum_name = ""
if checksum_glob:
    checksum_matches = sorted(n for n in names if fnmatch.fnmatch(n, checksum_glob))
    if checksum_matches:
        checksum_name = checksum_matches[-1]
print(f"{tag}\t{asset_matches[-1]}\t{checksum_name}")
PY
}

install_gh_binary() {
  local dry_run="$1"
  local repo="$2"            # owner/name
  local asset_glob_fn="$3"   # function: os arch -> asset glob
  local checksum_glob_fn="$4" # function: os arch -> checksum glob (optional)
  local bin_name="$5"        # installed binary name
  local os arch asset_glob checksum_glob resolved tag asset checksum_file verified=0

  os="$(detect_platform_os)"
  arch="$(detect_platform_arch)"
  asset_glob="$("$asset_glob_fn" "$os" "$arch")"
  checksum_glob=""
  if [[ -n "$checksum_glob_fn" ]]; then
    checksum_glob="$("$checksum_glob_fn" "$os" "$arch")"
  fi

  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] would install ${bin_name} from github.com/${repo} asset_glob=${asset_glob} (os=${os} arch=${arch})"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || die "curl or wget required"

  IFS=$'\t' read -r tag asset checksum_file < <(resolve_gh_release_assets "$repo" "$asset_glob" "$checksum_glob")
  [[ -n "$tag" && -n "$asset" ]] || die "could not resolve release asset for ${repo}"

  local url tmpdir
  url="https://github.com/${repo}/releases/download/${tag}/${asset}"
  tmpdir="$(mktemp -d)"
  # Capture path in trap string — local tmpdir is unset when RETURN fires under set -u.
  trap "rm -rf '${tmpdir}'" RETURN

  info "  downloading ${bin_name} ${tag} (${asset})"
  download_url "$url" "${tmpdir}/${asset}"

  if [[ -n "$checksum_file" ]]; then
    if download_url "https://github.com/${repo}/releases/download/${tag}/${checksum_file}" "${tmpdir}/${checksum_file}" 2>/dev/null; then
      local expected actual
      expected="$(grep "$asset" "${tmpdir}/${checksum_file}" | awk '{print $1}' | head -1 || true)"
      if [[ -n "$expected" ]]; then
        actual="$(sha256_of "${tmpdir}/${asset}")"
        [[ "$expected" == "$actual" ]] || die "checksum mismatch for ${asset} (verify release authenticity separately)"
        verified=1
        info "  checksum verified (${checksum_file})"
      fi
    fi
  fi
  if [[ "$verified" -eq 0 ]]; then
    info "  warning: no checksum file verified — download integrity only"
  fi

  mkdir -p "$SECURITY_TOOLS_BIN"
  case "$asset" in
    *.tar.gz|*.tgz)
      tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
      install -m 0755 "$(find "$tmpdir" -name "$bin_name" -type f | head -1)" "${SECURITY_TOOLS_BIN}/${bin_name}"
      ;;
    *)
      install -m 0755 "${tmpdir}/${asset}" "${SECURITY_TOOLS_BIN}/${bin_name}"
      ;;
  esac
  info "  installed ${bin_name} -> ${SECURITY_TOOLS_BIN}/${bin_name}"
}

install_via_brew() {
  local dry_run="$1" formula="$2"
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] would brew install ${formula}"
    return 0
  fi
  brew install "$formula"
  info "  brew installed ${formula}"
  return 0
}

cargo_install_tool() {
  local dry_run="$1" crate="$2"
  if [[ "$dry_run" == "1" ]]; then
    info "  [dry-run] would cargo install --locked ${crate}"
    return 0
  fi
  command -v cargo >/dev/null 2>&1 || die "cargo required for ${crate}"
  if command -v cargo-binstall >/dev/null 2>&1; then
    cargo binstall --locked -y "$crate"
  else
    cargo install --locked "$crate"
  fi
  info "  cargo installed ${crate}"
}

# Tool check registry: name|group|check_cmd|version_args|skills_that_degrade
SECURITY_TOOL_ROWS=(
  "gitleaks|core|gitleaks|version|security-audit-core backend-security-audit"
  "osv-scanner|core|osv-scanner|version|security-audit-core vulnerability-research"
  "trivy|core|trivy|version|security-audit-core backend-security-audit"
  "semgrep|core python|semgrep|--version|backend-security-audit"
  "opengrep|core|opengrep|--version|backend-security-audit"
  "bandit|python|bandit|--version|backend-security-audit"
  "ruff|python|ruff|--version|backend-security-audit"
  "pip-audit|python|pip-audit|--version|backend-security-audit"
  "detekt|jvm|detekt|version|backend-security-audit"
  "cargo-audit|rust cosmwasm|cargo-audit|audit --version|smart-contract-security-audit vulnerability-research"
  "cargo-deny|rust cosmwasm|cargo-deny|deny --version|smart-contract-security-audit"
  "cosmwasm-check|rust cosmwasm|cosmwasm-check|--version|smart-contract-security-audit"
  "cargo-llvm-cov|rust cosmwasm|cargo-llvm-cov|llvm-cov --version|smart-contract-security-audit"
)

tool_in_group() {
  local tool_group="$1" want_group="$2"
  [[ " $tool_group " == *" $want_group "* ]] || [[ "$want_group" == "all" ]]
}

report_tool_check() {
  local missing=0
  local os arch
  os="$(detect_platform_os)"
  arch="$(detect_platform_arch)"
  info "Platform: os=${os} arch=${arch}"
  info ""
  info "Tool                          Status    Version / note"
  info "------------------------------ --------- ------------------------------"
  local row name groups cmd ver_args skills status ver
  for row in "${SECURITY_TOOL_ROWS[@]}"; do
    IFS='|' read -r name groups cmd ver_args skills <<< "$row"
    if command -v "$cmd" >/dev/null 2>&1; then
      status="ok"
      ver="$(tool_version "$cmd" ${ver_args})"
    else
      status="missing"
      ver="—"
      missing=$((missing + 1))
    fi
    printf "  %-28s %-9s %s\n" "$name" "$status" "$ver"
    if [[ "$status" == "missing" ]]; then
      info "    degrades: $skills"
    fi
  done
  info ""
  info "Node (project-local, not installed globally):"
  info "  eslint-plugin-security, eslint-plugin-no-unsanitized — npm i -D in target repo"
  info ""
  ensure_local_bin_on_path_hint
  return "$missing"
}

install_group() {
  local dry_run="$1"
  local group="$2"
  local os
  os="$(detect_platform_os)"

  info "Installing group: ${group} (dry_run=${dry_run})"

  case "$group" in
    core)
      if [[ "$os" == "macos" ]]; then
        install_via_brew "$dry_run" gitleaks || install_gh_binary "$dry_run" gitleaks/gitleaks gh_asset_glob_gitleaks gh_checksum_glob_gitleaks gitleaks
        install_via_brew "$dry_run" osv-scanner || install_gh_binary "$dry_run" google/osv-scanner gh_asset_glob_osv_scanner gh_checksum_glob_osv_scanner osv-scanner
        install_via_brew "$dry_run" trivy || install_gh_binary "$dry_run" aquasecurity/trivy gh_asset_glob_trivy gh_checksum_glob_trivy trivy
      else
        install_gh_binary "$dry_run" gitleaks/gitleaks gh_asset_glob_gitleaks gh_checksum_glob_gitleaks gitleaks
        install_gh_binary "$dry_run" google/osv-scanner gh_asset_glob_osv_scanner gh_checksum_glob_osv_scanner osv-scanner
        install_gh_binary "$dry_run" aquasecurity/trivy gh_asset_glob_trivy gh_checksum_glob_trivy trivy
      fi
      install_python_packages "$dry_run" semgrep || info "  semgrep skipped (install python3-venv or uv — see hints above)"
      ;;
    python)
      install_python_packages "$dry_run" semgrep bandit ruff pip-audit || true
      ;;
    jvm)
      if install_via_brew "$dry_run" detekt; then
        :
      else
        info "  detekt CLI: install manually from https://github.com/detekt/detekt/releases"
        info "    (brew install detekt on macOS when Homebrew is available)"
      fi
      ;;
    rust|cosmwasm)
      cargo_install_tool "$dry_run" cargo-audit
      cargo_install_tool "$dry_run" cargo-deny
      cargo_install_tool "$dry_run" cosmwasm-check
      cargo_install_tool "$dry_run" cargo-llvm-cov
      ;;
    js)
      info "  Node tools are project-local — run in target repo:"
      info "    npm i -D eslint-plugin-security eslint-plugin-no-unsanitized"
      ;;
    all)
      install_group "$dry_run" core || true
      install_group "$dry_run" python || true
      install_group "$dry_run" jvm || true
      install_group "$dry_run" rust || true
      install_group "$dry_run" js || true
      ;;
    *)
      die "unknown install group: $group (use core|js|python|jvm|rust|cosmwasm|all)"
      ;;
  esac

  ensure_local_bin_on_path_hint
  info "Install group ${group} complete."
}
