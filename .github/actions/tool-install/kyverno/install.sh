#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kyverno Installer with:
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
KEY="kyverno"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kyverno"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached kyverno found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kyverno
  if validate_version_match kyverno "$VERSION"; then
    log_success "kyverno ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached kyverno version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
URL="https://github.com/kyverno/kyverno/releases/download/v${VERSION}/kyverno-cli_${VERSION}_${OS}_${ARCH}.tar.gz"
log_info "Downloading kyverno ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

if ! curl -sSL "$URL" | tar xz; then
  log_error "Download or extraction failed for kyverno"
  exit 1
fi

chmod +x kyverno

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp kyverno "$BIN"
sudo mv kyverno /usr/local/bin/kyverno

# ----- Validate Final Version -------------------------------------------------
if ! validate_version_match kyverno "$VERSION"; then
  log_error "kyverno installed but version check failed"
  exit 1
fi

log_success "kyverno ${VERSION} installed successfully"

