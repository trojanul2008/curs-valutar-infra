#!/bin/bash
set -euo pipefail

KEY="yq"
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/yq"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached yq found"
  sudo cp "$BIN" /usr/local/bin/yq
  exit 0
fi

echo "📦 Downloading yq $VERSION..."
curl -sLo yq "https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_${OS}_${ARCH}"
chmod +x yq
mkdir -p "$CACHE"
cp yq "$BIN"
sudo mv yq /usr/local/bin/
