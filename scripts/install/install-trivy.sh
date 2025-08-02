#!/usr/bin/env bash
set -e

VERSION="${TRIVY_VERSION:-v0.50.1}"
ARCH=$(uname -m)
OS="Linux"

# 🧠 Match GitHub release asset platform naming
case "$ARCH" in
  x86_64) PLATFORM="${OS}-64bit" ;;
  aarch64) PLATFORM="${OS}-ARM64" ;;
  armv7l) PLATFORM="${OS}-ARM" ;;
  i686 | i386) PLATFORM="${OS}-32bit" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# 🔧 Correct asset file name and URL
TARBALL="trivy_${VERSION}_${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/aquasecurity/trivy/releases/download/${VERSION}/${TARBALL}"

echo "📦 Downloading Trivy from: $DOWNLOAD_URL"
curl -sSL -o "$TARBALL" "$DOWNLOAD_URL"

echo "🔍 Validating archive format..."
if ! file "$TARBALL" | grep -q gzip; then
  echo "❌ Invalid archive format. Expected gzip, got something else."
  echo "🔎 Check asset URL or TRIVY_VERSION: $DOWNLOAD_URL"
  exit 1
fi

echo "📂 Extracting Trivy..."
tar -xzf "$TARBALL"

if [ ! -f trivy ]; then
  echo "❌ Trivy binary not found after extraction!"
  exit 1
fi

chmod +x trivy
sudo mv trivy /usr/local/bin/
rm -f "$TARBALL"

echo "✅ Trivy installed successfully!"
trivy --version

