#!/bin/bash
set -euo pipefail

# Check memory requests vs limits
kubectl get pods -n dev -o json | \
  jq '.items[] | {name: .metadata.name, containers: .spec.containers[] | {name: .name, req: .resources.requests.memory, lim: .resources.limits.memory}} | select(.lim != null and .req != null) | select((.lim | sub("Mi"; "") | tonumber) / (.req | sub("Mi"; "") | tonumber) > 2)'
