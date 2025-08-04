#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ Kyverno Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="kyverno"
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
BIN="${CACHE}/kyverno"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached kyverno found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kyverno
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://github.com/kyverno/kyverno/releases/download/v${VERSION}/kyverno-cli_${VERSION}_${OS}_${ARCH}.tar.gz"
echo "📦 Downloading kyverno CLI ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sSL "${URL}" | tar xz

# ----- Install & Cache --------------------------------------------------------
chmod +x kyverno
mkdir -p "$CACHE"
cp kyverno "$BIN"
sudo mv kyverno /usr/local/bin/

echo "✅ kyverno ${VERSION} installed successfully."

