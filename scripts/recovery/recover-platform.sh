#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-precheck}"

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." &&
  pwd
)"

cd "$ROOT_DIR"

KUBE_CONTEXT="${KUBE_CONTEXT:-remote-cloudflare}"
EXPECTED_NODE="${EXPECTED_NODE:-raspberrypi}"

PATCH_FILE=""

trap 'rm -f "${PATCH_FILE:-}"' EXIT

log() {
  printf '[recovery] %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    fail "Required command is missing: $1"
}

require_environment_variable() {
  local name="$1"
  local value="${!name-}"

  [[ -n "$value" ]] ||
    fail "Required recovery variable is missing: $name"
}

k() {
  kubectl --context "$KUBE_CONTEXT" "$@"
}

check_suspended_if_present() {
  local resource="$1"
  local name="$2"
  local suspended

  if ! k -n flux-system get "$resource" "$name" >/dev/null 2>&1; then
    return 0
  fi

  suspended="$(
    k -n flux-system \
      get "$resource" "$name" \
      -o jsonpath='{.spec.suspend}'
  )"

  if [[ "$suspended" != "true" ]]; then
    fail "Legacy Flux resource ${resource}/${name} exists and is not suspended."
  fi

  log "Legacy Flux resource ${resource}/${name} exists but is safely suspended."
}

verify_flux_ownership_boundary() {
  check_suspended_if_present \
    kustomization.kustomize.toolkit.fluxcd.io \
    curs-valutar-dev

  check_suspended_if_present \
    kustomization.kustomize.toolkit.fluxcd.io \
    curs-valutar-prod

  check_suspended_if_present \
    imageupdateautomation.image.toolkit.fluxcd.io \
    curs-valutar-dev-autoupdate

  check_suspended_if_present \
    imageupdateautomation.image.toolkit.fluxcd.io \
    curs-valutar-autoupdate
}

verify_safe_flux_composition() {
  local rendered

  rendered="$(mktemp)"

  kustomize build \
    infrastructure/flux/flux-system \
    > "$rendered"

  if grep -Eq 'curs-valutar|infra-dev' "$rendered"; then
    rm -f "$rendered"
    fail "Recovery Flux composition contains legacy curs-valutar ownership."
  fi

  rm -f "$rendered"

  log "Flux recovery composition contains no curs-valutar or infra-dev resources."
}

preflight() {
  log "Running recovery preflight checks."

  for command in \
    kubectl \
    helm \
    kustomize \
    curl \
    jq \
    base64
  do
    require_command "$command"
  done

  if ! kubectl config get-contexts "$KUBE_CONTEXT" >/dev/null 2>&1; then
    fail "Kubernetes context does not exist: $KUBE_CONTEXT"
  fi

  kubectl config use-context "$KUBE_CONTEXT" >/dev/null

  if ! k get node "$EXPECTED_NODE" >/dev/null 2>&1; then
    fail "Expected Kubernetes node is not reachable: $EXPECTED_NODE"
  fi

  log "Kubernetes node ${EXPECTED_NODE} is reachable."

  if k -n kube-system get deployment traefik >/dev/null 2>&1; then
    fail "K3s bundled Traefik deployment is active in kube-system."
  fi

  if k -n kube-system \
    get helmchart.helm.cattle.io traefik \
    >/dev/null 2>&1
  then
    fail "K3s Traefik HelmChart is active; recovery would create two ingress controllers."
  fi

  log "K3s bundled Traefik is not active."

  verify_safe_flux_composition
  verify_flux_ownership_boundary

  require_environment_variable ISTARTIT_GIT_USERNAME
  require_environment_variable ISTARTIT_GIT_PASSWORD
  require_environment_variable CLOUDFLARE_API_TOKEN
  require_environment_variable ARGO_GITHUB_WEBHOOK_SECRET

  log "Required recovery credentials are available."
  log "Preflight checks passed."
}

install_flux_platform() {
  log "Installing/reconciling Flux controllers."

  k apply \
    -f infrastructure/flux/flux-system/manifests/flux-controllers.yaml

  for deployment in \
    source-controller \
    kustomize-controller \
    helm-controller \
    notification-controller \
    image-reflector-controller \
    image-automation-controller
  do
    k -n flux-system rollout status \
      "deployment/${deployment}" \
      --timeout=300s
  done

  log "Flux controllers are ready."

  log "Installing/reconciling External Secrets through Flux."

  k apply \
    -f infrastructure/flux/flux-system/manifests/external-secrets-install.yaml

  k -n flux-system wait \
    --for=condition=ready \
    helmrepository/external-secrets \
    --timeout=180s

  k -n flux-system wait \
    --for=condition=ready \
    helmrelease/external-secrets \
    --timeout=300s

  k -n flux-system rollout status \
    deployment/external-secrets \
    --timeout=300s

  log "External Secrets is ready."
}

