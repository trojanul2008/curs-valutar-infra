#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Trivy Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
#   – Vulnerability scanner setup
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="trivy"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"
export TRIVY_CACHE_DIR="/tmp/.trivy-cache"

# ----- Platform Detection & Normalization -------------------------------------
RAW_ARCH="$(uname -m)"
RAW_OS="$(uname -s)"

case "$RAW_ARCH" in
  x86_64|amd64)      ARCH="amd64"  ;;
  arm64|aarch64)     ARCH="arm64"  ;;
  *)                 echo "❌ Unsupported architecture: $RAW_ARCH" >&2; exit 1 ;;
esac

case "$RAW_OS" in
  Linux*)  OS="linux"  ;;
  Darwin*) OS="darwin" ;;
  *)       echo "❌ Unsupported OS: $RAW_OS" >&2; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/trivy"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached trivy found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/trivy
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${OS}-${ARCH}.tar.gz"
echo "📦 Downloading trivy ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sSL "${URL}" | tar xz

# ----- Install & Cache --------------------------------------------------------
chmod +x trivy
mkdir -p "$CACHE"
cp trivy "$BIN"
sudo mv trivy /usr/local/bin/

echo "✅ trivy ${VERSION} installed successfully."

