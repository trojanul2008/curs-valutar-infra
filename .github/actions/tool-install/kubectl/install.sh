#!/bin/bash
set -euo pipefail

VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
KEY="kubectl"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kubectl"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached kubectl found"
  sudo cp "$BIN" /usr/local/bin/kubectl
  exit 0
fi

echo "📦 Downloading kubectl $VERSION for $OS/$ARCH..."
curl -sLo kubectl "https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl"
file kubectl | grep -q 'ELF' || { echo "❌ Download failed"; exit 1; }

chmod +x kubectl
mkdir -p "$CACHE"
cp kubectl "$BIN"
sudo mv kubectl /usr/local/bin/
