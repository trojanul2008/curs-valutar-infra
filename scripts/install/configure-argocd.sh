#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Argo CD..."

echo "Checking prerequisites..."

if ! kubectl get namespace argocd >/dev/null 2>&1; then
  echo "ERROR: Argo CD namespace does not exist."
  echo "Run scripts/install/install-argocd.sh first."
  exit 1
fi

if ! kubectl get configmap argocd-cm -n argocd >/dev/null 2>&1; then
  echo "ERROR: Argo CD installation is incomplete: argocd-cm is missing."
  exit 1
fi

if ! kubectl get service traefik -n traefik >/dev/null 2>&1; then
  echo "ERROR: Traefik service traefik/traefik is missing."
  exit 1
fi

if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  echo "ERROR: cert-manager CRDs are missing."
  echo "Run scripts/install/install-cert-manager.sh first."
  exit 1
fi

if ! kubectl get secret cloudflare-api-token \
  -n argocd \
  -o jsonpath='{.data.api-token}' \
  2>/dev/null \
  | grep -q .; then

  echo "ERROR: argocd/cloudflare-api-token is missing the api-token key."
  exit 1
fi

if ! kubectl get secret argocd-secret \
  -n argocd \
  -o jsonpath='{.data.webhook\.github\.secret}' \
  2>/dev/null \
  | grep -q .; then

  echo "ERROR: argocd-secret is missing webhook.github.secret."
  echo "Restore the GitHub webhook HMAC secret before continuing."
  exit 1
fi

echo "Prerequisites are satisfied."

echo "Configuring Traefik private LAN endpoint..."

kubectl patch svc traefik \
  -n traefik \
  --type merge \
  --patch-file infrastructure/argocd/networking/traefik-private-ip-patch.yaml

echo "Applying Argo CD Ingress health customization..."

kubectl patch configmap argocd-cm \
  -n argocd \
  --type merge \
  --patch-file infrastructure/argocd/argocd-cm-ingress-health-patch.yaml

echo "Applying private Argo CD route..."

kubectl apply \
  -f infrastructure/argocd/networking/argocd-private-route.yaml

echo "Applying public Argo CD GitHub webhook route..."

kubectl apply \
  -f infrastructure/argocd/networking/argocd-webhook-route.yaml

echo "Applying Argo CD applications..."

kubectl apply \
  -f infrastructure/argocd/applications/curs-valutar-dev.yaml

kubectl apply \
  -f infrastructure/argocd/applications/curs-valutar-prod.yaml

echo "Applying Argo CD TLS certificate configuration..."

kubectl apply \
  -f infrastructure/argocd/certificates/argocd-certificate.yaml

echo "Argo CD configuration applied successfully."
