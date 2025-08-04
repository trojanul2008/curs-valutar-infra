#!/bin/bash
set -euo pipefail

KEY="trivy"
VERSIONS_FILE=".github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

export TRIVY_CACHE_DIR="/tmp/.trivy-cache"
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"
BIN="${CACHE}/trivy"

if [[ -f "$BIN" ]]; then
  echo "✅ Cached trivy found"
  sudo cp "$BIN" /usr/local/bin/trivy
  exit 0
fi

echo "📦 Downloading trivy $VERSION..."
curl -sL "https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${OS}-${ARCH}.tar.gz" | tar xz
chmod +x trivy
mkdir -p "$CACHE"
cp trivy "$BIN"
sudo mv trivy /usr/local/bin/
