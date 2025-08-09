#!/usr/bin/env bash

# ----- Ultra debug prompt, safe under `set -u` -----
export PS4='[${BASH_SOURCE[0]:-?}:${LINENO} ${FUNCNAME[0]:-main}] '
set -Eeuo pipefail
set -x

# Error trap for postmortem dump
on_error() {
  local ec=$?
  echo ""
  echo "💥 Error trapped in ${BASH_SOURCE[0]} at line ${BASH_LINENO[0]} (exit=$ec)"
  echo "📂 scan-results/trivy-images (if any):"
  ls -lah scan-results/trivy-images 2>/dev/null || true
  echo "🧪 Dump first 120 lines of any error logs:"
  shopt -s nullglob
  for f in scan-results/trivy-images/error-*.log; do
    [[ -f "$f" ]] || continue
    echo "------ $f"
    sed -n '1,120p' "$f" || true
  done
  shopt -u nullglob
  exit "$ec"
}
trap on_error ERR

# ----- Config -----
export TRIVY_DEBUG=true
OVERLAY="${1:-dev}"
OVERLAY_DIR="infrastructure/k8s/overlays/${OVERLAY}"
TRIVY_BIN="$(command -v trivy || true)"
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-/tmp/trivy-cache}"

# Ensure dependencies exist
command -v yq >/dev/null
command -v jq >/dev/null
command -v kustomize >/dev/null

# Ensure writable cache
mkdir -p "$TRIVY_CACHE_DIR"
chmod 777 "$TRIVY_CACHE_DIR" || true

