#!/usr/bin/env bash
set -e

echo "🔧 Installing Kubeconform..."
scripts/install-kubeconform.sh

echo "🛡️ Installing Kyverno..."
scripts/install-kyverno.sh

echo "⛵ Installing Helm..."
scripts/install-helm.sh

echo "📎 Installing YQ..."
scripts/install-yq.sh

echo "🔍 Installing Trivy..."
scripts/install-trivy.sh

echo "✅ All tools installed successfully!"
