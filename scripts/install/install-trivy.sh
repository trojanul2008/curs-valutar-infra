#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
OS="Linux"
VERSION="${TRIVY_VERSION:-v0.50.1}"

if [ "$ARCH" = "x86_64" ]; then
  PLATFORM="64bit"
elif [ "$ARCH" = "aarch64" ]; then
  PLATFORM="ARM64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

TARBALL="trivy_${VERSION}_${OS}-${PLATFORM}.tar.gz"

echo "📦 Downloading Trivy for $ARCH..."
curl -sL "https://github.com/aquasecurity/trivy/releases/download/${VERSION}/${TARBALL}" | tar xz

file trivy

chmod +x trivy
sudo mv trivy /usr/local/bin/

echo "✅ Trivy installed successfully!"
