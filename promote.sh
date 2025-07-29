#!/usr/bin/env bash
set -euo pipefail

REMOTE=origin
DEV=dev
PROD=prod

# 1) Make sure we're on DEV and it's up to date
current=$(git symbolic-ref --short HEAD)
if [[ "$current" != "$DEV" ]]; then
  echo "❌ Please run this script while on the '$DEV' branch (currently on '$current')."
  exit 1
fi
git pull "$REMOTE" "$DEV"

# 2) Try fetching PROD
if git ls-remote --exit-code --heads "$REMOTE" "$PROD" >/dev/null; then
  echo "⏳ Remote '$PROD' exists—fetching it."
  git fetch "$REMOTE" "$PROD":"$PROD"
else
  echo "✨ Remote '$PROD' does not exist—will create it."
fi

# 3) If PROD branch missing locally or no common ancestor, create it from DEV
if ! git show-ref --verify --quiet "refs/heads/$PROD"; then
  echo "🚀 Creating local '$PROD' from '$DEV'."
  git checkout -b "$PROD"
  git push --set-upstream "$REMOTE" "$PROD"
  git checkout "$DEV"
  echo "✅ '$PROD' created and pushed—done."
  exit 0
fi

# 4) Otherwise merge
echo "🔀 Checking out '$PROD' and merging '$DEV' into it."
git checkout "$PROD"
git merge --no-ff "$DEV" -m "chore: promote $DEV → $PROD"
echo "⏳ Pushing '$PROD' → '$REMOTE/$PROD'"
git push "$REMOTE" "$PROD"

# 5) Go back to DEV
git checkout "$DEV"
echo "✅ Promotion complete—you're back on '$DEV'."

