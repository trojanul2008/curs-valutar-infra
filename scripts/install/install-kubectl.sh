#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kubectl)  # e.g., 1.32.3
curl -fsSLo kubectl "https://dl.k8s.io/release/v${VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
echo "✅ kubectl $(kubectl version --client --short) installed"

