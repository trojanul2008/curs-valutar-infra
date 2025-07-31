#!/bin/bash
set -euo pipefail

# Get service URL
URL=$(kubectl get svc -n dev curs-valutar -o jsonpath='{.spec.clusterIP}')

# Run load test
echo "GET http://$URL" | vegeta attack -duration=30s -rate=10 | vegeta report
