#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Flux Installer with:
#   – Version from versions.yaml
#   – Caching
#   – CLI validation
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="flux"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/flux"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached flux found at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/flux
  exit 0
fi

# ----- Install via official script --------------------------------------------
echo "📦 Installing flux ${VERSION} from fluxcd.io..."
curl -s https://fluxcd.io/install.sh | bash

# ----- Validate install -------------------------------------------------------
if ! flux --version | grep -q "${VERSION}"; then
  echo "❌ Flux version mismatch or install failed" >&2
  exit 1
fi

# ----- Install & Cache --------------------------------------------------------
mkdir -p "$CACHE"
cp "$(command -v flux)" "$BIN"
sudo mv "$BIN" /usr/local/bin/flux

echo "✅ flux ${VERSION} installed successfully."

