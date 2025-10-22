#!/usr/bin/env bash
set -euo pipefail

# Install Snyk (node-based) and Checkov (python-based) for CI runners
# This script is idempotent and will skip tools already present.

echo "🧩 install-snyk-checkov: starting"

# --- Snyk ---
if command -v snyk >/dev/null 2>&1; then
  echo "snyk already installed: $(snyk --version 2>&1 | head -n1 || true)"
else
  echo "Installing Node.js (via NodeSource) and snyk..."
  # Ensure curl is available
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is missing; installing curl..."
    sudo apt-get update -y
    sudo apt-get install -y curl
  fi

  # Install Node LTS via NodeSource (idempotent)
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi

  # Try to install snyk globally. Try without sudo first; fallback to sudo.
  if npm install -g snyk; then
    echo "snyk installed via npm"
  else
    echo "npm global install failed, retrying with sudo"
    sudo npm install -g snyk
  fi

  echo "snyk version: $(snyk --version 2>&1 | head -n1 || true)"
fi

# --- Checkov ---
if command -v checkov >/dev/null 2>&1; then
  echo "checkov already installed: $(checkov --version 2>&1 | head -n1 || true)"
else
  echo "Installing Python3/pip and checkov..."
  # Ensure python3 and pip are present
  if ! command -v python3 >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y python3
  fi

  if ! command -v pip3 >/dev/null 2>&1; then
    sudo apt-get install -y python3-pip
  fi

  # Try normal user pip install; fallback to sudo if necessary
  if pip3 install --user --upgrade pip checkov; then
    echo "checkov installed for user"
    # Ensure pip user bin is on PATH in GH runner; print where checkov is
    if command -v checkov >/dev/null 2>&1; then
      echo "checkov available at: $(command -v checkov)"
    else
      # Try to install globally
      echo "checkov not on PATH after user install, trying global install"
      sudo pip3 install --upgrade checkov
    fi
  else
    echo "pip user install failed; trying sudo pip install"
    sudo pip3 install --upgrade checkov
  fi

  echo "checkov version: $(checkov --version 2>&1 | head -n1 || true)"
fi

echo "✅ install-snyk-checkov: done"

