#!/bin/bash
set -euo pipefail

# Enhanced debug info
echo "### SCAN DEBUG INFO ###"
echo "Trivy version: $(trivy --version | head -1)"
echo "yq version: $(yq --version)"
echo "Cache dir: $TRIVY_CACHE_DIR"
echo "Files to process: $(find infrastructure -type f \( -name '*.yaml' -o -name '*.yml' \) | wc -l)"
echo "########################"

# Initialize counters
total_files=0
files_with_images=0
files_without_images=0
invalid_yaml_files=0
scan_failed=0
total_images=0
scanned_images=0
vulnerable_images=0

# Create report file
report_file="image-scan-report.txt"
echo "Image Scan Report - $(date)" > "$report_file"

# Process all YAML files
while IFS= read -r -d $'\0' file; do
  ((total_files++))
  file_entry="\n===== File: $file =====\n"
  
  # Skip non-YAML files
  if [[ ! "$file" =~ \.(yaml|yml)$ ]]; then
    file_entry+="Skipped: Not a YAML file\n"
    echo -e "$file_entry" >> "$report_file"
    continue
  fi

  # Check if valid YAML - capture errors
  yq_error=""
  if ! yq_output=$(yq eval 'true' "$file" 2>&1); then
    ((invalid_yaml_files++))
    file_entry+="Skipped: Invalid YAML format\n"
    file_entry+="YQ Error: $yq_output\n"
    echo -e "$file_entry" >> "$report_file"
    echo "⚠️ Invalid YAML: $file - $yq_output" >&2
    continue
  fi

  # Extract images (ignore PLACEHOLDER and Kyverno patterns)
  images=$(
    yq eval '.. | select(has("image")) | .image | 
    select(. != null) | 
    select(. != "PLACEHOLDER") | 
    select(tostring | test("^!") | not)' \
    "$file" 2>/dev/null || true
  )

  # Process images if found
  if [ -n "$images" ]; then
    ((files_with_images++))
    file_entry+="Found images:\n"
    while IFS= read -r image; do
      if [ -n "$image" ]; then
        file_entry+="- $image\n"
        ((total_images++))
      fi
    done <<< "$images"
    echo -e "$file_entry" >> "$report_file"
    
    # Scan each image
    while IFS= read -r image; do
      if [ -n "$image" ]; then
        echo "Scanning $image"
        ((scanned_images++))
        if ! trivy image --cache-dir "$TRIVY_CACHE_DIR" \
            --exit-code 1 --severity HIGH,CRITICAL "$image"; then
          echo "❌ Critical vulnerabilities found in $image"
          scan_failed=1
          ((vulnerable_images++))
        fi
      fi
    done <<< "$images"
  else
    ((files_without_images++))
    file_entry+="No valid images found in this file\n"
    echo -e "$file_entry" >> "$report_file"
    echo "ℹ️ File without images: $file" >&2
  fi
done < <(find infrastructure -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

# Generate summary
summary="\n=== Scan Summary ===
Total files processed: $total_files
Files with images: $files_with_images
Files without valid images: $files_without_images
Invalid YAML files: $invalid_yaml_files
Total images found: $total_images
Images scanned: $scanned_images
Images with vulnerabilities: $vulnerable_images
"
echo -e "$summary" >> "$report_file"

# Print report
echo -e "\n📊 Scan Report:"
cat "$report_file"

# Print files without images to console
if [ "$files_without_images" -gt 0 ]; then
  echo -e "\nℹ️ Files without valid images:"
  grep -B1 "No valid images found" "$report_file" | grep "File:"
fi

# Print invalid YAML files to console
if [ "$invalid_yaml_files" -gt 0 ]; then
  echo -e "\n⚠️ Invalid YAML files:"
  grep -B1 "Invalid YAML format" "$report_file" | grep "File:"
fi

# Exit with error if any scan failed
if [ "$scan_failed" -eq 1 ]; then
  echo "❌ Critical vulnerabilities found in $vulnerable_images image(s)"
  exit 1
fi

echo "✅ Scan completed successfully"
