#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kubectl Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
#   – Logging & Version validation via utils.sh
# --------------------------------------------------

# ----- Import Utilities -------------------------------------------------------
UTILS="${GITHUB_WORKSPACE}/.github/actions/common/utils.sh"
source "$UTILS"

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="kubectl"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Platform Detection -----------------------------------------------------
RAW_ARCH="$(uname -m)"
RAW_OS="$(uname -s)"

case "$RAW_ARCH" in
  x86_64|amd64)      ARCH="amd64" ;;
  arm64|aarch64)     ARCH="arm64" ;;
  *)                 log_error "Unsupported architecture: $RAW_ARCH"; exit 1 ;;
esac

case "$RAW_OS" in
  Linux*)  OS="linux" ;;
  Darwin*) OS="darwin" ;;
  *)       log_error "Unsupported OS: $RAW_OS"; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kubectl"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached kubectl found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kubectl
  if validate_version_match kubectl "$VERSION"; then
    log_success "kubectl ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached kubectl version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download ---------------------------------------------------------------
URL="https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl"
log_info "Downloading kubectl ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

curl -sSL --fail -o kubectl "${URL}" || {
  log_error "kubectl download failed"
  exit 1
}

# ----- Install & Cache --------------------------------------------------------
chmod +x kubectl
mkdir -p "$CACHE"
cp kubectl "$BIN"
sudo mv kubectl /usr/local/bin/kubectl

# ----- Validate Final Version -------------------------------------------------
if ! validate_version_match kubectl "$VERSION"; then
  log_error "kubectl installed but version check failed"
  exit 1
fi

log_success "kubectl ${VERSION} installed successfully"

