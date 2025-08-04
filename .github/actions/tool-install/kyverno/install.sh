#!/bin/bash
set -euo pipefail

KEY="kyverno"
VERSIONS_FILE=".github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/kyverno"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached kyverno found"
  sudo cp "$BIN" /usr/local/bin/kyverno
  exit 0
fi

echo "📦 Downloading kyverno CLI $VERSION..."
curl -sL "https://github.com/kyverno/kyverno/releases/download/v${VERSION}/kyverno-cli_${VERSION}_${OS}_${ARCH}.tar.gz" | tar xz
chmod +x kyverno
mkdir -p "$CACHE"
cp kyverno "$BIN"
sudo mv kyverno /usr/local/bin/
