#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kyvernoApp)   # e.g., 1.12.4
OS="linux"
ARCH="amd64"  # CI uses x64 runners; use arch detection if needed

BINARY="kyverno_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/kyverno/kyverno/releases/download/v${VERSION}/${BINARY}"

echo "📥 Downloading Kyverno CLI from: $URL"
curl -fsSLO "$URL"
tar -xzf "$BINARY" kyverno
chmod +x kyverno
sudo mv kyverno /usr/local/bin/kyverno
rm -f "$BINARY"

echo "✅ Kyverno CLI $(kyverno version) installed"

