#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kyvernoApp)
OS="linux"

ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported arch: $ARCH_RAW"; exit 1 ;;
esac

BINARY="kyverno-cli_v${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/kyverno/kyverno/releases/download/v${VERSION}/${BINARY}"

echo "📥 Downloading Kyverno CLI from: $URL"
curl -fsSLO "$URL"
tar -xzf "$BINARY" kyverno
chmod +x kyverno
sudo mv kyverno /usr/local/bin/kyverno
rm -f "$BINARY"

echo "✅ Kyverno CLI $(kyverno version) installed"

