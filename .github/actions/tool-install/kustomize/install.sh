#!/bin/bash
set -euo pipefail

KEY="kustomize"
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kustomize"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached kustomize found"
  sudo cp "$BIN" /usr/local/bin/kustomize
  exit 0
fi

echo "📦 Downloading kustomize $VERSION for $OS/$ARCH..."
curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${VERSION}/kustomize_${VERSION}_${OS}_${ARCH}.tar.gz" | tar xz
chmod +x kustomize
mkdir -p "$CACHE"
cp kustomize "$BIN"
sudo mv kustomize /usr/local/bin/