# Context echo
echo "📦 Overlay context: $OVERLAY"
echo "🔍 Trivy version: $($TRIVY_BIN --version | head -1)"
echo "🔍 yq version: $(yq --version)"
echo "🔍 jq version: $(jq --version)"
echo "📁 Trivy cache dir: $TRIVY_CACHE_DIR"
echo "📄 Overlay YAML files count: $(ls -1 "$OVERLAY_DIR"/*.yaml | wc -l)"
ls -1 "$OVERLAY_DIR"/*.yaml

# Prepare output dirs
mkdir -p scan-results/trivy-images
mkdir -p scan-results/trivy-configs

image_report="scan-results/image-scan-report-${OVERLAY}.txt"
vuln_report="scan-results/vulnerability-details-${OVERLAY}.txt"
config_report="scan-results/trivy-config-${OVERLAY}.txt"
manifest_file="scan-results/manifest-${OVERLAY}.yaml"

echo "Image Scan Report (${OVERLAY}) - $(date)" > "$image_report"
echo "Vulnerable Images:" > "$vuln_report"

total_images=0
scanned_images=0
vulnerable_images=0
scan_failed=0
approved_vulnerabilities=()

# Build manifest
echo "🛠 Building manifest via Kustomize..."
if ! kustomize build "$OVERLAY_DIR" > "$manifest_file"; then
  echo "❌ Kustomize build failed for overlay: $OVERLAY"
  exit 4
fi

# Extract container images
echo "🔍 Extracting container images from rendered manifest..."
images="$(yq eval -r '.. | .image? | select(.)' "$manifest_file" | sort -u || true)"

if [[ -z "$images" ]]; then
  echo "ℹ️ Primary traversal empty; trying explicit container paths..."
  images="$(yq eval -r '.spec.template.spec.containers[].image? // "" | select(.)' "$manifest_file" 2>/dev/null || true)"
  init_images="$(yq eval -r '.spec.template.spec.initContainers[].image? // "" | select(.)' "$manifest_file" 2>/dev/null || true)"
  images="$(printf '%s\n%s\n' "$images" "$init_images" | sed '/^$/d' | sort -u || true)"
fi

echo "🧾 Parsed image list:"
printf '%s\n' "$images"

if [[ -z "$images" ]]; then
  echo "⚠️ No container images found — check overlay/base manifests or yq query syntax"
  exit 3
fi

# ----- Scan loop -----
while IFS= read -r image; do
  (( total_images += 1 ))
  echo "🚀 Scanning image: $image"

  if [[ -z "$image" ]]; then
    echo "⚠️ Empty image entry, skipping"
    continue
  fi

  safe_name="$(echo "$image" | tr '/:' '__')"
  scan_json="scan-results/trivy-images/image-${OVERLAY}-${safe_name}.json"
  error_log="scan-results/trivy-images/error-${safe_name}.log"

  echo "🔧 Trivy command:"
  echo "$TRIVY_BIN image \"$image\" --debug --severity HIGH,CRITICAL --no-progress --cache-dir \"$TRIVY_CACHE_DIR\" -f json -o \"$scan_json\""

  {
    "$TRIVY_BIN" image "$image" \
      --debug \
      --severity HIGH,CRITICAL \
      --no-progress \
      --cache-dir "$TRIVY_CACHE_DIR" \
      -f json -o "$scan_json"
  } 2>"$error_log" || {
    echo "❌ Trivy scan failed for $image"
    echo "⚠️ stderr from Trivy:"
    sed -n '1,200p' "$error_log" || true
    echo "🚫 JSON output status:"
    ls -lh "$scan_json" || echo "❌ JSON not generated"
    (( scan_failed += 1 ))
    continue
  }

  (( scanned_images += 1 ))
  echo "📄 Trivy scan output (preview):"
  head -20 "$scan_json" || true

  # Parse vulnerabilities
  if jq -e '.Results[]? | select(.Vulnerabilities != null) | .Vulnerabilities | length > 0' "$scan_json" >/dev/null; then
    while IFS= read -r vuln; do
      vuln_id="$(jq -r '.VulnerabilityID' <<< "$vuln")"
      if [[ " ${approved_vulnerabilities[*]-} " == *" ${vuln_id} "* ]]; then
        echo "⚠️ Approved vulnerability: $vuln_id in $image"
      else
        echo "❌ Critical vulnerability: $vuln_id in $image"
        {
          echo "Image: $image"
          jq -r <<< "$vuln" '. | "  - \(.VulnerabilityID): \(.Title) (Severity: \(.Severity), Fixed: \(.FixedVersion // "n/a"))"'
          echo ""
        } >> "$vuln_report"
        (( vulnerable_images += 1 ))
        (( scan_failed += 1 ))
      fi
    done < <(jq -c '.Results[]? | select(.Vulnerabilities != null) | .Vulnerabilities[]' "$scan_json")
  else
    echo "✅ No critical vulnerabilities found in $image"
  fi
done <<< "$images"

# Config scan
echo "🔎 Running Trivy config scan..."
if ! "$TRIVY_BIN" config --debug "$manifest_file" | tee "$config_report"; then
  echo "❌ Trivy config scan failed"
  exit 5
fi

echo "📜 Trivy config scan (preview):"
sed -n '1,60p' "$config_report" || true

# Summary
{
  echo ""
  echo "=== Image Scan Summary (${OVERLAY}) ==="
  echo "Images found: $total_images"
  echo "Images scanned: $scanned_images"
  echo "Vulnerable images: $vulnerable_images"
} >> "$image_report"

if (( scanned_images == 0 )); then
  echo "⚠️ No images were scanned — check overlay or YAMLs"
  exit 2
fi

##exit if vulnerabilites are found
#if (( scan_failed > 0 )); then
#  echo "❌ One or more scans failed or critical vulnerabilities found"
#  exit 1
#fi

#allow to continue if vulnerabilites are found, but log and flag them
if (( scan_failed > 0 )); then
  echo '❌ One or more scans failed or critical vulnerabilities found'
  echo '⚠️ Continuing for artifact upload and PR summary'
  touch scan-failed-${OVERLAY}
fi


echo "✅ Scanning complete for overlay: $OVERLAY"

