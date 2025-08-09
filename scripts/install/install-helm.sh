#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version helm)     # e.g., 3.18.4
export DESIRED_VERSION="v${VERSION}"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "✅ Helm $(helm version --short) installed"

