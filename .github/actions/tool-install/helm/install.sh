#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Helm Installer
#   – Uses shared utils for logging + version checks
#   – Normalizes platform
#   – Caches binary for reuse
# --------------------------------------------------

# ----- Import Utilities -------------------------------------------------------
UTILS="${GITHUB_WORKSPACE}/.github/actions/common/utils.sh"
source "$UTILS"

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="helm"
#VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
RAW_VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
VERSION="$(echo "$RAW_VERSION" | sed 's/^v//')"    # strip v if present
TAG="v${VERSION}"                                  # ensure v-prefix for GitHub URLs


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
BIN="${CACHE}/helm"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached helm found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/helm
  if validate_version_match helm "$VERSION"; then
    log_success "helm ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached helm version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
URL="https://get.helm.sh/helm-v${VERSION}-${OS}-${ARCH}.tar.gz"
log_info "Downloading helm ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

if ! curl -sSL "${URL}" | tar xz; then
  log_error "Download or extraction failed for Helm ${VERSION}"
  exit 1
fi

mv "${OS}-${ARCH}/helm" helm
chmod +x helm

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp helm "$BIN"
sudo mv helm /usr/local/bin/helm

# ----- Validate Final Version -------------------------------------------------
INSTALLED_VERSION="$(helm version --short 2>/dev/null | awk -F '+' '{print $1}' | tr -d '[:space:]')"
EXPECTED_VERSION="$(echo "$VERSION" | tr -d '[:space:]')"

if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" && "$INSTALLED_VERSION" != "v${EXPECTED_VERSION}" ]]; then
  log_error "Installed helm version '$INSTALLED_VERSION' does not match expected '$VERSION'"
  exit 1
fi

log_success "helm ${VERSION} installed successfully"

