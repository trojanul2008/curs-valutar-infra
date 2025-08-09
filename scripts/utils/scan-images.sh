#!/usr/bin/env bash
export PS4='[$BASH_SOURCE:$LINENO ${FUNCNAME[0]}()] '
set -euxo pipefail

# ✅ Enable Trivy internal debugging
export TRIVY_DEBUG=true

OVERLAY="${1:-dev}"
OVERLAY_DIR="infrastructure/k8s/overlays/${OVERLAY}"
TRIVY_BIN="$(command -v trivy || true)"
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-/tmp/trivy-cache}"

if [[ -z "$TRIVY_BIN" ]]; then
  echo "❌ Trivy binary not found in PATH"
  exit 1
fi

echo "📦 Overlay context: $OVERLAY"
echo "🔍 Trivy version: $($TRIVY_BIN --version | head -1)"
echo "🔍 yq version: $(yq --version)"
echo "📁 Cache dir: $TRIVY_CACHE_DIR"
echo "📄 Overlay YAML files count: $(ls -1 "$OVERLAY_DIR"/*.yaml | wc -l)"
echo "📂 Overlay YAML files list:"
ls -1 "$OVERLAY_DIR"/*.yaml

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

echo "🔍 Extracting container images from YAMLs..."
images=$(yq eval '.. | select(has("image")) | .image | select(. != null)' "$OVERLAY_DIR"/*.yaml || true)

echo "🧾 Parsed image list:"
echo "$images"

if [[ -z "$images" ]]; then
  echo "⚠️ No container images found — check overlay YAMLs or yq query syntax"
  exit 3
fi

for image in $images; do
  ((total_images++))
  echo "🚀 Scanning image: $image"

  safe_name=$(echo "$image" | tr '/:' '__')
  scan_json="scan-results/trivy-images/image-${OVERLAY}-${safe_name}.json"
  error_log="scan-results/trivy-images/error-${safe_name}.log"

  echo "🔧 Trivy command:"
  echo "$TRIVY_BIN image \"$image\" --severity HIGH,CRITICAL --no-progress --cache-dir \"$TRIVY_CACHE_DIR\" -f json -o \"$scan_json\""

  if ! "$TRIVY_BIN" image "$image" \
    --debug \
    --severity HIGH,CRITICAL \
    --no-progress \
    --cache-dir "$TRIVY_CACHE_DIR" \
    -f json -o "$scan_json" 2> "$error_log"; then

    echo "❌ Trivy scan failed for $image"
    echo "⚠️ Exit code: $?"
    echo "⚠️ stderr from Trivy:"
    cat "$error_log"
    echo "⚠️ scan_json presence:"
    ls -lah "$scan_json" || echo "🚫 JSON output not created"
    ((scan_failed++))
    continue
  fi

  ((scanned_images++))
  echo "📄 Trivy scan output (short preview):"
  head -20 "$scan_json"

  if jq -e '.Results[].Vulnerabilities != null' "$scan_json" >/dev/null; then
    while IFS= read -r vuln; do
      vuln_id=$(jq -r '.VulnerabilityID' <<< "$vuln")
      if [[ " ${approved_vulnerabilities[@]} " =~ " ${vuln_id} " ]]; then
        echo "⚠️ Approved vulnerability: $vuln_id in $image"
      else
        echo "❌ Critical vulnerability: $vuln_id in $image"
        echo "Image: $image" >> "$vuln_report"
        jq -r <<< "$vuln" '. | "  - \(.VulnerabilityID): \(.Title) (Severity: \(.Severity), Fixed: \(.FixedVersion))"' >> "$vuln_report"
        echo "" >> "$vuln_report"
        ((vulnerable_images++))
        ((scan_failed++))
      fi
    done < <(jq -c '.Results[].Vulnerabilities[]' "$scan_json")
  else
    echo "✅ No critical vulnerabilities found in $image"
  fi
done

echo "🛠 Building manifest via Kustomize..."
if ! kustomize build "$OVERLAY_DIR" > "$manifest_file"; then
  echo "❌ Failed to build manifest with kustomize"
  exit 4
fi

echo "🔎 Running Trivy config scan..."
if ! "$TRIVY_BIN" config "$manifest_file" | tee "$config_report"; then
  echo "❌ Trivy config scan failed"
  exit 5
fi

echo "📜 Trivy config scan output:"
head -30 "$config_report"

{
  echo ""
  echo "=== Image Scan Summary (${OVERLAY}) ==="
  echo "Images found: $total_images"
  echo "Images scanned: $scanned_images"
  echo "Vulnerable images: $vulnerable_images"
} >> "$image_report"

if (( scan_failed > 0 )); then
  echo "❌ One or more scans failed or critical vulnerabilities found"
  exit 1
fi

if (( scanned_images == 0 )); then
  echo "⚠️ No images were scanned — check overlay or YAMLs"
  exit 2
fi

echo "✅ Scanning complete for overlay: $OVERLAY"

