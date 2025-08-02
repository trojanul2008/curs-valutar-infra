#!/usr/bin/env bash
set -e

# 💡 Defaults & metadata
VERSION="${TRIVY_VERSION:-v0.50.1}"
ARCH=$(uname -m)
OS="Linux"

# 🧠 Detect Trivy asset platform
case "$ARCH" in
  x86_64) PLATFORM="Linux-64bit" ;;
  aarch64) PLATFORM="Linux-ARM64" ;;
  armv7l) PLATFORM="Linux-ARM" ;;
  i686 | i386) PLATFORM="Linux-32bit" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

TARBALL="trivy_${VERSION}_${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/aquasecurity/trivy/releases/download/${VERSION}/${TARBALL}"

echo "📦 Downloading Trivy from: $DOWNLOAD_URL..."
curl -sSL -o "$TARBALL" "$DOWNLOAD_URL"

# 🔍 Validate archive format before extracting
if ! file "$TARBALL" | grep -q gzip; then
  echo "❌ The downloaded file is not a valid gzip archive."
  echo "🔎 Double-check the URL or TRIVY_VERSION: $DOWNLOAD_URL"
  exit 1
fi

echo "📂 Extracting Trivy binary..."
tar -xzf "$TARBALL"

# 🛠️ Ensure binary was extracted
if [ ! -f trivy ]; then
  echo "❌ Trivy binary not found after extraction."
  exit 1
fi

chmod +x trivy
sudo mv trivy /usr/local/bin/

# 🧹 Clean up
rm -f "$TARBALL"

echo "✅ Trivy installed successfully!"
trivy --version
