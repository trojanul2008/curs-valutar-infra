#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ yq Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="yq"
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

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
BIN="${CACHE}/yq"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached yq found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/yq
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_${OS}_${ARCH}"
echo "📦 Downloading yq ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sSL -o yq "${URL}"

# ----- Validate binary --------------------------------------------------------
if ! file yq | grep -qE 'ELF|Mach-O'; then
  echo "❌ Invalid yq binary for ${OS}/${ARCH}" >&2
  echo "🔍 URL tried: ${URL}" >&2
  exit 1
fi

# ----- Install & Cache --------------------------------------------------------
chmod +x yq
mkdir -p "$CACHE"
cp yq "$BIN"
sudo mv yq /usr/local/bin/

echo "✅ yq ${VERSION} installed successfully."

