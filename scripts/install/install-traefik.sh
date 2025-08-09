#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

CHART_VERSION=$(get_version traefikChart)
NAMESPACE="traefik"

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm upgrade --install traefik traefik/traefik \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$CHART_VERSION" \
  --set additionalArguments={--providers.kubernetescrd} \
  --wait --timeout 10m

echo "✅ Traefik chart ${CHART_VERSION} installed in namespace ${NAMESPACE}"

