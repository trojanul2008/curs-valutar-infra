#!/usr/bin/env bash
set -euo pipefail

source ./scripts/utils/load-version.sh

CHART_VERSION="$(get_version traefikChart)"
NAMESPACE="traefik"

if [[ -z "$CHART_VERSION" || "$CHART_VERSION" == "null" ]]; then
  echo "ERROR: traefikChart version is missing from .github/versions.yaml"
  exit 1
fi

echo "Installing Traefik chart ${CHART_VERSION}..."

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm upgrade --install traefik traefik/traefik \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$CHART_VERSION" \
  --wait \
  --timeout 10m

echo "Traefik chart ${CHART_VERSION} installed successfully."
