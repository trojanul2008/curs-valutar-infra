#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version trivy)
INSTALL_DIR="/usr/local/bin"

echo "📥 Installing Trivy v${VERSION} into ${INSTALL_DIR}"
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | bash -s -- -b "${INSTALL_DIR}" "v${VERSION}"

# Verify and expose path
if ! command -v trivy &>/dev/null; then
  echo "❌ Trivy install failed or not on PATH"
  exit 1
fi

echo "✅ Trivy installed → $(trivy --version | head -n1)"

