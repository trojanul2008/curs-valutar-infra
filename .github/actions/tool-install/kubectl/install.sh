#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🛠️ kubectl Installer with:
#   – Version from versions.yaml
#   – ARCH/OS normalization
#   – Caching
#   – Binary validation
# --------------------------------------------------

# ----- Configuration ----------------------------------------------------------
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="kubectl"

# Extract version for kubectl from versions.yaml
VERSION="$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')"

# ----- Platform Detection & Normalization -------------------------------------
RAW_ARCH="$(uname -m)"
RAW_OS="$(uname -s)"

# Normalize architecture
case "$RAW_ARCH" in
  x86_64|amd64)      ARCH="amd64"  ;;
  arm64|aarch64)     ARCH="arm64"  ;;
  armv7l|armv6l)     ARCH="arm"    ;;  # Included for completeness
  *)                 echo "❌ Unsupported architecture: $RAW_ARCH" >&2; exit 1 ;;
esac

# Normalize OS
case "$RAW_OS" in
  Linux*)  OS="linux"  ;;
  Darwin*) OS="darwin" ;;
  *)       echo "❌ Unsupported OS: $RAW_OS" >&2; exit 1 ;;
esac

# ----- Paths ------------------------------------------------------------------
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kubectl"

# ----- Check cache ------------------------------------------------------------
if [[ -f "$BIN" ]]; then
  echo "✅ Cached kubectl found for ${OS}/${ARCH} at ${BIN}"
  sudo cp "$BIN" /usr/local/bin/kubectl
  exit 0
fi

# ----- Download ---------------------------------------------------------------
URL="https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl"
echo "📦 Downloading kubectl ${VERSION} for ${OS}/${ARCH}..."
echo "🔗 ${URL}"

curl -sSL --fail -o kubectl "${URL}" || {
  echo "❌ Download failed — curl couldn't retrieve the binary." >&2
  exit 1
}

# ----- Validate binary --------------------------------------------------------
if ! file kubectl | grep -qE 'ELF|Mach-O'; then
  echo "❌ Downloaded file is not a valid executable for ${OS}/${ARCH}" >&2
  echo "🔍 URL tried: ${URL}" >&2
  exit 1
fi

# ----- Install & Cache --------------------------------------------------------
chmod +x kubectl
mkdir -p "$CACHE"
cp kubectl "$BIN"
sudo mv kubectl /usr/local/bin/

echo "✅ kubectl $(kubectl version --client --short | tr -d '\n') installed successfully."

