#!/usr/bin/env bash
set -euo pipefail

source ./scripts/utils/load-version.sh

VERSION="$(get_version certManagerApp)"
NAMESPACE="cert-manager"

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "ERROR: certManagerApp version is missing from .github/versions.yaml"
  exit 1
fi

echo "Installing cert-manager v${VERSION}..."

kubectl apply \
  -f "https://github.com/cert-manager/cert-manager/releases/download/v${VERSION}/cert-manager.yaml"

kubectl rollout status deployment/cert-manager \
  -n "$NAMESPACE" \
  --timeout=180s

kubectl rollout status deployment/cert-manager-webhook \
  -n "$NAMESPACE" \
  --timeout=180s

kubectl rollout status deployment/cert-manager-cainjector \
  -n "$NAMESPACE" \
  --timeout=180s

echo "cert-manager v${VERSION} installed successfully."
