# Health Report: Block Impact Section, PR Delta, and Compare Consolidation

**Date:** 2026-03-20
**Status:** Approved for implementation

---

## Goal

Unify the health-report and compare commands into a single PR-aware report that:

1. Shows impactful code blocks per changed file with severity and fix hints
2. Shows a before/after metric delta with bar graphs when a base ref is provided
3. Shows a PR impact summary at the top of the report
4. Removes file-level worst_offenders (replaced by block-level view)
5. Deletes the compare command entirely

---

## User Stories Addressed

| User | Need | How addressed |
|------|------|---------------|
| PR author | Find antipatterns by file and line | Block section: file-grouped, line-precise, behavior + fix hint |
| Reviewer | Estimate merge risk quickly | PR impact summary: score drift, blocks flagged, files changed |
| Reviewer | Spot quality regressions | Block severity label + delta bar graphs |
| New repo user | Assess overall code quality | Overall grade + category breakdown (unchanged) |

---

## Architecture

### What Changes

| Component | Change |
|-----------|--------|
| `CLI.HealthReport` | Add `--base-ref`, `--head-ref` flags; wire git diff and dual analysis |
| `HealthReport.generate/2` | Accept `changed_files` + `base_results` opts; add `top_blocks` and `codebase_delta` keys; drop `worst_offenders` |
| `HealthReport.Delta` | New module — wraps delta computation (logic ported from `Comparator`) |
| `HealthReport.Formatter` | Remove worst_offenders rendering; add PR summary, delta bar graphs, block section |
| `BlockImpactAnalyzer` | Add `end_line` to serialized node output |
| `CLI.Compare` | **Deleted** |
| `Comparator` | **Deleted** (logic moved to `HealthReport.Delta`) |
| `lib/codeqa/formatter.ex` | **Deleted** (compare-only formatter — confirmed no health-report usage) |
| `Summarizer` | **Deleted** (confirmed compare-only) |

### What Stays the Same

- Overall score, grade, categories (threshold + cosine)
- `top_issues` (SampleRunner diagnose_aggregate)
- Metadata section
- All analysis options (workers, cache, timeout, NCD flags)
- Backward compatibility: running without `--base-ref` produces the existing report minus worst_offenders

---

## Data Flow

### With `--base-ref`

```
CLI.HealthReport
  ├── Git.collect_files_at_ref(path, base_ref) → base_files_map
  ├── Git.collect_files_at_ref(path, head_ref) → head_files_map  (head_ref defaults to HEAD)
  ├── Git.changed_files(path, base_ref, head_ref) → [%ChangedFile{path, status}]
  ├── Analyzer.analyze_codebase(head_files_map) → head_results
  ├── BlockImpactAnalyzer.analyze(head_results, head_files_map) → head_results_with_nodes
  ├── Analyzer.analyze_codebase(base_files_map) → base_results
  └── HealthReport.generate(head_results_with_nodes,
        base_results: base_results,
        changed_files: [%ChangedFile{path, status}])   # full structs, not just paths
```

### Without `--base-ref`

```
CLI.HealthReport
  ├── Analyzer.analyze_codebase(files_map) → results
  ├── BlockImpactAnalyzer.analyze(results, files_map) → results_with_nodes
  └── HealthReport.generate(results_with_nodes)
      (no delta, blocks shown for all files with significant impact, status: nil)
```

---

## CLI Options

Added to `codeqa health-report <path>`:

| Option | Default | Description |
|--------|---------|-------------|
| `--base-ref REF` | (none) | Base git ref to compare from. Enables delta and PR scoping. |
| `--head-ref REF` | `HEAD` | Head git ref for comparison |

Removed: `--changes-only` (never used; always analyzes all files).

---

## `HealthReport.generate/2` Output Shape

```elixir
%{
  metadata: %{path, timestamp, total_files},
  pr_summary: %{                          # nil when no base_results
    base_score: integer(),
    head_score: integer(),
    score_delta: integer(),               # head - base
    base_grade: String.t(),
    head_grade: String.t(),
    blocks_flagged: integer(),            # derived: Enum.sum(Enum.map(top_blocks, &length(&1.blocks)))
    files_changed: integer(),
    files_added: integer(),
    files_modified: integer()
  },
  overall_score: integer(),
  overall_grade: String.t(),
  codebase_delta: map() | nil,            # nil when no base_results
  categories: [category_map],             # worst_offenders removed from each
  top_issues: [behavior_map],
  top_blocks: [file_block_group]          # new
}
```

