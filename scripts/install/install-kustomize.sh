#!/bin/bash
set -e
source ./scripts/utils/load-version.sh

VERSION=$(get_version kustomize) # e.g., 5.7.1
BIN="kustomize_v${VERSION}_linux_amd64.tar.gz"
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${VERSION}/${BIN}"

curl -fsSLO "$URL"
tar -xzf "${BIN}" kustomize
chmod +x kustomize
sudo mv kustomize /usr/local/bin/kustomize
rm -f "${BIN}"
echo "✅ Kustomize $(kustomize version) installed"

