#!/usr/bin/env bash
set -euo pipefail

REMOTE=${REMOTE:-origin}
DEV=${DEV:-dev}
PROD=${PROD:-prod}

# 0) Ensure working tree is clean
if ! git diff-index --quiet HEAD --; then
  echo " You have uncommitted changes. Please commit or stash before running."
  exit 1
fi

# 1) Fetch latest from origin
echo " Fetching ${REMOTE}..."
git fetch "${REMOTE}" --prune

# 2) Reset local dev to match origin/dev
echo " Resetting ${DEV}  ${REMOTE}/${DEV}"
git checkout "${DEV}"
git reset --hard "${REMOTE}/${DEV}"

# 3) Check if origin/prod exists
if git show-ref --quiet "refs/remotes/${REMOTE}/${PROD}"; then
  # origin/prod exists  check if dev is an ancestor of prod
  if git merge-base --is-ancestor "${REMOTE}/${DEV}" "${REMOTE}/${PROD}"; then
    echo " Merging ${DEV}  ${PROD}"
    git checkout "${PROD}"
    git reset --hard "${REMOTE}/${PROD}"
    git merge --no-ff "${DEV}" -m "chore: promote ${DEV}  ${PROD}"
    echo " Pushing merged ${PROD}  ${REMOTE}/${PROD}"
    git push "${REMOTE}" "${PROD}"
    git checkout "${DEV}"
    echo " Promotion complete!"
    exit 0
  fi
  echo " origin/${PROD} and origin/${DEV} have no common ancestor  recreating ${PROD}"
else
  echo " origin/${PROD} not found  creating first-time branch ${PROD}"
fi

# 4) First-time or unrelated histories  force-create prod from dev
echo " Force-creating ${PROD} from ${DEV}"
git branch -f "${PROD}" "${DEV}"
git checkout "${PROD}"
echo " Force-pushing ${PROD}  ${REMOTE}/${PROD}"
git push --force --set-upstream "${REMOTE}" "${PROD}"
git checkout "${DEV}"
echo " ${PROD} is now at the same tip as ${DEV}"
