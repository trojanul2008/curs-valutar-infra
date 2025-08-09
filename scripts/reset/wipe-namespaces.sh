#!/usr/bin/env bash
set -euo pipefail

NS="${1:-dev}"
FULL="${2:-}"
DRY_RUN="${3:-true}"

do_or_echo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# Resolve target namespaces
TARGETS=()
case "$NS" in
  dev|prod) TARGETS+=("$NS");;
  both) TARGETS+=(dev prod);;
  *) echo "Invalid namespace arg: $NS (expected dev|prod|both)"; exit 1;;
esac

# Include platform namespaces when FULL
if [[ "$FULL" == "FULL" ]]; then
  TARGETS+=(flux-system kyverno traefik)
fi

echo "Deleting namespaces: ${TARGETS[*]} (dry-run=$DRY_RUN)"

for N in "${TARGETS[@]}"; do
  echo "=== Processing namespace: $N ==="
  do_or_echo kubectl delete ns "$N" --ignore-not-found --grace-period=0 --force --wait=false || true

  # Wait briefly for deletion to start
  for i in {1..30}; do
    sleep 2
    if ! kubectl get ns "$N" &>/dev/null; then
      echo "Namespace $N no longer exists."
      break
    fi
  done

  # Finalizer cleanup if still present
  if kubectl get ns "$N" &>/dev/null; then
    echo "Attempting finalizers cleanup for $N"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY-RUN: kubectl get ns $N -o json | jq 'del(.spec.finalizers)' | kubectl replace --raw /api/v1/namespaces/$N/finalize -f -"
    else
      kubectl get ns "$N" -o json \
        | jq 'del(.spec.finalizers)' \
        | kubectl replace --raw "/api/v1/namespaces/$N/finalize" -f - || true
    fi
  fi
done

echo "✅ Namespace wipe complete."

