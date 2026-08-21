#!/bin/bash
set -e

source ./scripts/utils/load-version.sh

VERSION=$(get_version certManagerApp)
NAMESPACE="cert-manager"

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
