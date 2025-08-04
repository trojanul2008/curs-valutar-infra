#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kustomize Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="kustomize"
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
BIN="${CACHE}/kustomize"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached kustomize found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kustomize
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${VERSION}/kustomize_${VERSION}_${OS}_${ARCH}.tar.gz"
echo "📦 Downloading kustomize ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sSL "${URL}" | tar xz

# ----- Install & Cache --------------------------------------------------------
chmod +x kustomize
mkdir -p "$CACHE"
cp kustomize "$BIN"
sudo mv kustomize /usr/local/bin/

echo "✅ kustomize ${VERSION} installed successfully."

