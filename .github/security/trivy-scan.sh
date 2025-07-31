#!/bin/bash
set -euo pipefail

# Scan all images in manifests
find infrastructure -name '*.yaml' -exec grep -E 'image: ' {} \; | \
  awk '{print $2}' | sort | uniq | \
  while read -r image; do
    echo "Scanning $image"
    trivy image --exit-code 1 --severity HIGH,CRITICAL "$image"
  done
