#!/usr/bin/env bash
set -euo pipefail

source ./scripts/utils/load-version.sh

VERSION="$(get_version argocdApp)"
NAMESPACE="argocd"

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "ERROR: argocdApp version is missing from .github/versions.yaml"
  exit 1
fi

echo "Installing Argo CD v${VERSION}..."

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  kubectl create namespace "$NAMESPACE"
fi

kubectl apply \
  --server-side \
  --force-conflicts \
  -n "$NAMESPACE" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/v${VERSION}/manifests/install.yaml"

echo "Waiting for Argo CD deployments..."

for deployment in \
  argocd-applicationset-controller \
  argocd-dex-server \
  argocd-notifications-controller \
  argocd-redis \
  argocd-repo-server \
  argocd-server
do
  kubectl rollout status \
    "deployment/${deployment}" \
    -n "$NAMESPACE" \
    --timeout=300s
done

echo "Waiting for Argo CD application controller..."

kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "$NAMESPACE" \
  --timeout=300s

echo "Verifying Argo CD workloads..."

kubectl get deployments,statefulsets \
  -n "$NAMESPACE"

echo "Argo CD v${VERSION} installed successfully."
