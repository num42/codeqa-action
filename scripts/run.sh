#!/usr/bin/env bash
set -euo pipefail

# --- Obtain codeqa binary ---
BINARY_NAME="codeqa"
INSTALL_DIR="${RUNNER_TEMP:-/tmp}/codeqa-bin"
mkdir -p "$INSTALL_DIR"

if [[ "${INPUT_BUILD:-release}" == "source" ]]; then
  echo "Building codeqa from source..."
  SOURCE_DIR="${GITHUB_ACTION_PATH:-.}"
  (cd "$SOURCE_DIR" && mix deps.get && mix escript.build)
  cp "${SOURCE_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
  chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
else
  REPO="num42/codeqa-action"
  if [[ "$INPUT_VERSION" == "latest" ]]; then
    DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}"
  else
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${INPUT_VERSION}/${BINARY_NAME}"
  fi
  echo "Downloading codeqa from ${DOWNLOAD_URL}..."
  curl -fsSL -o "${INSTALL_DIR}/${BINARY_NAME}" "$DOWNLOAD_URL"
  chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
fi

CODEQA="${INSTALL_DIR}/${BINARY_NAME}"

# --- Determine output file ---
OUTPUT_FILE="${RUNNER_TEMP:-/tmp}/codeqa-output"
case "$INPUT_COMMAND" in
  health-report) OUTPUT_FILE="${OUTPUT_FILE}.md" ;;
  compare)
    if [[ "$INPUT_FORMAT" == "markdown" ]]; then
      OUTPUT_FILE="${OUTPUT_FILE}.md"
    else
      OUTPUT_FILE="${OUTPUT_FILE}.json"
    fi
    ;;
  analyze) OUTPUT_FILE="${OUTPUT_FILE}.json" ;;
  *)
    echo "::error::Unknown command: $INPUT_COMMAND. Must be health-report, compare, or analyze."
    exit 1
    ;;
esac

# --- Build CLI arguments ---
ARGS=("$INPUT_COMMAND" "$INPUT_PATH")
CAPTURE_STDOUT=false
COMMENT_MODE=false

case "$INPUT_COMMAND" in
  health-report)
    ARGS+=("--detail" "$INPUT_DETAIL")
    ARGS+=("--top" "$INPUT_TOP")
    if [[ -n "$INPUT_CONFIG" ]]; then
      ARGS+=("--config" "$INPUT_CONFIG")
    fi
    if [[ "${INPUT_COMMENT:-false}" == "true" ]]; then
      ARGS+=("--comment")
      COMMENT_MODE=true
    else
      ARGS+=("--output" "$OUTPUT_FILE")
    fi
    ;;
  compare)
    BASE_REF="${INPUT_BASE_REF}"
    if [[ -z "$BASE_REF" ]]; then
      BASE_REF="${GITHUB_BASE_REF:-}"
      if [[ -z "$BASE_REF" ]]; then
        echo "::error::No base-ref provided and not running in a PR context"
        exit 1
      fi
      git -C "$INPUT_PATH" fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
      BASE_REF="origin/${BASE_REF}"
    fi
    ARGS+=("--base-ref" "$BASE_REF")
    if [[ "${INPUT_COMMENT:-false}" == "true" ]]; then
      ARGS+=("--format" "github")
    else
      ARGS+=("--format" "$INPUT_FORMAT")
    fi
    CAPTURE_STDOUT=true
    ;;
  analyze)
    ARGS+=("--output" "$OUTPUT_FILE")
    ;;
esac

# Parse ignore-paths YAML list into --ignore-paths flag
if [[ -n "$INPUT_IGNORE_PATHS" ]]; then
  IGNORE_CSV=""
  while IFS= read -r line; do
    # Strip YAML list prefix "- " and surrounding whitespace
    pattern=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [[ -n "$pattern" ]]; then
      if [[ -n "$IGNORE_CSV" ]]; then
        IGNORE_CSV="${IGNORE_CSV},${pattern}"
      else
        IGNORE_CSV="$pattern"
      fi
    fi
  done <<< "$INPUT_IGNORE_PATHS"
  if [[ -n "$IGNORE_CSV" ]]; then
    ARGS+=("--ignore-paths" "$IGNORE_CSV")
  fi
