#!/bin/bash
set -euo pipefail

KEY="helm"
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/helm"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached helm found"
  sudo cp "$BIN" /usr/local/bin/helm
  exit 0
fi

echo "📦 Downloading helm $VERSION for $OS/$ARCH..."
curl -sL "https://get.helm.sh/helm-${VERSION}-${OS}-${ARCH}.tar.gz" | tar xz
mv ${OS}-${ARCH}/helm helm
chmod +x helm
mkdir -p "$CACHE"
cp helm "$BIN"
sudo mv helm /usr/local/bin/
