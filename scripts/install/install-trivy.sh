#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version trivy)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | bash -s -- -b /usr/local/bin "v${VERSION}"
echo "✅ Trivy $(trivy --version | head -n 1) installed"

