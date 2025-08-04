#!/usr/bin/env bash
set -euo pipefail

REMOTE=${REMOTE:-origin}
DEV=${DEV:-dev}
PROD=${PROD:-prod}

# 0) Guard: working tree must be clean
if ! git diff-index --quiet HEAD --; then
  echo "❌ You have uncommitted changes. Please commit or stash before running."
  exit 1
fi

# 1) Fetch latest refs
echo "⏳ Fetching ${REMOTE}..."
git fetch "${REMOTE}" --prune

# 2) Hard-reset local dev to remote/dev
echo "🔄 Resetting ${DEV} → ${REMOTE}/${DEV}"
git checkout "${DEV}"
git reset --hard "${REMOTE}/${DEV}"

# 3) Does origin/prod exist?
if git show-ref --quiet "refs/remotes/${REMOTE}/${PROD}"; then
  # Compare ancestry: is prod contained in dev?
  if git merge-base --is-ancestor "${REMOTE}/${PROD}" "${REMOTE}/${DEV}"; then
    echo "🔀 Fast-forwarding ${PROD} to match ${DEV}"
    git branch -f "${PROD}" "${DEV}"
    git push "${REMOTE}" "${PROD}" --force-with-lease --set-upstream
    git checkout "${DEV}"
    echo "🎉 Promotion complete (fast-forward)."
    exit 0
  fi
  echo "⚠️  ${PROD} history diverged → recreating from ${DEV}"
else
  echo "✨ ${PROD} does not yet exist on ${REMOTE} → creating first version"
fi

# 4) Force-recreate prod
echo "🚀 Force-creating ${PROD} from ${DEV}"
git branch -f "${PROD}" "${DEV}"
git checkout "${PROD}"
echo "⏳ Force-pushing ${PROD} → ${REMOTE}/${PROD}"
git push --force --set-upstream "${REMOTE}" "${PROD}"
git checkout "${DEV}"
echo "✔️  ${PROD} is now aligned with ${DEV}"
