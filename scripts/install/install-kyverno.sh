#!/usr/bin/env bash
set -euo pipefail

source ./scripts/utils/load-version.sh

CHART_VERSION="$(get_version kyvernoChart)"
NAMESPACE="kyverno"

if [[ -z "$CHART_VERSION" || "$CHART_VERSION" == "null" ]]; then
  echo "ERROR: kyvernoChart version is missing from .github/versions.yaml"
  exit 1
fi

echo "Installing Kyverno chart ${CHART_VERSION}..."

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm upgrade --install kyverno kyverno/kyverno \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$CHART_VERSION" \
  --set crds.install=true \
  --wait \
  --timeout 10m

echo "Kyverno chart ${CHART_VERSION} installed successfully."
