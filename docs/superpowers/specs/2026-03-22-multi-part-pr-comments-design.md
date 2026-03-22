# Multi-Part PR Comments Design

**Date:** 2026-03-22
**Status:** Proposed

## Context

The `codeqa health-report` GitHub Action posts a markdown report as a sticky PR comment via `marocchino/sticky-pull-request-comment@v2`. GitHub's PR comment API has a hard 65,536 character limit. On large codebases (300+ files), the generated report exceeds this limit and the posting step fails.

## Solution

Split the report into fixed-section parts, each posted as a separate sticky PR comment. No content compression — splitting is purely a rendering concern.

## Part Assignment

Parts are fixed, not dynamically determined by content size (except Part 3+ which slices the blocks section).

| Part | Sticky Header | Content |
|------|--------------|---------|
| 1 | `codeqa-health-report-1` | Header + overall grade + mermaid chart + progress bars + overall category table + PR summary + metric changes (delta) |
| 2 | `codeqa-health-report-2` | Top likely issues + all category detail sections (threshold metrics + cosine behaviors) |
| 3+ | `codeqa-health-report-3`, `codeqa-health-report-4`, … | Blocks section, sliced at 60,000 characters per part |

Each non-final chunk of Part 3+ ends with:

```
> ⚠️ Truncated at 60,000 chars — continued in next comment
```

If there are no blocks, Part 3 is written as a single empty part (`""`).

## Formatter Changes

**File:** `lib/codeqa/health_report/formatter/github.ex`

Add three new rendering entry points alongside the existing `render/3`:

- `render_part_1(report, opts)` → `String.t()` — header, summary table, PR summary, delta, mermaid chart, progress bars
- `render_part_2(report, opts)` → `String.t()` — top issues, all category detail sections
- `render_parts_3(report, opts)` → `[String.t()]` — blocks section sliced into 60,000-char chunks; returns `[""]` when no blocks exist

The existing `render/3` is not changed. It continues to produce the full single-string report for `--output file` usage.

## CLI Changes

**File:** `lib/codeqa/cli/health_report.ex`

Add `render_parts(report, opts)` → `[String.t()]` — returns a flat list `[part_1, part_2, part_3a, part_3b, ...]`. Used internally when the `comment: true` path is active. `comment: true` is an **existing** flag (already parsed from `INPUT_COMMENT` env var in `run.sh` and passed as `--comment` to the CLI); no new flag is introduced.

When writing output for comment mode, the CLI writes each part to a numbered temp file:

- `$TMPDIR/codeqa-part-1.md`
- `$TMPDIR/codeqa-part-2.md`
- `$TMPDIR/codeqa-part-3.md`
- … etc.

It also writes `$TMPDIR/codeqa-part-count.txt` containing the integer count of parts.

The existing `--output` flag behaviour (write single file) is unchanged.

## Stale Comment Handling

If a previous run produced 4 parts and the current run produces 2, the old parts 3 and 4 remain stale. To handle this, always write a minimum of 3 part files. Parts beyond the actual content get a single-line placeholder:

```
> _No content for this section._
```

The sticky comment action overwrites the stale comment with the placeholder rather than leaving old content. The minimum of 3 is sufficient for the current fixed-section design. Real content is written for any blocks overflow to part 4+.

**Known limitation:** if run N produces more than 3 parts (e.g., 5) and run N+1 produces fewer (e.g., 3), parts 4 and 5 from run N remain stale permanently — the minimum-3 floor does not cover them. This is accepted as an edge case; the stale comments are cosmetic (they hold the placeholder text), and a future cleanup step can address it if needed.

## Action / run.sh Changes

**File:** `scripts/run.sh`

After generating part files, loop over them and post each as a sticky PR comment. Use the GitHub REST API directly (`curl -s -X POST/PATCH`) with the following sticky update-or-create logic:

1. Search existing PR comments for one whose body contains the sentinel `<!-- codeqa-health-report-{N} -->` (appended to each part by the formatter)
2. If found: `PATCH /repos/{owner}/{repo}/issues/comments/{id}` with the new body
3. If not found: `POST /repos/{owner}/{repo}/issues/{pr_number}/comments` with the new body

Each part's markdown ends with the sentinel HTML comment so future runs can locate and update it:

```
<!-- codeqa-health-report-{N} -->
```

This replicates the sticky semantics of `marocchino/sticky-pull-request-comment@v2` without depending on that action for a variable number of posts. `run.sh` uses `GITHUB_TOKEN` (already available in the action environment) and `GITHUB_API_URL`, `GITHUB_REPOSITORY`, and `PR_NUMBER` (sourced from the workflow env).

**File:** `.github/workflows/health-report.yml`

Remove the `marocchino/sticky-pull-request-comment@v2` step. `run.sh` now owns posting entirely. The workflow passes `PR_NUMBER: ${{ github.event.pull_request.number }}` as an env var to the run step.

## Key Constraints

- `render/3` must not change behaviour — used by `--output` flag
- Part 1 must always be self-contained — a reader seeing only Part 1 gets the full codebase health picture
- Parts 2 and 3 are drill-down detail; safe to be empty if the codebase has no behaviors or blocks
- 60,000 char slice limit (not 65,536) leaves headroom for sticky comment metadata

## Breaking Change

The sticky comment header for Part 1 changes from `codeqa-health-report` to `codeqa-health-report-1`. Old single-part comments will not be cleaned up automatically on the first run after upgrade.

## Files Affected

| File | Change |
|------|--------|
| `lib/codeqa/health_report/formatter/github.ex` | Add `render_part_1/2`, `render_part_2/2`, `render_parts_3/2` |
| `lib/codeqa/cli/health_report.ex` | Add `render_parts/2`, multi-file output in comment mode |
| `scripts/run.sh` | Loop to post multiple part files |
| `.github/workflows/health-report.yml` | Simplified posting step |
| `test/codeqa/health_report/formatter_test.exs` | Tests for new part renderers |

## What Does Not Change

- The `--detail`, `--top`, `--format`, `--output` CLI flags
- The plain formatter (`Formatter.Plain`)
- Report data assembly (`health_report.ex`, `grader.ex`, `top_blocks.ex`) — splitting is purely a rendering concern
