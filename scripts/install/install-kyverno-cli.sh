#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kyvernoApp)  # reuse app version for CLI
OS="linux"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
esac

BINARY="kyverno-cli_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/kyverno/kyverno/releases/download/v${VERSION}/${BINARY}"

curl -fsSLO "$URL"
tar -xzf "$BINARY" kyverno
chmod +x kyverno
sudo mv kyverno /usr/local/bin/kyverno
rm -f "$BINARY"
echo "✅ Kyverno CLI $(kyverno version) installed"

