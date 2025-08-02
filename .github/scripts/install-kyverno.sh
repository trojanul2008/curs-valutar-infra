#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  PLATFORM="linux_x86_64"
elif [ "$ARCH" = "aarch64" ]; then
  PLATFORM="linux_arm64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

VERSION="${KYVERNO_VERSION:-v1.12.4}"
TARBALL="kyverno-cli_${VERSION}_${PLATFORM}.tar.gz"

curl -sL "https://github.com/kyverno/kyverno/releases/download/${VERSION}/${TARBALL}" | tar xz
chmod +x kyverno
sudo mv kyverno /usr/local/bin/
