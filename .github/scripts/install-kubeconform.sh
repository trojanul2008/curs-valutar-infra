#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  PLATFORM="linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
  PLATFORM="linux-arm64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

VERSION="${KUBECONFORM_VERSION:-v0.6.7}"

curl -sL "https://github.com/yannh/kubeconform/releases/download/${VERSION}/kubeconform-${PLATFORM}.tar.gz" | tar xz
chmod +x kubeconform
sudo mv kubeconform /usr/local/bin/
