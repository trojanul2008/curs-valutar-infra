#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kustomize Installer with:
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
KEY="kustomize"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Platform Detection -----------------------------------------------------
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kustomize"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached kustomize found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kustomize
  if validate_version_match kustomize "$VERSION"; then
    log_success "kustomize ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached kustomize version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
# ----- Download ---------------------------------------------------------------
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${VERSION}/kustomize_${VERSION}_${OS}_${ARCH}"
log_info "Downloading kustomize ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

curl -sSL -o kustomize "$URL"
chmod +x kustomize

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp kustomize "$BIN"
sudo mv kustomize /usr/local/bin/kustomize

# ----- Validate Final Version -------------------------------------------------
if ! validate_version_match kustomize "$VERSION"; then
  log_error "kustomize installed but version check failed"
  exit 1
fi

log_success "kustomize ${VERSION} installed successfully"

