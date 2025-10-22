#!/bin/bash
set -e

echo "🧩 Installing CLI tools from versions.yaml..."
scripts/install/install-helm.sh
scripts/install/install-kubectl.sh
scripts/install/install-kustomize.sh
scripts/install/install-yq.sh
scripts/install/install-trivy.sh
scripts/install/install-kubeconform.sh
scripts/install/install-flux.sh
scripts/install/install-kyverno-cli.sh
scripts/install/install-snyk-checkov.sh
echo "✅ All CLI tools installed successfully"

