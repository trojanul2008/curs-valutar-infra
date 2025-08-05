#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kubeconform Installer with:
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
KEY="kubeconform"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Platform Detection -----------------------------------------------------
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kubeconform"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "✅ Cached kubeconform found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kubeconform
  if validate_version_match kubeconform "$VERSION"; then
    log_success "✅ kubeconform ${VERSION} activated from cache"
    exit 0
  else
    log_error "⚠️ Cached kubeconform version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download & Extract -----------------------------------------------------
URL="https://github.com/yannh/kubeconform/releases/download/${VERSION}/kubeconform-${OS}-${ARCH}.tar.gz"
log_info "⬇️  Downloading kubeconform ${VERSION} for ${OS}/${ARCH}"
log_info "🔗 URL: ${URL}"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

if ! curl -sSL "$URL" | tar xz; then
  log_error "❌ Download or extraction failed for kubeconform"
  exit 1
fi

chmod +x kubeconform

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp kubeconform "$BIN"
sudo mv kubeconform /usr/local/bin/

# ----- Validate Final Version -------------------------------------------------
actual_version="$(/usr/local/bin/kubeconform -v | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+')"
expected_version="$VERSION"

if [[ "$actual_version" == "$expected_version" || "$actual_version" == "v$expected_version" ]]; then
  log_success "✅ kubeconform ${expected_version} installed successfully"
else
  log_error "❌ Installed kubeconform version '$actual_version' does not match expected '$expected_version'"
  exit 1
fi
