#!/usr/bin/env bash
set -euo pipefail

source scripts/utils/load-version.sh

echo "Installing pinned CI validation tools..."

scripts/install/install-kustomize.sh
scripts/install/install-yq.sh
scripts/install/install-trivy.sh
scripts/install/install-kubeconform.sh
scripts/install/install-kyverno-cli.sh

CHECKOV_VERSION="$(get_version checkov)"
YAMLLINT_VERSION="$(get_version yamllint)"

VENV="$HOME/.cache/curs-valutar-ci-venv"

python3 -m venv "$VENV"

"$VENV/bin/python" -m pip install \
  --disable-pip-version-check \
  --upgrade pip

"$VENV/bin/python" -m pip install \
  "checkov==${CHECKOV_VERSION}" \
  "yamllint==${YAMLLINT_VERSION}"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$VENV/bin" >> "$GITHUB_PATH"
fi

echo "Installed Python CI tools:"
"$VENV/bin/checkov" --version
"$VENV/bin/yamllint" --version

echo "CI tool installation complete."
