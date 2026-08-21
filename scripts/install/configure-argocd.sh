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

echo "Applying Argo CD applications..."

kubectl apply \
  -f infrastructure/argocd/applications/curs-valutar-dev.yaml

echo "Argo CD configuration applied successfully."
