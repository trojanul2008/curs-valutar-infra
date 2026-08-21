#!/bin/bash
set -e

echo "Configuring Argo CD..."

kubectl get namespace argocd >/dev/null
kubectl get configmap argocd-cm -n argocd >/dev/null

echo "Applying Argo CD Ingress health customization..."

kubectl patch configmap argocd-cm \
  -n argocd \
  --type merge \
  --patch-file infrastructure/argocd/argocd-cm-ingress-health-patch.yaml

echo "Applying Argo CD applications..."

kubectl apply \
  -f infrastructure/argocd/applications/curs-valutar-dev.yaml

echo "Argo CD configuration applied successfully."