### `pr_summary` Computation Notes

- `base_score` / `base_grade`: requires running the full grading pipeline on `base_results` (same `Grader.grade_aggregate` + `Grader.overall_score` calls as for head). This is a second pass over base data — not a shortcut.
- `blocks_flagged`: computed after `top_blocks` is assembled (sum of all blocks across all file groups).
- `files_added` / `files_modified`: counted from `changed_files` structs (`:status` field).

### `top_blocks` Shape

```elixir
[
  %{
    path: String.t(),
    status: "added" | "modified" | nil,  # nil when no base_results (no --base-ref)
    blocks: [
      %{
        start_line: integer(),
        end_line: integer(),
        type: String.t(),                 # "code" | "doc" | "typespec"
        token_count: integer(),
        potentials: [
          %{
            category: String.t(),
            behavior: String.t(),
            cosine_delta: float(),
            severity: :critical | :high | :medium,
            fix_hint: String.t() | nil    # nil if not defined for that behavior
          }
        ]
      }
    ]
  }
]
```

### Severity Computation

Severity is computed during `top_blocks` assembly in `HealthReport.generate/2`, not in `BlockImpactAnalyzer`. The baseline codebase cosine scores are already available via `SampleRunner.diagnose_aggregate(baseline_codebase_agg, top: 99_999, languages: project_langs)` — the same call already made for `top_issues`. Pass these as a lookup map `%{{category, behavior} => codebase_cosine}` into the block assembly step.

For each `{behavior, cosine_delta}` on a block:

```
codebase_cosine = lookup codebase cosine for that {category, behavior}
                  (default to 0.0 if behavior not found in codebase diagnose)
gap = max(0.01, 1.0 - codebase_cosine)   # floor prevents division by zero
severity_ratio = cosine_delta / gap       # fraction of existing gap this block causes

:critical  when severity_ratio > 0.50
:high      when severity_ratio > 0.25
:medium    when severity_ratio > 0.10
(filtered) when severity_ratio <= 0.10   (below significance, not shown)
```

**Note on thresholds:** These are initial defaults. The gap-relative formula means a block with `cosine_delta = 0.12` may be `:critical` in a healthy codebase (small gap) and `:medium` in a poor one (large gap). This is intentional — severity reflects impact relative to where the codebase currently stands. Thresholds should be validated against real codebases and are configurable in future iterations.

### Fix Hint Enrichment

Fix hints are sourced from the combined_metrics YAMLs (`priv/combined_metrics/<category>.yml`, `_fix_hint` key per behavior). All 12 category YAMLs have `_fix_hint` fields. Enrichment happens during `top_blocks` assembly in `HealthReport.generate/2` using `CombinedMetrics.Scorer.all_yamls()` (compiled at module load time). Pattern mirrors the existing `cosine_fix_hint/2` in formatters. If a behavior has no `_fix_hint`, the field is `nil`.

### Block Filtering

A block appears in `top_blocks` when:
- `token_count >= 10` (already guaranteed by BlockImpactAnalyzer, but re-checked for safety)
- At least one potential has `severity != filtered` (i.e. `severity_ratio > 0.10`)
- File path is in `changed_files` paths (when `--base-ref` given) or any file (when not)

Blocks within a file are ordered by their highest `cosine_delta` descending.

---

## `BlockImpactAnalyzer` Change: Add `end_line`

The serialized node map in `serialize_node/9` (`block_impact_analyzer.ex:167-175`) currently omits `end_line`. Add it:

```elixir
%{
  "start_line"  => node.start_line,
  "end_line"    => node.end_line,       # ADD THIS
  "column_start" => ...,
  ...
}
```

The `Node` struct already has `end_line` — this is a one-line addition. The existing test in `block_impact_analyzer_test.exs` must also assert `Map.has_key?(node, "end_line")`.

---

## `HealthReport.Delta` Module

New module wrapping delta computation, ported from `Comparator`:

```elixir
@spec compute(base_results :: map(), head_results :: map()) :: map()
def compute(base_results, head_results)
```

Returns per-metric aggregate delta (head minus base), porting `compute_aggregate_delta/2` and `compute_numeric_delta/2` from `Comparator`. File-level deltas are not included (compare-only, now removed).

