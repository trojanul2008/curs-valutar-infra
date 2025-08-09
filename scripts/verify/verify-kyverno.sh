#!/bin/bash
set -euo pipefail

COMPONENTS=(
  kyverno-admission-controller
  kyverno-background-controller
  kyverno-cleanup-controller
  kyverno-reports-controller
)

echo "🧪 Verifying Kyverno rollout in namespace: kyverno"
SUCCESS=(); TIMEOUT=(); NOT_FOUND=()

for DEPLOY in "${COMPONENTS[@]}"; do
  echo "🔍 Checking $DEPLOY..."
  if ! kubectl get deployment "$DEPLOY" -n kyverno &>/dev/null; then
    echo "❌ '$DEPLOY' not found"
    NOT_FOUND+=("$DEPLOY")
    continue
  fi
  if kubectl rollout status deployment/"$DEPLOY" -n kyverno --timeout=180s; then
    echo "✅ '$DEPLOY' healthy"
    SUCCESS+=("$DEPLOY")
  else
    echo "⚠️ '$DEPLOY' timed out"
    TIMEOUT+=("$DEPLOY")
  fi
done

if (( ${#TIMEOUT[@]} > 0 || ${#NOT_FOUND[@]} > 0 )); then
  echo "❌ Kyverno verification failed"
  exit 1
else
  echo "✅ All Kyverno components healthy"
fi
