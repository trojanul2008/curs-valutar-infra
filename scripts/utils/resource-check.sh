#!/bin/bash
set -euo pipefail
NS="${1:-dev}"

kubectl get pods -n "$NS" -o json | \
  jq '.items[] | {name: .metadata.name, containers: .spec.containers[] | {name: .name, req: .resources.requests.memory, lim: .resources.limits.memory}} | select(.lim != null and .req != null) | select((.lim | sub("Mi"; "") | tonumber) / (.req | sub("Mi"; "") | tonumber) > 2)'

