#!/usr/bin/env bash
set -euo pipefail

# If TARGET_CONTEXT is set, use it; otherwise prompt interactively.
if [ -n "${TARGET_CONTEXT-}" ]; then
  CONTEXT="$TARGET_CONTEXT"
else
  echo "🔎 Available contexts:"
  kubectl config get-contexts
  read -erp "👉 Enter the CONTEXT you want to wipe: " CONTEXT
fi

echo "Switching to context: $CONTEXT"
kubectl config use-context "$CONTEXT"
echo "✅ Current context: $(kubectl config current-context)"

# 1) Uninstall Flux v2
echo "⏳ Uninstalling Flux controllers..."
# --watch=false makes uninstall non-blocking in some versions
flux uninstall --namespace flux-system --watch=false || true
kubectl delete ns flux-system --ignore-not-found

# 2) Remove Kyverno
echo "⏳ Removing Kyverno..."
kubectl delete -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/release/install.yaml --ignore-not-found || true
kubectl delete ns kyverno --ignore-not-found

# 3) Remove External-Secrets
echo "⏳ Removing External-Secrets HelmRelease & CRDs..."
helm uninstall external-secrets --namespace flux-system --ignore-not-found || true
kubectl delete ns flux-system --ignore-not-found
kubectl delete crd externalsecrets.external-secrets.io \
                  clustersecretstores.external-secrets.io \
                  externalsecretstores.external-secrets.io \
  --ignore-not-found || true

# 4) Prune leftover Flux GitOps CRs
echo "⏳ Deleting leftover GitOps custom resources..."
kubectl delete gitrepositories.source.toolkit.fluxcd.io \
                 kustomizations.kustomize.toolkit.fluxcd.io \
                 helmrepositories.source.toolkit.fluxcd.io \
                 imagepolicies.image.toolkit.fluxcd.io \
                 imageupdateautomations.image.toolkit.fluxcd.io \
  --all-namespaces --ignore-not-found || true

# 5) (Optional) Delete non-system namespaces
echo "⏳ Deleting non-system namespaces..."
kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -Ev '^(default|kube-system|kube-public)$' \
  | xargs -r kubectl delete ns --ignore-not-found

# 6) Final status
echo "🔍 Cluster resources now:"
kubectl get all --all-namespaces || true
echo "🔍 Remaining CRDs (flux/kyverno/external):"
kubectl get crd | grep -E 'flux|kyverno|external' || echo "  (none found)"
echo "🎉 Cluster wipe complete."