restore_istartit() {
  log "Restoring istartit Git authentication."

  k -n flux-system create secret generic istartit-flux-git \
    --from-literal=username="$ISTARTIT_GIT_USERNAME" \
    --from-literal=password="$ISTARTIT_GIT_PASSWORD" \
    --dry-run=client \
    -o yaml \
  | k apply -f -

  log "Applying istartit Flux bootstrap objects."

  k apply \
    -f infrastructure/flux/bootstrap/istartit.yaml

  k -n flux-system wait \
    --for=condition=ready \
    gitrepository/istartit \
    --timeout=180s

  k -n flux-system wait \
    --for=condition=ready \
    kustomization/istartit-platform \
    --timeout=300s

  k -n flux-system wait \
    --for=condition=ready \
    kustomization/istartit-app \
    --timeout=300s

  log "istartit Flux reconciliation is ready."
}

restore_argocd_secrets() {
  local webhook_secret_base64

  log "Restoring Argo CD Cloudflare credential."

  k -n argocd create secret generic cloudflare-api-token \
    --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
    --dry-run=client \
    -o yaml \
  | k apply -f -

  log "Restoring Argo CD GitHub webhook HMAC."

  PATCH_FILE="$(mktemp)"
  chmod 600 "$PATCH_FILE"

  webhook_secret_base64="$(
    printf '%s' "$ARGO_GITHUB_WEBHOOK_SECRET" \
      | base64 \
      | tr -d '\n'
  )"

  printf \
    '{"data":{"webhook.github.secret":"%s"}}\n' \
    "$webhook_secret_base64" \
    > "$PATCH_FILE"

  k -n argocd patch secret argocd-secret \
    --type merge \
    --patch-file "$PATCH_FILE"

  rm -f "$PATCH_FILE"
  PATCH_FILE=""

  log "Required Argo CD recovery secrets are restored."
}

wait_for_argocd_application() {
  local application="$1"
  local timeout_seconds="${2:-420}"
  local deadline
  local sync
  local health

  deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    sync="$(
      k -n argocd \
        get application "$application" \
        -o jsonpath='{.status.sync.status}' \
        2>/dev/null || true
    )"

    health="$(
      k -n argocd \
        get application "$application" \
        -o jsonpath='{.status.health.status}' \
        2>/dev/null || true
    )"

    log "${application}: sync=${sync:-unknown} health=${health:-unknown}"

    if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
      return 0
    fi

    sleep 5
  done

  k -n argocd get application "$application" || true

  fail "Argo CD application did not become Synced/Healthy: $application"
}

http_smoke_test() {
  local url="$1"

  log "HTTP smoke test: $url"

  curl \
    --fail \
    --silent \
    --show-error \
    --retry 8 \
    --retry-delay 3 \
    --max-time 20 \
    "$url" \
    >/dev/null

  log "HTTP smoke test passed: $url"
}

recover() {
  if [[ "${RECOVERY_CONFIRMATION:-}" != "RECOVER" ]]; then
    fail "Recovery mode requires RECOVERY_CONFIRMATION=RECOVER."
  fi

  log "Starting idempotent Kubernetes platform recovery."

  log "Installing/reconciling Traefik."
  ./scripts/install/install-traefik.sh

  log "Installing/reconciling Kyverno."
  ./scripts/install/install-kyverno.sh

  log "Installing/reconciling cert-manager."
  ./scripts/install/install-cert-manager.sh

  install_flux_platform
  restore_istartit

  log "Installing/reconciling Argo CD."
  ./scripts/install/install-argocd.sh

  restore_argocd_secrets

  log "Applying Argo CD platform configuration."
  ./scripts/install/configure-argocd.sh

  wait_for_argocd_application curs-valutar-dev
  wait_for_argocd_application curs-valutar-prod

  verify_flux_ownership_boundary

  http_smoke_test "https://istartit.com"
  http_smoke_test "https://di-exchange.istartit.com"
  http_smoke_test "https://exchange.istartit.com"

  echo
  log "Final Flux status:"
  k -n flux-system get \
    gitrepository/istartit \
    kustomization/istartit-platform \
    kustomization/istartit-app \
    helmrelease/external-secrets

  echo
  log "Final Argo CD status:"
  k -n argocd get applications

  log "Platform recovery completed successfully."
}

case "$MODE" in
  precheck)
    preflight
    ;;
  recover)
    preflight
    recover
    ;;
  *)
    fail "Unknown mode '$MODE'. Expected: precheck or recover."
    ;;
esac
