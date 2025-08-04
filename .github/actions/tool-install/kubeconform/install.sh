#!/bin/bash
set -euo pipefail

KEY="kubeconform"
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kubeconform"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached kubeconform found"
  sudo cp "$BIN" /usr/local/bin/kubeconform
  exit 0
fi

echo "📦 Downloading kubeconform $VERSION..."
curl -sL "https://github.com/yannh/kubeconform/releases/download/v${VERSION}/kubeconform-${OS}-${ARCH}.tar.gz" | tar xz
chmod +x kubeconform
mkdir -p "$CACHE"
cp kubeconform "$BIN"
sudo mv kubeconform /usr/local/bin/
