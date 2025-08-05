#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ yq Installer Script
# --------------------------------------------------
# Features:
#   – Gets version from versions.yaml
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
KEY="yq"

# ✅ Strip 'v' prefix from version to match expected download format
RAW_VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
VERSION="${RAW_VERSION#v}"

# ----- Platform Detection -----------------------------------------------------
ARCH="$(uname -m)"
OS="$(uname -s)"

# 🔎 Normalize architecture
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) log_error "❌ Unsupported architecture: ${ARCH}" && exit 1 ;;
esac

# 🔎 Normalize OS name
case "$OS" in
  Linux*) OS="linux" ;;
  Darwin*) OS="darwin" ;;
  *) log_error "❌ Unsupported OS: ${OS}" && exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/yq"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "✅ Cached yq found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/yq
  if validate_version_match yq "$RAW_VERSION"; then
    log_success "✅ yq ${RAW_VERSION} activated from cache"
    exit 0
  else
    log_error "⚠️ Cached yq version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Install -----------------------------------------------------
URL="https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_${OS}_${ARCH}"

log_info "⬇️  Downloading yq ${RAW_VERSION} for ${OS}/${ARCH}"
log_info "🔗 URL: ${URL}"

curl -sSL --fail -o yq "${URL}" || {
  log_error "❌ yq download failed"
  exit 1
}

# ----- Cache & Deploy ---------------------------------------------------------
chmod +x yq
mkdir -p "$CACHE"
cp yq "$BIN"
sudo mv yq /usr/local/bin/yq

# ----- Validate Installed Version ---------------------------------------------
if ! validate_version_match yq "$RAW_VERSION"; then
  log_error "❌ yq installed but version check failed"
  exit 1
fi

log_success "🎉 yq ${RAW_VERSION} installed successfully"

