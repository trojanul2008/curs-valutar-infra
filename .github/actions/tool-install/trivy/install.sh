#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Trivy Installer Script
# --------------------------------------------------
# Features:
#   – Retrieves version from versions.yaml
#   – Detects platform and architecture
#   – Uses caching for faster builds
#   – Logs steps using utils.sh
#   – Validates version after install
# --------------------------------------------------

# ----- Import Utilities -------------------------------------------------------
UTILS="${GITHUB_WORKSPACE}/.github/actions/common/utils.sh"
source "$UTILS"

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="trivy"
RAW_VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
VERSION="${RAW_VERSION#v}"

# ----- Platform Detection -----------------------------------------------------
ARCH="$(uname -m)"
OS="$(uname -s)"

# 🔎 Normalize architecture
case "$ARCH" in
  x86_64|amd64) ARCH="64bit" ;;
  arm64|aarch64) ARCH="ARM64" ;;
  *) log_error "❌ Unsupported architecture: ${ARCH}" && exit 1 ;;
esac

# 🔎 Normalize OS name
case "$OS" in
  Linux*) OS="Linux" ;;
  Darwin*) OS="macOS" ;;  # Trivy releases use "macOS" in archive names
  *) log_error "❌ Unsupported OS: ${OS}" && exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/trivy"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "✅ Cached trivy found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/trivy
  if validate_version_match trivy "$RAW_VERSION"; then
    log_success "✅ trivy ${RAW_VERSION} activated from cache"
    exit 0
  else
    log_error "⚠️ Cached trivy version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Install -----------------------------------------------------
URL="https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${VERSION}_${OS}-${ARCH}.tar.gz"

log_info "⬇️  Downloading trivy ${RAW_VERSION} for ${OS}/${ARCH}"
log_info "🔗 URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

if ! curl -sSL --fail "$URL" | tar xz; then
  log_error "❌ Download or extraction failed for trivy"
  exit 1
fi

chmod +x trivy

# ----- Cache & Deploy ---------------------------------------------------------
mkdir -p "$CACHE"
cp trivy "$BIN"
sudo mv trivy /usr/local/bin/trivy

# ----- Validate Installed Version ---------------------------------------------
if validate_version_match trivy "$RAW_VERSION"; then
  log_success "🎉 trivy ${RAW_VERSION} installed successfully"
else
  log_error "❌ Installed trivy version does not match expected ${RAW_VERSION}"
  exit 1
fi

