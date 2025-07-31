#!/usr/bin/env bash
set -euo pipefail

# Extract images, skip placeholders
find infrastructure -name '*.yaml' -exec grep -E 'image: ' {} \; \
  | awk '$2 != "" && $2 !~ /PLACEHOLDER/ {print $2}' \
  | sort -u \
  | while read -r image; do
      echo "🔍 Scanning $image"
      trivy image \
        --exit-code 1 \
        --severity HIGH,CRITICAL \
        "$image"
    done

