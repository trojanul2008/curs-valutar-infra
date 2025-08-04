#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Trivy Installer with:
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
KEY="trivy"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/trivy"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached trivy found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/trivy
  if validate_version_match trivy "$VERSION"; then
    log_success "trivy ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached trivy version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
URL="https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${VERSION}_${OS}_${ARCH}.tar.gz"
log_info "Downloading trivy ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

if ! curl -sSL "$URL" | tar xz; then
  log_error "Download or extraction failed for trivy"
  exit 1
fi

chmod +x trivy

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp trivy "$BIN"
sudo mv trivy /usr/local/bin/trivy

# ----- Validate Final Version -------------------------------------------------
if ! validate_version_match trivy "$VERSION"; then
  log_error "trivy installed but version check failed"
  exit 1
fi

log_success "trivy ${VERSION} installed successfully"

