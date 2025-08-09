#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${1:-true}"

do_or_echo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

echo "=== Cluster-scoped cleanup (dry-run=$DRY_RUN) ==="

# 1) CRDs (skip k3s-managed)
ALL_CRDS="$(kubectl get crd -o name || true)"
TO_DELETE_CRDS="$(echo "$ALL_CRDS" | grep -v 'k3s.cattle.io' || true)"
while read -r crd; do
  [[ -z "$crd" ]] && continue
  echo "Deleting CRD: $crd"
  do_or_echo kubectl delete "$crd" --ignore-not-found --timeout=60s
done <<< "$TO_DELETE_CRDS"

# 2) Webhooks
for w in mutatingwebhookconfiguration validatingwebhookconfiguration; do
  echo "Deleting all $w"
  do_or_echo kubectl delete "$w" --all --ignore-not-found --timeout=30s
done

# 3) APIService (selected)
APISVCS="$(kubectl get apiservice -o name | grep -E '(helm|traefik|kyverno)' || true)"
while read -r svc; do
  [[ -z "$svc" ]] && continue
  echo "Deleting APIService: $svc"
  do_or_echo kubectl delete "$svc" --ignore-not-found --timeout=30s
done <<< "$APISVCS"

# 4) PersistentVolumes
echo "Deleting all PersistentVolumes"
do_or_echo kubectl delete pv --all --ignore-not-found --timeout=30s

# 5) StorageClasses (keep local-path-storage)
ALL_SCS="$(kubectl get storageclass -o name || true)"
TO_DELETE_SCS="$(echo "$ALL_SCS" | grep -v 'local-path-storage' || true)"
while read -r sc; do
  [[ -z "$sc" ]] && continue
  echo "Deleting StorageClass: $sc"
  do_or_echo kubectl delete "$sc" --ignore-not-found --timeout=30s
done <<< "$TO_DELETE_SCS"

# 6) ClusterRoleBindings (keep core and k3s/system)
KEEP_CRB_RE='^(cluster-admin|k3s:.*|system:.*|cloudflare-user-.*|clustercidrs-node|local-path-provisioner-bind|metrics-server:system:auth-delegator|remote-admin-binding|teardown-admin)$'
for crb in $(kubectl get clusterrolebinding -o name || true); do
  name="${crb##*/}"
  if [[ "$name" =~ $KEEP_CRB_RE ]]; then
    echo "Keeping CRB: $crb"
  else
    echo "Deleting CRB: $crb"
    do_or_echo kubectl delete "$crb" --ignore-not-found --timeout=20s
  fi
done

# 7) RoleBindings (namespaced)
KEEP_RB_RE='^(default/github-runner-edit|remote-admin-binding|kube-system/metrics-server-auth-reader|kube-system/system:.*|kube-system/k3s:.*|kube-system/extension:.*)$'
kubectl get rolebinding -A \
  -o custom-columns="NS:.metadata.namespace,NAME:.metadata.name" --no-headers 2>/dev/null \
| while read -r ns name; do
    full="$ns/$name"
    if [[ "$full" =~ $KEEP_RB_RE ]]; then
      echo "Keeping RB: $full"
    else
      echo "Deleting RB: $full"
      do_or_echo kubectl -n "$ns" delete rolebinding "$name" --ignore-not-found --timeout=20s
    fi
  done

# 8) Roles (namespaced)
KEEP_ROLES_RE='^(kube-public/system:controller:bootstrap-signer|kube-system/(extension-apiserver-authentication-reader|system:.*|system::.*))$'
kubectl get role -A \
  -o custom-columns="NS:.metadata.namespace,NAME:.metadata.name" --no-headers 2>/dev/null \
| while read -r ns name; do
    full="$ns/$name"
    if [[ "$full" =~ $KEEP_ROLES_RE ]]; then
      echo "Keeping Role: $full"
    else
      echo "Deleting Role: $full"
      do_or_echo kubectl -n "$ns" delete role "$name" --ignore-not-found --timeout=20s
    fi
  done

echo "✅ Cluster-scoped cleanup complete."

