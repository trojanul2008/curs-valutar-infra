#!/usr/bin/env bash
set -euo pipefail

REMOTE=${REMOTE:-origin}
DEV=${DEV:-dev}
PROD=${PROD:-prod}

# 0) Ensure working tree clean
if ! git diff-index --quiet HEAD --; then
  echo "❌ You have uncommitted changes. Please commit or stash before running."
  exit 1
fi

# 1) Fetch dev + prod
echo "⏳ Fetching ${REMOTE}/${DEV} and ${REMOTE}/${PROD} …"
git fetch "${REMOTE}" "${DEV}:${DEV}" --force
# try to fetch prod; ignore errors
git fetch "${REMOTE}" "${PROD}:${PROD}" || true

# 2) Make sure we're on dev
git checkout "${DEV}"

# 3) Detect if prod & dev share history
if ! git merge-base --is‑ancestor "${DEV}" "${PROD}" 2>/dev/null; then
  echo "✨ No common ancestor between ${DEV} and ${PROD}; first‑time push → creating ${PROD} from ${DEV}"
  git branch -f "${PROD}" "${DEV}"
  git checkout "${PROD}"
  echo "⏳ Force‑pushing ${PROD} → ${REMOTE}/${PROD}"
  git push "${REMOTE}" "${PROD}" --force --set-upstream
  echo "✔️  Created ${PROD} from ${DEV}"
  git checkout "${DEV}"
  exit 0
fi

# 4) Normal merge path
echo "🔀 Checking out ${PROD} and merging ${DEV} into it"
git checkout "${PROD}"
git merge --no-ff "${DEV}" -m "chore: promote ${DEV} → ${PROD}"

echo "⏳ Pushing ${PROD} → ${REMOTE}/${PROD}"
git push "${REMOTE}" "${PROD}"

# 5) Back to dev
git checkout "${DEV}"
echo "🎉 Promotion complete — you’re back on ${DEV}"

