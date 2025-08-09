#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

CHART_VERSION=$(get_version kyvernoChart)  # e.g., 3.2.7
APP_VERSION=$(get_version kyvernoApp)      # optional
NAMESPACE="kyverno"

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm upgrade --install kyverno kyverno/kyverno \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$CHART_VERSION" \
  --set installCRDs=true \
  ${APP_VERSION:+--set image.tag="$APP_VERSION"} \
  --wait --timeout 10m

echo "✅ Kyverno chart ${CHART_VERSION} installed in namespace ${NAMESPACE}"

