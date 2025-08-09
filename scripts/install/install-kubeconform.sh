#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kubeconform) # e.g., 0.6.4
OS=linux
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
esac

TARBALL="kubeconform-${OS}-${ARCH}.tar.gz"
URL="https://github.com/yannh/kubeconform/releases/download/v${VERSION}/${TARBALL}"

curl -fsSLO "$URL"
tar -xzf "$TARBALL" kubeconform
chmod +x kubeconform
sudo mv kubeconform /usr/local/bin/kubeconform
rm -f "$TARBALL"
echo "✅ Kubeconform $(kubeconform -v) installed"

