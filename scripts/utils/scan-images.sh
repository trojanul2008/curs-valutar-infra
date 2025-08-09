#!/bin/bash
set -euo pipefail

# Overlay passed from CI workflow
OVERLAY="${1:-default}"
echo "📦 Overlay context: $OVERLAY"

: "${TRIVY_CACHE_DIR:=/tmp/trivy-cache}"
TRIVY_BIN="$(command -v trivy || true)"

if [[ -z "$TRIVY_BIN" ]]; then
  echo "❌ Trivy binary not found in PATH"
  exit 1
fi

# Debug info
echo "### SCAN DEBUG INFO ###"
echo "Overlay: $OVERLAY"
echo "Trivy version: $($TRIVY_BIN --version | head -1)"
echo "yq version: $(yq --version)"
echo "Cache dir: $TRIVY_CACHE_DIR"
echo "Files to process: $(find infrastructure -type f \( -name '*.yaml' -o -name '*.yml' \) | wc -l)"
echo "########################"

# Counters
total_files=0
files_with_images=0
files_without_images=0
invalid_yaml_files=0
scan_failed=0
total_images=0
scanned_images=0
vulnerable_images=0

# File names include overlay for clarity
report_file="image-scan-report-${OVERLAY}.txt"
vuln_details="vulnerability-details-${OVERLAY}.txt"
echo "Image Scan Report (${OVERLAY}) - $(date)" > "$report_file"
echo "Vulnerable Images:" > "$vuln_details"

# Approved CVEs (optional hook)
approved_vulnerabilities=()

while IFS= read -r -d $'\0' file; do
  ((total_files++))
  file_entry="\n===== File: $file =====\n"

  if [[ ! "$file" =~ \.(yaml|yml)$ ]]; then
    file_entry+="Skipped: Not a YAML file\n"
    echo -e "$file_entry" >> "$report_file"
    continue
  fi

  if ! yq eval 'true' "$file" &>/dev/null; then
    ((invalid_yaml_files++))
    file_entry+="Skipped: Invalid YAML format\n"
    echo -e "$file_entry" >> "$report_file"
    continue
  fi

  images=$(yq eval '.. | select(has("image")) | .image | select(. != null) | select(. != "PLACEHOLDER") | select(tostring | test("^!") | not)' "$file" 2>/dev/null || true)

  if [ -n "$images" ]; then
    ((files_with_images++))
    file_entry+="Found images:\n"
    while IFS= read -r image; do
      [[ -n "$image" ]] && file_entry+="- $image\n" && ((total_images++))
    done <<< "$images"
    echo -e "$file_entry" >> "$report_file"

    while IFS= read -r image; do
      [[ -z "$image" ]] && continue
      echo "🔍 Scanning $image"
      ((scanned_images++))
      safe_image_name=$(echo "$image" | tr '/:' '__')
      json_report="trivy-scan-${OVERLAY}-${safe_image_name}.json"

      "$TRIVY_BIN" image --cache-dir "$TRIVY_CACHE_DIR" --severity HIGH,CRITICAL -f json -o "$json_report" "$image" || true

      if jq -e '.Results[].Vulnerabilities != null' "$json_report" >/dev/null; then
        while IFS= read -r vuln; do
          vuln_id=$(jq -r '.VulnerabilityID' <<< "$vuln")
          if [[ " ${approved_vulnerabilities[@]} " =~ " ${vuln_id} " ]]; then
            echo "⚠️ Approved vulnerability: $vuln_id in $image"
          else
            echo "❌ Critical vulnerability: $vuln_id in $image"
            echo "Image: $image" >> "$vuln_details"
            jq -r <<< "$vuln" '. | "  - \(.VulnerabilityID): \(.Title) (Severity: \(.Severity), Fixed: \(.FixedVersion))"' >> "$vuln_details"
            echo "" >> "$vuln_details"
            scan_failed=1
            ((vulnerable_images++))
          fi
        done < <(jq -c '.Results[].Vulnerabilities[]' "$json_report")
      else
        echo "✅ No critical vulnerabilities found in $image"
      fi
    done <<< "$images"
  else
    ((files_without_images++))
    echo -e "$file_entry\nNo valid images found\n" >> "$report_file"
  fi
done < <(find infrastructure -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

summary="\n=== Scan Summary (${OVERLAY}) ===
Total files processed: $total_files
Files with images: $files_with_images
Files without valid images: $files_without_images
Invalid YAML files: $invalid_yaml_files
Total images found: $total_images
Images scanned: $scanned_images
Images with vulnerabilities: $vulnerable_images
"
echo -e "$summary" >> "$report_file"

if [ -s "$vuln_details" ]; then
  echo -e "\nVulnerability Details:" >> "$report_file"
  cat "$vuln_details" >> "$report_file"
fi

cat "$report_file"
cat "$vuln_details"

if (( scan_failed )); then
  echo "❌ Critical vulnerabilities found in overlay $OVERLAY"
  exit 1
fi

echo "✅ Image vulnerability scan completed for overlay $OVERLAY"

