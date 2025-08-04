#!/bin/bash
set -euo pipefail

echo -e "\n🔧 Version Key Validation Utility"
echo "────────────────────────────────────"
echo "📝 Scans install scripts for KEY= usage"
echo "🔍 Cross-checks against .github/versions.yaml"
echo "⚠️ Warns about missing or unused keys"
echo "✅ Checks version format consistency"
echo ""

VERSIONS_FILE=".github/versions.yaml"
INSTALLERS=$(find .github/actions/tool-install -name install.sh)

# Grab keys from YAML
YAML_KEYS=$(grep -E '^[a-zA-Z0-9_]+:' "$VERSIONS_FILE" | awk -F: '{print $1}' | sort)

# Grab used keys from all install scripts
USED_KEYS=$(for SCRIPT in $INSTALLERS; do
  grep -E '^KEY=' "$SCRIPT" | cut -d'"' -f2
done | sort | uniq)

echo "🔍 Validating install scripts against $VERSIONS_FILE..."

MISSING=0
for SCRIPT in $INSTALLERS; do
  USED_KEY=$(grep -E '^KEY=' "$SCRIPT" | cut -d'"' -f2)
  if ! grep -q "^${USED_KEY}:" "$VERSIONS_FILE"; then
    echo "❌ Missing key \"$USED_KEY\" in $VERSIONS_FILE (used in: $SCRIPT)"
    echo "💡 Suggested fix: Add \"$USED_KEY: vX.Y.Z\" to $VERSIONS_FILE"
    MISSING=$((MISSING + 1))
  fi
done

# Check for unused keys in versions.yaml
echo -e "\n🔍 Checking for unused keys in $VERSIONS_FILE..."

UNUSED=$(comm -23 <(echo "$YAML_KEYS") <(echo "$USED_KEYS"))

if [[ -n "$UNUSED" ]]; then
  echo "⚠️ Unused keys in $VERSIONS_FILE:"
  echo "$UNUSED"
else
  echo "✅ No unused keys detected."
fi

# Validate format of version values
echo -e "\n🔍 Validating version format for each key..."

INVALID_FORMAT=0
for KEY in $YAML_KEYS; do
  VALUE=$(grep "^${KEY}:" "$VERSIONS_FILE" | awk -F": " '{print $2}')
  if [[ "$KEY" =~ .*VERSION$ || "$KEY" == "kubectl" || "$KEY" == "flux" || "$KEY" == "helm" || "$KEY" == "kustomize" || "$KEY" == "kyverno" || "$KEY" == "yq" || "$KEY" == "trivy" || "$KEY" == "kubeconform" ]]; then
    if ! [[ "$VALUE" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "⚠️ $KEY value \"$VALUE\" is not a valid version format"
      INVALID_FORMAT=$((INVALID_FORMAT + 1))
    fi
  fi
done

if [[ "$INVALID_FORMAT" -eq 0 ]]; then
  echo "✅ All version formats look great!"
else
  echo "⚠️ $INVALID_FORMAT format issues found — review them above."
fi

# Final exit decision
if [[ "$MISSING" -eq 0 && "$INVALID_FORMAT" -eq 0 ]]; then
  echo -e "\n🎉 All checks passed!"
else
  echo -e "\n🚨 Validation issues detected — please fix before proceeding."
  exit 1
fi

