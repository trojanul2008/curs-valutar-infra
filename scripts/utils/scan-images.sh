#!/usr/bin/env bash
set -euo pipefail

# Overlay passed from CI workflow
OVERLAY="${1:-dev}"
OVERLAY_DIR="infrastructure/k8s/overlays/${OVERLAY}"
TRIVY_BIN="$(command -v trivy || true)"
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-/tmp/trivy-cache}"

if [[ -z "$TRIVY_BIN" ]]; then
  echo "❌ Trivy binary not found in PATH"
  exit 1
fi

echo "📦 Overlay context: $OVERLAY"
echo "Trivy version: $($TRIVY_BIN --version | head -1)"
echo "yq version: $(yq --version)"
echo "Cache dir: $TRIVY_CACHE_DIR"
echo "Overlay YAML files: $(ls -1 "$OVERLAY_DIR"/*.yaml | wc -l)"

# Prep directories
mkdir -p scan-results
mkdir -p scan-results/trivy-images
mkdir -p scan-results/trivy-configs

image_report="scan-results/image-scan-report-${OVERLAY}.txt"
vuln_report="scan-results/vulnerability-details-${OVERLAY}.txt"
config_report="scan-results/trivy-config-${OVERLAY}.txt"
manifest_file="scan-results/manifest-${OVERLAY}.yaml"

# Initialize reports
echo "Image Scan Report (${OVERLAY}) - $(date)" > "$image_report"
echo "Vulnerable Images:" > "$vuln_report"

total_images=0
scanned_images=0
vulnerable_images=0
scan_failed=0
approved_vulnerabilities=()

echo "🔍 Extracting container images from overlay YAMLs..."
images=$(yq eval '.. | select(has("image")) | .image | select(. != null)' "$OVERLAY_DIR"/*.yaml || true)

for image in $images; do
  ((total_images++))
  echo "🚀 Scanning image: $image"

  safe_name=$(echo "$image" | tr '/:' '__')
  scan_json="scan-results/trivy-images/image-${OVERLAY}-${safe_name}.json"

  # Extra debug before calling Trivy
  echo "🔧 Command: $TRIVY_BIN image --severity HIGH,CRITICAL --no-progress --cache-dir $TRIVY_CACHE_DIR -f json -o $scan_json $image"

  # Actually run the scan and capture stderr
  if ! "$TRIVY_BIN" image "$image" \
      --severity HIGH,CRITICAL \
      --no-progress \
      --cache-dir "$TRIVY_CACHE_DIR" \
      -f json -o "$scan_json" 2> "scan-results/trivy-images/error-${safe_name}.log"; then

    echo "❌ Trivy scan failed for $image"
    echo "⚠️ Error log:"
    cat "scan-results/trivy-images/error-${safe_name}.log"
    ((scan_failed++))
    continue
  fi

  ((scanned_images++))

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
kustomize build "$OVERLAY_DIR" > "$manifest_file"

echo "🔎 Running config scan with Trivy..."
"$TRIVY_BIN" config "$manifest_file" | tee "$config_report"

# Summary
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

