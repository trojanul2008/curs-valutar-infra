#!/usr/bin/env bash
set -euo pipefail

# Usage: finalizer-cleanup.sh <apiVersion> <kind> <name> [namespace] [dry-run]
APIV="$1"
KIND="$2"
NAME="$3"
NS="${4:-}"
DRY_RUN="${5:-true}"

NSARG=()
[[ -n "$NS" ]] && NSARG=(-n "$NS")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: kubectl get $KIND $NAME -o json ${NSARG[*]} | jq 'del(.metadata.finalizers)' | kubectl apply -f -"
  exit 0
fi

RAW="$(kubectl get "$KIND" "$NAME" -o json "${NSARG[@]}" 2>/dev/null || true)"
if [[ -z "$RAW" ]]; then
  echo "Resource $KIND/$NAME not found (namespace='$NS')"
  exit 0
fi

echo "$RAW" | jq 'del(.metadata.finalizers)' | kubectl apply -f - || true

