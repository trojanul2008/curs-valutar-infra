#!/bin/bash

set -euo pipefail

KUBECTL_VERSION="${1}"
FLUX_VERSION="${2}"
HELM_VERSION="${3}"

echo "🔧 Installing kubectl ${KUBECTL_VERSION}..."
curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "🔧 Installing flux ${FLUX_VERSION}..."
curl -s https://fluxcd.io/install.sh | bash
flux version || echo "⚠️ Flux not found"

echo "🔧 Installing helm ${HELM_VERSION}..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh --version ${HELM_VERSION}
rm get_helm.sh

echo "✅ Tool installation complete"
