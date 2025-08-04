#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 🔧 Utility Functions for Tool Installation
#   – Logging helpers
#   – Version validation
# --------------------------------------------------

log_success() { echo -e "✅ $*"; }
log_error()   { echo -e "❌ $*" >&2; }
log_info()    { echo -e "ℹ️  $*"; }

# Validate if installed tool version matches expected
validate_version_match() {
  local tool="$1"
  local expected="$2"
  local actual="$($tool version 2>/dev/null | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+')"

  if [[ "$actual" == "$expected" || "$actual" == "v$expected" ]]; then
    return 0
  else
    log_error "Installed $tool version '$actual' does not match expected '$expected'"
    return 1
  fi
}

