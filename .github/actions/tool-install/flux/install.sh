#!/bin/bash
set -euo pipefail

KEY="flux"
VERSIONS_FILE="${GITHUB_WORKSPACE}/.github/versions.yaml"
VERSION=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk '{print $2}')
CACHE="/tmp/tool-cache/${KEY}-${VERSION}"

if [[ -f "$CACHE/$KEY" ]]; then
  echo "✅ Cached $KEY found"
  sudo cp "$CACHE/$KEY" /usr/local/bin/flux
  exit 0
fi

echo "📦 Installing flux $VERSION..."
curl -s https://fluxcd.io/install.sh | bash

mkdir -p "$CACHE"
cp "$(which flux)" "$CACHE/flux"
