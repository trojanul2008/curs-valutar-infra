#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🚀 Master Tool Installer
#     - Delegates to each individual install.sh
#     - Centralized trigger for all CLI setup
# --------------------------------------------------

TOOLS=(
  kubectl
  flux
  helm
  kustomize
  kubeconform
  kyverno
  yq
  trivy
)

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for TOOL in "${TOOLS[@]}"; do
  echo "🔧 Installing ${TOOL}..."
  INSTALLER="${BASE_DIR}/${TOOL}/install.sh"
  if [[ -f "$INSTALLER" ]]; then
    bash "$INSTALLER"
  else
    echo "⚠️ Installer for '${TOOL}' not found at ${INSTALLER}" >&2
  fi
done

echo "✅ All tools installed via modular install.sh scripts!"

