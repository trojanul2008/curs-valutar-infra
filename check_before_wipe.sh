#!/usr/bin/env bash
set -euo pipefail

# Define k3s defaults
DEFAULT_NAMESPACES=(default kube-system kube-public kube-node-lease local-path-storage)
DEFAULT_CLUSTERROLES=(cluster-admin admin edit view)
DEFAULT_STORAGECLASS="local-path-storage"

echo
echo "=== Namespaces (non-default) ==="
kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -v -x -F "${DEFAULT_NAMESPACES[@]}" || true

echo
echo "=== CustomResourceDefinitions ==="
kubectl get crd -o name

echo
echo "=== ClusterRoles (non-default) ==="
kubectl get clusterrole -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -v -x -F "${DEFAULT_CLUSTERROLES[@]}" || true

echo
echo "=== ClusterRoleBindings (all) ==="
kubectl get clusterrolebinding -o name

echo
echo "=== MutatingWebhookConfigurations ==="
kubectl get mutatingwebhookconfiguration -o name

echo
echo "=== ValidatingWebhookConfigurations ==="
kubectl get validatingwebhookconfiguration -o name

echo
echo "=== APIService Definitions ==="
kubectl get apiservice -o name

echo
echo "=== StorageClasses (non-default) ==="
kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -v -x "${DEFAULT_STORAGECLASS}" || true

echo
echo "=== PersistentVolumes ==="
kubectl get pv -o name

echo
echo "=== Summary ==="
echo "- Review the above output for any Flux, Kyverno, Cert-Manager, Vault, or other CRDs"
echo "- Note any cluster-scoped Roles, Bindings, Webhooks or StorageClasses you rely on"
echo "- Incorporate them into your GitOps bootstrap before running the wipe job"

