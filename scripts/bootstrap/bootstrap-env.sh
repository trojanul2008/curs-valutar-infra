#!/usr/bin/env bash
set -euo pipefail

ENV="${1:?env}"
CTX="${2:?context}"
BRANCH="${3:?branch}"
PATH_ARG="${4:?path}"

OUTDIR="artifacts/bootstrap/${ENV}"
mkdir -p "$OUTDIR"

log() { echo "[$ENV/$CTX] $*"; }

log "🔧 Creating namespaces"
kubectl --context="$CTX" create ns "$ENV" 2>/dev/null || true
kubectl --context="$CTX" create ns flux-system 2>/dev/null || true

log "🛡️ Kyverno"
kubectl config use-context "$CTX" >/dev/null
START=$(date +%s)
./scripts/install/install-kyverno.sh
END=$(date +%s)
log "⏱️ Kyverno duration: $((END - START))s"

log "🌐 Traefik"
START=$(date +%s)
./scripts/install/install-traefik.sh
END=$(date +%s)
log "⏱️ Traefik duration: $((END - START))s"

log "⚡ Flux bootstrap"
if kubectl --context="$CTX" get ns flux-system &>/dev/null && \
   kubectl --context="$CTX" -n flux-system get secret flux-system &>/dev/null; then
  log "Flux appears installed; reconciling"
else
  flux bootstrap github \
    --context="$CTX" \
    --owner="$OWNER" --repository="$REPO" \
    --branch="$BRANCH" --path="$PATH_ARG" \
    --personal --token-auth --log-level=debug
fi

flux reconcile source git flux-system --context="$CTX" || true
flux reconcile kustomization flux-system --context="$CTX" || true

log "📸 Snapshots"
kubectl --context="$CTX" get deployments -A -o wide > "$OUTDIR/deployments.txt" || true
kubectl --context="$CTX" get pods -A --field-selector=status.phase!=Running -o wide > "$OUTDIR/pods.txt" || true
kubectl --context="$CTX" get events -A --sort-by=.lastTimestamp | tail -n 200 > "$OUTDIR/events.txt" || true

log "🧠 Summary"
{
  echo "ENV: $ENV"
  echo "CTX: $CTX"
  echo "BRANCH: $BRANCH"
  echo "PATH: $PATH_ARG"
  echo "Deployments: $(kubectl --context="$CTX" get deployments -A --no-headers 2>/dev/null | wc -l || echo 0)"
  echo "Pending pods: $(kubectl --context="$CTX" get pods -A --no-headers 2>/dev/null | grep -c 'Pending' || echo 0)"
  echo "Nodes: $(kubectl --context="$CTX" get nodes --no-headers 2>/dev/null | wc -l || echo 0)"
  echo "Quotas: $(kubectl --context="$CTX" get resourcequota -A --no-headers 2>/dev/null | wc -l || echo 0)"
} > "$OUTDIR/summary.txt"

