#!/usr/bin/env bash
set -e

echo "🔧 Installing Kubeconform..."
scripts/install/install-kubeconform.sh

echo "🛡️ Installing Kyverno..."
scripts/install/install-kyverno.sh

echo "⛵ Installing Helm..."
scripts/install/install-helm.sh

echo "📎 Installing YQ..."
scripts/install/install-yq.sh

echo "🔍 Installing Trivy..."
scripts/install/install-trivy.sh

echo "✅ All tools installed successfully!"
