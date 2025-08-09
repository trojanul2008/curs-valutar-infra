#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version yq)   # e.g., 4.43.1
curl -fsSLo yq "https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_linux_amd64"
chmod +x yq
sudo mv yq /usr/local/bin/yq
echo "✅ yq $(yq --version) installed"

