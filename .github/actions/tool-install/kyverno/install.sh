#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kyverno Installer with:
#   – Version from versions.yaml
#   – Platform detection
#   – Caching
#   – Logging & Version validation via utils.sh
#   – Archive validation to catch broken downloads
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

# ----- Normalize Architecture -------------------------------------------------
# Prevent issues with inconsistent ARCH naming
case "$ARCH" in
  x86_64) ARCH="linux_x86_64" ;;
  arm64|aarch64) ARCH="linux_arm64" ;;
  *) log_error "Unsupported architecture: ${ARCH}" && exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kyverno"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "✅ Cached kyverno found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kyverno
  if validate_version_match kyverno "$VERSION"; then
    log_success "✅ kyverno ${VERSION} activated from cache"
    exit 0
  else
    log_error "⚠️ Cached kyverno version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
URL="https://github.com/kyverno/kyverno/releases/download/${VERSION}/kyverno-cli_${VERSION}_${ARCH}.tar.gz"

log_info "⬇️  Downloading kyverno ${VERSION} for ${OS}/${ARCH}"
log_info "🔗 URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

ARCHIVE="kyverno.tar.gz"
curl -sSL "$URL" -o "$ARCHIVE"

# Validate archive is actually a gzip
if ! file "$ARCHIVE" | grep -q 'gzip'; then
  log_error "❌ Downloaded file is not a valid gzip archive"
  head -n 20 "$ARCHIVE" || echo "(binary content)"
  exit 1
fi

# Extract and locate binary
tar xzf "$ARCHIVE"

# If kyverno binary has a prefix, normalize it
mv kyverno* kyverno 2>/dev/null || true
chmod +x kyverno

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp kyverno "$BIN"
sudo mv kyverno /usr/local/bin/kyverno

# ----- Validate Final Version -------------------------------------------------
STRIPPED_VERSION="${VERSION#v}"
if ! validate_version_match kyverno "$STRIPPED_VERSION"; then
  log_error "❌ kyverno installed but version check failed"
  exit 1
fi

log_success "🎉 kyverno ${VERSION} installed successfully"

