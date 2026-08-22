#!/usr/bin/env bash
set -euo pipefail

readonly CLOUDFLARED_VERSION="2026.5.1"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly INSTALL_PATH="${INSTALL_DIR}/cloudflared"

case "$(uname -m)" in
  x86_64)
    ASSET="cloudflared-linux-amd64"
    SHA256="3c6a5ba995a258dbe90f98e5fdb2c2620b7be72c3ca761614f6eb52aee252cea"
    ;;
  aarch64|arm64)
    ASSET="cloudflared-linux-arm64"
    SHA256="7b7a8b9a2764acab0fecda633cb54a6c0df42d7f8ca1ec45c78333c2227d8d91"
    ;;
  *)
    echo "ERROR: Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

URL="https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/${ASSET}"
TMP_FILE="$(mktemp)"

cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

mkdir -p "$INSTALL_DIR"

echo "Installing cloudflared ${CLOUDFLARED_VERSION} for $(uname -m)."

curl \
  --fail \
  --location \
  --silent \
  --show-error \
  --retry 3 \
  "$URL" \
  --output "$TMP_FILE"

printf '%s  %s\n' "$SHA256" "$TMP_FILE" \
  | sha256sum --check --status

install \
  --mode 0755 \
  "$TMP_FILE" \
  "$INSTALL_PATH"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

"$INSTALL_PATH" --version
