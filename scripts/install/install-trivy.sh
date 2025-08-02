#!/usr/bin/env bash
set -e

VERSION="${TRIVY_VERSION:-0.50.1}"  # No 'v' in the filename, but keep it here for download path
ARCH=$(uname -m)
OS="Linux"

# Match Trivy release asset naming for platform
case "$ARCH" in
  x86_64) PLATFORM="${OS}-64bit" ;;
  aarch64) PLATFORM="${OS}-ARM64" ;;
  armv7l) PLATFORM="${OS}-ARM" ;;
  i686 | i386) PLATFORM="${OS}-32bit" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Construct filename and URL
FILENAME="trivy_${VERSION}_${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/${FILENAME}"

echo "📦 Downloading Trivy from: $DOWNLOAD_URL"
curl -sSL -o "$FILENAME" "$DOWNLOAD_URL"

echo "🔍 Validating archive format..."
if ! file "$FILENAME" | grep -q gzip; then
  echo "❌ Invalid archive format. Got:"
  head "$FILENAME" | cut -c-120
  exit 1
fi

echo "📂 Extracting Trivy..."
tar -xzf "$FILENAME"

if [ ! -f trivy ]; then
  echo "❌ Trivy binary not found!"
  exit 1
fi

chmod +x trivy
sudo mv trivy /usr/local/bin/
rm -f "$FILENAME"

echo "✅ Trivy installed successfully!"
trivy --version
