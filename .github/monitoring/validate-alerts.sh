#!/bin/bash
set -euo pipefail

# Validate alert rules
docker run --rm -v $(pwd):/work prom/promtool check rules /work/infrastructure/monitoring/alerts.yaml
