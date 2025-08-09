#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version flux)

OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
esac

TARBALL="flux_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/fluxcd/flux2/releases/download/v${VERSION}/${TARBALL}"

echo "📥 Downloading flux CLI v${VERSION} from ${URL}"
curl -fsSL -o "$TARBALL" "$URL"
tar -xzf "$TARBALL" flux
chmod +x flux
sudo mv flux /usr/local/bin/flux
rm -f "$TARBALL"

echo "✅ Flux $(flux --version) installed"

