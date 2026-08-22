#!/bin/bash
set -e

echo "Configuring Argo CD..."

kubectl get namespace argocd >/dev/null
kubectl get configmap argocd-cm -n argocd >/dev/null

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

echo "Checking cert-manager and Cloudflare credential..."

kubectl get crd certificates.cert-manager.io >/dev/null

if ! kubectl get secret cloudflare-api-token -n argocd >/dev/null 2>&1; then
  echo "ERROR: Secret argocd/cloudflare-api-token is missing."
  echo "Create it before configuring the Argo CD certificate."
  exit 1
fi

echo "Applying Argo CD TLS certificate configuration..."

kubectl apply \
  -f infrastructure/argocd/certificates/argocd-certificate.yaml

echo "Argo CD configuration applied successfully."
