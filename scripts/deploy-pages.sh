#!/usr/bin/env bash
set -euo pipefail

# Deploy generated line-report to GitHub Pages branch.
#
# Inputs via environment:
#   PUBLISH_BRANCH - branch to deploy to (e.g. "gh-pages")
#   PAGES_PATH     - subdirectory within the branch (e.g. "codeqa")
#   DEPLOY_DIR     - local directory containing the generated report
#   GITHUB_TOKEN   - token for pushing
#   GITHUB_REPOSITORY - owner/repo
#   INPUT_REF      - git ref used in commit message

if [[ -z "${PUBLISH_BRANCH:-}" ]]; then
  echo "::error::PUBLISH_BRANCH not set"
  exit 1
fi

if [[ -z "${DEPLOY_DIR:-}" || ! -d "${DEPLOY_DIR:-}" ]]; then
  echo "::error::DEPLOY_DIR not set or does not exist: ${DEPLOY_DIR:-}"
  exit 1
fi

PAGES_PATH="${PAGES_PATH:-codeqa}"
WORK_DIR="${RUNNER_TEMP:-/tmp}/codeqa-pages-deploy"
rm -rf "$WORK_DIR"

# --- Checkout existing branch or init empty ---
REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

if git ls-remote --exit-code --heads "$REPO_URL" "$PUBLISH_BRANCH" >/dev/null 2>&1; then
  echo "Checking out existing ${PUBLISH_BRANCH} branch..."
  git clone --single-branch --branch "$PUBLISH_BRANCH" --depth 1 "$REPO_URL" "$WORK_DIR"
else
  echo "Creating new ${PUBLISH_BRANCH} branch..."
  mkdir -p "$WORK_DIR"
  pushd "$WORK_DIR" >/dev/null
  git init
  git checkout -b "$PUBLISH_BRANCH"
  git remote add origin "$REPO_URL"
  popd >/dev/null
fi

# --- Copy report into pages path ---
mkdir -p "${WORK_DIR}/${PAGES_PATH}"

# Overlay new files without deleting existing ones.
# manifest.json was already merged by the CLI via --ref.
rsync -a "${DEPLOY_DIR}/" "${WORK_DIR}/${PAGES_PATH}/"

# --- Commit and push ---
pushd "$WORK_DIR" >/dev/null

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add -A

if git diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

REF_SHORT="${INPUT_REF:-unknown}"
git commit -m "deploy: codeqa line-report for ${REF_SHORT}"

echo "Pushing to ${PUBLISH_BRANCH}..."
git push origin "$PUBLISH_BRANCH"

popd >/dev/null
echo "Deployed to ${PUBLISH_BRANCH}/${PAGES_PATH}/"
