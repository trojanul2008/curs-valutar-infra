# scripts/utils/validate-version-keys.sh
#!/bin/bash
set -euo pipefail

VERSIONS_FILE=".github/versions.yaml"
# Accept either single or pairs
REQUIRED_SETS=(
  "helm"
  "kubectl"
  "kustomize"
  "yq"
  "trivy"
  "kubeconform"
  "flux"
  "kyverno,kyvernoApp"       # accept 'kyverno' or 'kyvernoApp'
  "traefik,traefikApp"       # accept 'traefik' or 'traefikApp'
)

echo "🔎 Validating $VERSIONS_FILE…"
[[ -f "$VERSIONS_FILE" ]] || { echo "❌ Missing $VERSIONS_FILE"; exit 1; }

missing=0; badfmt=0

has_key() { yq -e "has(\"$1\")" "$VERSIONS_FILE" >/dev/null; }

for set in "${REQUIRED_SETS[@]}"; do
  IFS=',' read -r k1 k2 <<< "$set"
  if [[ -n "${k2:-}" ]]; then
    if ! has_key "$k1" && ! has_key "$k2"; then
      echo "❌ Missing key: $k1 (or $k2)"
      missing=$((missing+1))
      continue
    fi
    key_present="$k1"; has_key "$k1" || key_present="$k2"
  else
    if ! has_key "$k1"; then
      echo "❌ Missing key: $k1"
      missing=$((missing+1))
      continue
    fi
    key_present="$k1"
  fi
  val=$(yq -r ".${key_present}" "$VERSIONS_FILE")
  if [[ ! "$val" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "⚠️  $key_present has non-standard version: '$val' (expected x.y.z)"
    badfmt=$((badfmt+1))
  fi
done

(( missing > 0 )) && { echo "🚨 Missing $missing required key(s)."; exit 1; }
(( badfmt > 0 )) && echo "⚠️ $badfmt version(s) with non-standard format — consider normalizing."
echo "✅ versions.yaml looks good"
