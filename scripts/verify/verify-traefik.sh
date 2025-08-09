#!/bin/bash
set -euo pipefail

NAMESPACE="traefik"
DEPLOY="traefik"

echo "🧪 Verifying Traefik rollout in namespace: ${NAMESPACE}"

echo "🔍 Deployment status..."
kubectl rollout status deployment/${DEPLOY} -n ${NAMESPACE} --timeout=180s

TYPE=$(kubectl get svc ${DEPLOY} -n ${NAMESPACE} -o jsonpath='{.spec.type}')
echo "🔍 Service type: ${TYPE}"

if [[ "$TYPE" == "LoadBalancer" ]]; then
  LB_IP=$(kubectl get svc ${DEPLOY} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "🌐 External IP: ${LB_IP:-none}"
else
  NODEPORTS=$(kubectl get svc ${DEPLOY} -n ${NAMESPACE} -o jsonpath='{.spec.ports[*].nodePort}')
  echo "🌐 NodePorts: ${NODEPORTS}"
fi

EP_COUNT=$(kubectl get endpoints ${DEPLOY} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
if [[ "$EP_COUNT" -eq 0 ]]; then
  echo "❌ No endpoints behind service/${DEPLOY}"
  exit 1
fi

echo "✅ Traefik is healthy"
