#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Helm Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="helm"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Platform Detection & Normalization -------------------------------------
RAW_ARCH="$(uname -m)"
RAW_OS="$(uname -s)"

case "$RAW_ARCH" in
  x86_64|amd64)      ARCH="amd64" ;;
  arm64|aarch64)     ARCH="arm64" ;;
  *)                 echo "❌ Unsupported architecture: $RAW_ARCH" >&2; exit 1 ;;
esac

case "$RAW_OS" in
  Linux*)  OS="linux" ;;
  Darwin*) OS="darwin" ;;
  *)       echo "❌ Unsupported OS: $RAW_OS" >&2; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/helm"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached helm found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/helm
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://get.helm.sh/helm-${VERSION}-${OS}-${ARCH}.tar.gz"
echo "📦 Downloading helm ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sL "${URL}" | tar xz
mv "${OS}-${ARCH}/helm" helm

# ----- Install & Cache --------------------------------------------------------
chmod +x helm
mkdir -p "$CACHE"
cp helm "$BIN"
sudo mv helm /usr/local/bin/

echo "✅ helm ${VERSION} installed successfully."

