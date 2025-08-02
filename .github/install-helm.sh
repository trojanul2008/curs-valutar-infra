#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  PLATFORM="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  PLATFORM="arm64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

VERSION="${HELM_VERSION:-v3.14.0}"
TARBALL="helm-${VERSION}-linux-${PLATFORM}.tar.gz"

# Download and extract
curl -sL "https://get.helm.sh/${TARBALL}" | tar xz
chmod +x linux-${PLATFORM}/helm
sudo mv linux-${PLATFORM}/helm /usr/local/bin/
