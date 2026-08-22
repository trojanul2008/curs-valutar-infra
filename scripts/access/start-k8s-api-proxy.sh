#!/usr/bin/env bash
set -euo pipefail

readonly ACCESS_HOSTNAME="${K8S_API_ACCESS_HOSTNAME:-k8s-api.istartit.com}"
readonly LISTEN_HOST="127.0.0.1"
readonly LISTEN_PORT="6443"
readonly LISTEN_ADDRESS="${LISTEN_HOST}:${LISTEN_PORT}"
readonly EXPECTED_API_SERVER="https://${LISTEN_ADDRESS}"
readonly KUBE_CONTEXT="${KUBE_CONTEXT:-remote-cloudflare}"
readonly CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-${HOME}/.local/bin/cloudflared}"
readonly STATE_DIR="${RUNNER_TEMP:-/tmp}"
readonly PID_FILE="${STATE_DIR}/cloudflared-k8s-api.pid"
readonly LOG_FILE="${STATE_DIR}/cloudflared-k8s-api.log"
readonly KUBECTL_ERROR_FILE="${STATE_DIR}/k8s-api-kubectl-error.log"

for required_var in \
  TUNNEL_SERVICE_TOKEN_ID \
  TUNNEL_SERVICE_TOKEN_SECRET
do
  if [[ -z "${!required_var:-}" ]]; then
    echo "ERROR: Required Cloudflare Access credential is not configured: ${required_var}"
    exit 1
  fi
done

if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
  echo "ERROR: cloudflared is not available at ${CLOUDFLARED_BIN}"
  exit 1
fi

if [[ ! -f "${HOME}/.kube/config" ]]; then
  echo "ERROR: Kubernetes kubeconfig is missing."
  exit 1
fi

if ! CONFIGURED_API_SERVER="$(
  kubectl \
    config view \
    --context="$KUBE_CONTEXT" \
    --minify \
    -o jsonpath='{.clusters[0].cluster.server}' \
    2>/dev/null
)"; then
  echo "ERROR: Kubernetes context does not exist or cannot be read: ${KUBE_CONTEXT}"
  exit 1
fi

if [[ "$CONFIGURED_API_SERVER" != "$EXPECTED_API_SERVER" ]]; then
  echo "ERROR: Kubernetes API server does not match the local Cloudflare proxy."
  echo "Expected: ${EXPECTED_API_SERVER}"
  echo "Configured: ${CONFIGURED_API_SERVER:-unknown}"
  exit 1
fi

listener_is_open() {
  timeout 1 \
    bash -c ": </dev/tcp/${LISTEN_HOST}/${LISTEN_PORT}" \
    2>/dev/null
}

if listener_is_open; then
  echo "ERROR: Local port ${LISTEN_ADDRESS} is already in use."
  exit 1
fi

rm -f \
  "$PID_FILE" \
  "$LOG_FILE" \
  "$KUBECTL_ERROR_FILE"

echo "Starting Cloudflare Access proxy for ${ACCESS_HOSTNAME}."

nohup "$CLOUDFLARED_BIN" access tcp \
  --hostname "$ACCESS_HOSTNAME" \
  --url "$LISTEN_ADDRESS" \
  > "$LOG_FILE" 2>&1 &

CLOUDFLARED_PID=$!
printf '%s\n' "$CLOUDFLARED_PID" > "$PID_FILE"

LISTENER_READY=false

for _ in $(seq 1 30); do
  if ! kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
    echo "ERROR: cloudflared exited before the local proxy became ready."
    sed -n '1,80p' "$LOG_FILE"
    exit 1
  fi

  if listener_is_open; then
    LISTENER_READY=true
    break
  fi

  sleep 1
done

if [[ "$LISTENER_READY" != "true" ]]; then
  echo "ERROR: Cloudflare Access proxy did not listen on ${LISTEN_ADDRESS}."
  sed -n '1,80p' "$LOG_FILE"
  exit 1
fi

echo "Cloudflare Access proxy is listening on ${LISTEN_ADDRESS}."

for _ in $(seq 1 10); do
  if kubectl \
    --context="$KUBE_CONTEXT" \
    get --raw=/version \
    >/dev/null 2>"$KUBECTL_ERROR_FILE"
  then
    echo "Kubernetes API is reachable through Cloudflare Access."
    exit 0
  fi

  sleep 1
done

echo "ERROR: Local Cloudflare proxy is listening, but Kubernetes API verification failed."

API_SERVER="$(
  kubectl \
    config view \
    --context="$KUBE_CONTEXT" \
    --minify \
    -o jsonpath='{.clusters[0].cluster.server}' \
    2>/dev/null || true
)"

echo "Configured Kubernetes API server: ${API_SERVER:-unknown}"

echo "kubectl diagnostic:"
sed -n '1,40p' "$KUBECTL_ERROR_FILE"

echo "cloudflared diagnostic:"
sed -n '1,80p' "$LOG_FILE"

exit 1
