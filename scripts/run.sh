#!/usr/bin/env bash
set -euo pipefail

# --- Download codeqa binary ---
REPO="num42/codeqa-action"
BINARY_NAME="codeqa"
INSTALL_DIR="${RUNNER_TEMP:-/tmp}/codeqa-bin"
mkdir -p "$INSTALL_DIR"

if [[ "$INPUT_VERSION" == "latest" ]]; then
  DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}"
else
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${INPUT_VERSION}/${BINARY_NAME}"
fi

echo "Downloading codeqa from ${DOWNLOAD_URL}..."
curl -fsSL -o "${INSTALL_DIR}/${BINARY_NAME}" "$DOWNLOAD_URL"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

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
  line-report) OUTPUT_FILE="" ;; # line-report writes to a directory, not a file
  *)
    echo "::error::Unknown command: $INPUT_COMMAND. Must be health-report, compare, analyze, or line-report."
    exit 1
    ;;
esac

# --- Build CLI arguments ---
ARGS=("$INPUT_COMMAND" "$INPUT_PATH")
CAPTURE_STDOUT=false

case "$INPUT_COMMAND" in
  health-report)
    ARGS+=("--output" "$OUTPUT_FILE")
    ARGS+=("--detail" "$INPUT_DETAIL")
    ARGS+=("--top" "$INPUT_TOP")
    if [[ -n "$INPUT_CONFIG" ]]; then
      ARGS+=("--config" "$INPUT_CONFIG")
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
    ARGS+=("--format" "$INPUT_FORMAT")
    CAPTURE_STDOUT=true
    ;;
  analyze)
    ARGS+=("--output" "$OUTPUT_FILE")
    ;;
  line-report)
    REPORT_DIR="${INPUT_OUTPUT_DIR:-line_report_html}"
    ARGS+=("--format" "${INPUT_FORMAT:-html}")
    ARGS+=("--output-dir" "$REPORT_DIR")
    if [[ -n "${INPUT_REF:-}" ]]; then
      ARGS+=("--ref" "$INPUT_REF")
    fi
    if [[ -n "${INPUT_MAX_REPORTS:-}" ]]; then
      ARGS+=("--max-reports" "$INPUT_MAX_REPORTS")
    fi
    if [[ -n "${INPUT_CONFIG:-}" ]]; then
      ARGS+=("--config" "$INPUT_CONFIG")
    fi
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

# --- Extract grade (health-report only) ---
GRADE=""
if [[ "$INPUT_COMMAND" == "health-report" && -f "$OUTPUT_FILE" ]]; then
  GRADE=$(grep -oP '## Overall: \K\S+' "$OUTPUT_FILE" || echo "")
fi

# --- Set outputs ---
if [[ -n "$OUTPUT_FILE" ]]; then
  echo "report-file=${OUTPUT_FILE}" >> "$GITHUB_OUTPUT"
fi
echo "grade=${GRADE}" >> "$GITHUB_OUTPUT"

# Set report-dir output for line-report
if [[ "$INPUT_COMMAND" == "line-report" ]]; then
  echo "report-dir=${REPORT_DIR}" >> "$GITHUB_OUTPUT"
  echo "Report written to ${REPORT_DIR}/"
else
  echo "Output written to ${OUTPUT_FILE}"
fi

if [[ -n "$GRADE" ]]; then
  echo "Overall grade: ${GRADE}"
fi