fi

# Append extra args (word-split intentionally)
if [[ -n "$INPUT_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  ARGS+=($INPUT_EXTRA_ARGS)
fi

# --- Run codeqa ---
echo "Running: codeqa ${ARGS[*]}"
if [[ "${CAPTURE_STDOUT}" == "true" ]]; then
  "$CODEQA" "${ARGS[@]}" > "$OUTPUT_FILE"
else
  "$CODEQA" "${ARGS[@]}"
fi

# --- Post multi-part PR comments (health-report with comment mode) ---
if [[ "$COMMENT_MODE" == "true" ]]; then
  TMPDIR="${TMPDIR:-/tmp}"
  PART_COUNT_FILE="${TMPDIR}/codeqa-part-count.txt"

  if [[ ! -f "$PART_COUNT_FILE" ]]; then
    echo "::error::Part count file not found at ${PART_COUNT_FILE}"
    exit 1
  fi

  PART_COUNT=$(cat "$PART_COUNT_FILE")
  echo "Posting ${PART_COUNT} comment parts..."

  # GitHub API settings
  API_URL="${GITHUB_API_URL:-https://api.github.com}"
  REPO="${GITHUB_REPOSITORY}"
  PR_NUMBER="${PR_NUMBER:-}"

  if [[ -z "$PR_NUMBER" ]]; then
    echo "::error::PR_NUMBER not set. Cannot post PR comments."
    exit 1
  fi

  for i in $(seq 1 "$PART_COUNT"); do
    PART_FILE="${TMPDIR}/codeqa-part-${i}.md"
    SENTINEL="<!-- codeqa-health-report-${i} -->"

    if [[ ! -f "$PART_FILE" ]]; then
      echo "::warning::Part file ${PART_FILE} not found, skipping"
      continue
    fi

    BODY=$(cat "$PART_FILE")

    # Search for existing comment with this sentinel
    echo "Searching for existing comment with sentinel: ${SENTINEL}"
    COMMENTS_JSON=$(curl -fsSL \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${API_URL}/repos/${REPO}/issues/${PR_NUMBER}/comments?per_page=100" 2>/dev/null || echo "[]")

    # Find comment ID containing the sentinel
    COMMENT_ID=$(echo "$COMMENTS_JSON" | jq -r --arg sentinel "$SENTINEL" \
      '.[] | select(.body | contains($sentinel)) | .id' | head -1)

    # Prepare JSON payload
    PAYLOAD=$(jq -n --arg body "$BODY" '{"body": $body}')

    if [[ -n "$COMMENT_ID" && "$COMMENT_ID" != "null" ]]; then
      echo "Updating existing comment ${COMMENT_ID} for part ${i}..."
      curl -fsSL -X PATCH \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "${API_URL}/repos/${REPO}/issues/comments/${COMMENT_ID}" \
        -d "$PAYLOAD" > /dev/null
    else
      echo "Creating new comment for part ${i}..."
      curl -fsSL -X POST \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "${API_URL}/repos/${REPO}/issues/${PR_NUMBER}/comments" \
        -d "$PAYLOAD" > /dev/null
    fi
  done

  echo "All ${PART_COUNT} comment parts posted successfully"

  # Use part 1 as the main output file for grade extraction
  OUTPUT_FILE="${TMPDIR}/codeqa-part-1.md"
fi

# --- Extract grade (health-report only) ---
GRADE=""
if [[ "$INPUT_COMMAND" == "health-report" && -f "$OUTPUT_FILE" ]]; then
  GRADE=$(grep -oP '(?:## Overall: |## [🟢🟡🟠🔴] Code Health: )\K\S+' "$OUTPUT_FILE" || echo "")
fi

# --- Set outputs ---
echo "report-file=${OUTPUT_FILE}" >> "$GITHUB_OUTPUT"
echo "grade=${GRADE}" >> "$GITHUB_OUTPUT"

echo "Output written to ${OUTPUT_FILE}"
if [[ -n "$GRADE" ]]; then
  echo "Overall grade: ${GRADE}"
fi
