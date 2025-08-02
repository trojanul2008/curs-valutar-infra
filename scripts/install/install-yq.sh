#!/usr/bin/env bash
set -e

VERSION="${YQ_VERSION:-v4.43.1}"
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  i386 | i686) ARCH="386" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

BINARY="yq_${OS}_${ARCH}"
URL="https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}"

echo "📥 Downloading yq for $OS/$ARCH..."
curl -sLo yq "$URL"
chmod +x yq
sudo mv yq /usr/local/bin/

yq --version

echo "✅ yq installed successfully!"
