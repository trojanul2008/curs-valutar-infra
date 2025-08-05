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
RAW_VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
VERSION="$(echo "$RAW_VERSION" | sed 's/^v//')"  # still useful if RAW is like v5.7.1

ENCODED_VERSION="kustomize%2F${RAW_VERSION}"
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/${ENCODED_VERSION}/kustomize_${VERSION}_${OS}_${ARCH}.tar.gz"



log_info "Downloading kustomize ${VERSION} for ${OS}/${ARCH}"
log_info "URL: ${URL}"

curl -sSL -o kustomize.tar.gz "$URL"
tar -xzf kustomize.tar.gz || { log_error "Failed to extract kustomize tarball"; exit 1; }

# ----- Post-Extraction: Verify & Move -----------------------------------------
if ! [[ -f kustomize ]]; then
  log_error "Extracted file 'kustomize' not found"
  exit 1
fi

if ! file kustomize | grep -qi 'elf'; then
  log_error "Downloaded file is not a valid ELF binary"
  head -n 10 kustomize
  exit 1
fi

chmod +x kustomize
mkdir -p "$CACHE"
cp kustomize "$BIN"
sudo mv kustomize /usr/local/bin/kustomize

# ----- Validate Final Version -------------------------------------------------
log_info "Raw kustomize version: $(kustomize version)"

if validate_version_match kustomize "$VERSION"; then
  log_success "kustomize ${VERSION} installed successfully"
else
  exit 1
fi
