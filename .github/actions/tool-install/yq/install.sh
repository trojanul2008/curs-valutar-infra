#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ yq Installer with:
#   – Version from versions.yaml
#   – Platform detection
#   – Caching
#   – Logging & Version validation via utils.sh
# --------------------------------------------------

# ----- Import Utilities -------------------------------------------------------
UTILS="${GITHUB_WORKSPACE}/.github/actions/common/utils.sh"
source "$UTILS"

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="yq"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

ARCH="$(uname -m)"
OS="$(uname -s)"

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  Linux*) OS="linux" ;;
  Darwin*) OS="darwin" ;;
  *) log_error "Unsupported OS: $OS"; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/yq"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached yq found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/yq
  if validate_version_match yq "$VERSION"; then
    log_success "yq ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached yq version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download ---------------------------------------------------------------
URL="https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_${OS}_${ARCH}"
log_info "Downloading yq ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

curl -sSL --fail -o yq "${URL}" || {
  log_error "yq download failed"
  exit 1
}

# ----- Cache & Move -----------------------------------------------------------
chmod +x yq
mkdir -p "$CACHE"
cp yq "$BIN"
sudo mv yq /usr/local/bin/yq

# ----- Validate Final Version -------------------------------------------------
if ! validate_version_match yq "$VERSION"; then
  log_error "yq installed but version check failed"
  exit 1
fi

log_success "yq ${VERSION} installed successfully"

