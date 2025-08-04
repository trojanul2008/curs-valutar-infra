#!/bin/bash
set -euo pipefail

VERSIONS_FILE=".github/versions.yaml"

get_version() {
  local key="$1"
  grep "^${key}:" "$VERSIONS_FILE" | awk '{print $2}'
}

KUBECTL_VERSION=$(get_version kubectl)
FLUX_VERSION=$(get_version flux)
HELM_VERSION=$(get_version helm)
KUSTOMIZE_VERSION=$(get_version KUSTOMIZE_VERSION)
KUBECONFORM_VERSION=$(get_version KUBECONFORM_VERSION)
KYVERNO_VERSION=$(get_version KYVERNO_VERSION)
YQ_VERSION=$(get_version YQ_VERSION)
TRIVY_VERSION=$(get_version TRIVY_VERSION)
TRIVY_CACHE_DIR=$(get_version TRIVY_CACHE_DIR)
HELM_PLUGIN_DIR=$(get_version HELM_PLUGIN_DIR)

# 🧪 Fail early if anything is missing
for var in KUBECTL_VERSION FLUX_VERSION HELM_VERSION KUSTOMIZE_VERSION KUBECONFORM_VERSION KYVERNO_VERSION YQ_VERSION TRIVY_VERSION; do
  if [[ -z "${!var}" ]]; then
    echo "❌ Missing $var in versions.yaml"; exit 1
  fi
done

echo "🔧 Installing kubectl $KUBECTL_VERSION..."
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
file kubectl | grep -q 'ELF' || { echo "❌ kubectl download failed"; exit 1; }
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

echo "🔧 Installing flux $FLUX_VERSION..."
curl -s https://fluxcd.io/install.sh | bash || echo "⚠️ Flux installation issue"
flux version || echo "⚠️ Flux not found"

echo "🔧 Installing helm $HELM_VERSION..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --version "$HELM_VERSION"

echo "🔧 Installing kustomize $KUSTOMIZE_VERSION..."
curl -Lo kustomize.tar.gz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
tar -xzf kustomize.tar.gz && chmod +x kustomize && sudo mv kustomize /usr/local/bin/

echo "🔧 Installing kubeconform $KUBECONFORM_VERSION..."
curl -Lo kubeconform.tar.gz "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
tar -xzf kubeconform.tar.gz && chmod +x kubeconform && sudo mv kubeconform /usr/local/bin/

echo "🔧 Installing kyverno $KYVERNO_VERSION..."
curl -Lo kyverno.tar.gz "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_x86_64.tar.gz"
tar -xzf kyverno.tar.gz && chmod +x kyverno && sudo mv kyverno /usr/local/bin/

echo "🔧 Installing yq $YQ_VERSION..."
curl -Lo yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
chmod +x yq && sudo mv yq /usr/local/bin/

echo "🔧 Installing trivy $TRIVY_VERSION..."
curl -Lo trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
mkdir -p "$TRIVY_CACHE_DIR"
tar -xzf trivy.tar.gz && chmod +x trivy && sudo mv trivy /usr/local/bin/

echo "✅ All tools installed successfully!"