---

## Formatter Changes

### Removed

- Worst offenders tables in all category sections (both threshold and cosine):
  - `plain.ex`: remove calls at lines 60, 64 and functions `cosine_worst_offenders/2` (91-117), `worst_offenders_section/2` (204-245)
  - `github.ex`: remove calls at lines 249, 381 and functions `cosine_worst_offenders/2` (254-304), `worst_offenders/2` (384-435)
- All compare-command formatting code (`lib/codeqa/formatter.ex` deleted)

### Added

**1. PR Impact Summary** (top of report, only when `pr_summary` present; omitted entirely when nil)

```
Score: B+ → C  |  Δ −8 pts  |  6 blocks flagged across 3 files  |  4 modified, 1 added
```

**2. Delta Bar Graphs** (after PR summary, before categories; only when `codebase_delta` present)

Bar graphs per major category (complexity, readability, duplication, structure) showing base vs head values. Port `progress_bars/2` and `mermaid_chart/1` logic from `lib/codeqa/formatter.ex`. Plain formatter uses ASCII, GitHub formatter uses mermaid.

**3. Block Section** (after top_issues)

```
## Blocks  (6 flagged across 3 files)

### path/to/file.ex  [modified]

**lines 42–67** · function · 84 tokens
  🔴 CRITICAL  function_design / cyclomatic_complexity_under_10  (Δ 0.41)
    → Break this function into smaller single-responsibility functions.
  🟠 HIGH      structure / deep_nesting  (Δ 0.18)
    → Flatten nested conditionals using early returns or pattern matching.

**lines 120–134** · code · 31 tokens
  🟡 MEDIUM    naming / identifier_length  (Δ 0.12)
    → Use descriptive names that convey intent without abbreviation.
```

Severity icons: 🔴 CRITICAL, 🟠 HIGH, 🟡 MEDIUM.
GitHub formatter wraps each file in a `<details><summary>` block (consistent with how categories are already wrapped in `github.ex:137-195`).

---

## Deletions

The following files are deleted as part of this work (all confirmed compare-only, no health-report dependencies):

- `lib/codeqa/cli/compare.ex`
- `lib/codeqa/comparator.ex`
- `lib/codeqa/formatter.ex`
- `lib/codeqa/summarizer.ex`
- `test/codeqa/cli_compare_test.exs`

---

## Testing

### New tests required

- Unit tests for `HealthReport.Delta.compute/2`
- Unit tests for severity computation: all three thresholds, filter boundary, gap floor (gap=0 → floored to 0.01), behavior not found in codebase diagnose (default 0.0)
- Unit tests for `top_blocks` assembly: filtering by token_count, severity, changed_files; ordering by cosine_delta; fix_hint inclusion and nil case
- Unit tests for PR summary computation: score/grade computation from base+head, blocks_flagged derivation, file status counts
- Integration test: `HealthReport.generate/2` with and without `base_results` — verify output keys present/nil correctly
- Formatter tests: block section renders correctly for plain and github formats; pr_summary nil omits summary and delta sections gracefully
- CLI test: `--base-ref` wires through to `Git.collect_files_at_ref`, `Git.changed_files`, and `HealthReport.generate` correctly
- `BlockImpactAnalyzer` test: assert `end_line` present in serialized node

### Tests to delete

- `test/codeqa/cli_compare_test.exs` (entire file)
- `test/codeqa/health_report/formatter_test.exs:186-194` — "includes worst offenders section"
- `test/codeqa/health_report/formatter_test.exs:216-226` — "renders cosine worst offenders per behavior"

### Tests to update

- `test/codeqa/health_report/formatter_test.exs:196-200` — "summary detail omits category sections" (refute reason changes)
- Any test referencing `worst_offenders` in the generate output shape
- `test/codeqa/block_impact_analyzer_test.exs` — add `end_line` assertion

---

## Out of Scope

- Per-block raw metric values (blocks carry cosine_delta only, not raw metrics)
- File-level delta details (compare's per-file before/after table is dropped)
- Near-duplicate block pairs in the block section (they exist as metrics but are not surfaced here)
- Relative severity across blocks (no "this block is Nx worse than average block")
- Configurable severity thresholds (hardcoded defaults for now; future iteration)
