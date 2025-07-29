#!/usr/bin/env bash
set -euo pipefail

# 🔧 Config: remote and branch names
REMOTE=${REMOTE:-origin}
DEV_BRANCH=${DEV_BRANCH:-dev}
PROD_BRANCH=${PROD_BRANCH:-prod}

# 1️⃣ Ensure we're up‑to‑date on dev
echo "⏳ Fetching ${REMOTE}/${DEV_BRANCH}..."
git fetch "${REMOTE}" "${DEV_BRANCH}"
echo "✔️  Checking out ${DEV_BRANCH}"
git checkout "${DEV_BRANCH}"
git reset --hard "${REMOTE}/${DEV_BRANCH}"

# 2️⃣ Merge into prod
echo "⏳ Checking out ${PROD_BRANCH}..."
git checkout "${PROD_BRANCH}"
echo "⏳ Merging ${DEV_BRANCH} → ${PROD_BRANCH}..."
git merge --no-ff "${DEV_BRANCH}" -m "chore: promote ${DEV_BRANCH} to ${PROD_BRANCH}"

# 3️⃣ Push prod
echo "⏳ Pushing ${PROD_BRANCH} to ${REMOTE}..."
git push "${REMOTE}" "${PROD_BRANCH}"

# 4️⃣ Return to dev
echo "✔️  Switch back to ${DEV_BRANCH}"
git checkout "${DEV_BRANCH}"

echo "🎉 Promotion complete!"

