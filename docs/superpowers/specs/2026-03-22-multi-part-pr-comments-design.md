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

Add `render_parts(report, opts)` → `[String.t()]` — returns a flat list `[part_1, part_2, part_3a, part_3b, ...]`. Used internally when the `comment: true` path is active.

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

## Action / run.sh Changes

**File:** `scripts/run.sh`

After generating part files, loop over them and post each using `gh pr comment` (or the GitHub API directly). Each part uses its own sticky header `codeqa-health-report-{N}`.

`run.sh` takes ownership of the posting loop since it already has access to all required env vars. This avoids duplicating logic across multiple YAML steps.

**File:** `.github/workflows/health-report.yml`

The current single `marocchino/sticky-pull-request-comment@v2` step is replaced. The YAML posting step becomes a no-op for comment posting; run.sh handles it entirely. No YAML changes are needed as the number of parts varies — a shell loop in run.sh handles the variable count cleanly.

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
