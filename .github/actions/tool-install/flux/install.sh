#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Flux Installer with:
#   – Version from versions.yaml
#   – Caching
#   – Logging & Version validation via utils.sh
# --------------------------------------------------

# ----- Import Utilities -------------------------------------------------------
UTILS="${GITHUB_WORKSPACE}/.github/actions/common/utils.sh"
source "$UTILS"

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="flux"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}' | sed 's/^v//')"


# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/flux"

# ----- Use Cached Binary if Available -----------------------------------------
if [[ -f "$BIN" ]]; then
  log_success "Cached flux found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/flux
  if validate_version_match flux "$VERSION"; then
    log_success "flux ${VERSION} activated from cache"
    exit 0
  else
    log_error "Cached flux version mismatch — redownloading"
    rm -f "$BIN"
  fi
fi

# ----- Download via Official Script -------------------------------------------
log_info "Installing flux ${VERSION} using fluxcd.io installer..."

if ! curl -s https://fluxcd.io/install.sh | bash; then
  log_error "flux install.sh script failed"
  exit 1
fi

# ----- Cache & Move -----------------------------------------------------------
mkdir -p "$CACHE"
cp "$(command -v flux)" "$BIN"
sudo mv "$BIN" /usr/local/bin/flux

# ----- Validate Final Version -------------------------------------------------
INSTALLED="$(flux --version 2>/dev/null | awk '{print $NF}')"

if [[ "$INSTALLED" != "$VERSION" ]]; then
  log_error "Installed flux version '$INSTALLED' does not match expected '$VERSION'"
  exit 1
fi

