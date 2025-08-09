#!/bin/bash
set -euo pipefail

NAMESPACE="flux-system"

KS_LIST=$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)
if [[ -z "$KS_LIST" ]]; then
  echo "❌ No Kustomizations found in flux-system"
  exit 1
fi

NOT_READY=()
for KS in $KS_LIST; do
  echo "⏳ Waiting for Kustomization/$KS..."
  if ! kubectl wait --for=condition=Ready --timeout=300s kustomization/$KS -n $NAMESPACE; then
    NOT_READY+=("$KS")
  fi
done

if (( ${#NOT_READY[@]} > 0 )); then
  echo "❌ Unhealthy Kustomizations: ${NOT_READY[*]}"
  exit 1
else
  echo "✅ All Kustomizations in '$NAMESPACE' are Ready"
fi
