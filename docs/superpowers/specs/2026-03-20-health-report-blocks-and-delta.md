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
| `CLI.Compare` | **Deleted** |
| `Comparator` | **Deleted** (logic moved to `HealthReport.Delta`) |
| Compare-specific `Formatter` | **Deleted** |
| `Summarizer` | **Deleted** if compare-only (verify at implementation time) |

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
        changed_files: [path, ...])
```

### Without `--base-ref`

```
CLI.HealthReport
  ├── Analyzer.analyze_codebase(files_map) → results
  ├── BlockImpactAnalyzer.analyze(results, files_map) → results_with_nodes
  └── HealthReport.generate(results_with_nodes)
      (no delta, blocks shown for all files with significant impact)
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
    blocks_flagged: integer(),            # total blocks above threshold
    files_changed: integer(),
    files_added: integer(),
    files_modified: integer()
  },
  overall_score: integer(),
  overall_grade: String.t(),
  codebase_delta: map() | nil,            # nil when no base_results
  categories: [category_map],            # worst_offenders removed from each
  top_issues: [behavior_map],
  top_blocks: [file_block_group]         # new
}
```

### `top_blocks` Shape

```elixir
[
  %{
    path: String.t(),
    status: "added" | "modified" | nil,  # nil when no base_results
    blocks: [
      %{
        start_line: integer(),
        end_line: integer(),             # derived from node
        type: String.t(),               # "code" | "doc" | "typespec"
        token_count: integer(),
        potentials: [
          %{
            category: String.t(),
            behavior: String.t(),
            cosine_delta: float(),
            severity: :critical | :high | :medium,
            fix_hint: String.t()         # from behavior definition
          }
        ]
      }
    ]
  }
]
```

### Severity Computation

For each `{behavior, cosine_delta}` on a block:

```
codebase_cosine = current codebase cosine score for that behavior
gap = 1.0 - codebase_cosine           # how far below ideal the codebase already is
severity_ratio = cosine_delta / gap   # what fraction of existing gap this block causes

:critical  when severity_ratio > 0.50
:high      when severity_ratio > 0.25
:medium    when severity_ratio > 0.10
(filtered) when severity_ratio <= 0.10  (below significance, not shown)
```

`gap` is floored at `0.01` to avoid division by zero when the codebase already scores perfectly on a behavior.

### Block Filtering

A block appears in `top_blocks` when:
- `token_count >= 10`
- At least one potential has `severity != filtered` (i.e. `severity_ratio > 0.10`)
- File is in `changed_files` (when `--base-ref` given) or any file (when not)

Blocks within a file are ordered by their highest `cosine_delta` descending.

---

## `HealthReport.Delta` Module

New module wrapping delta computation, ported from `Comparator`:

```elixir
@spec compute(base_results :: map(), head_results :: map()) :: map()
def compute(base_results, head_results)
```

Returns per-metric aggregate delta (head minus base), same shape as `Comparator.compare_results/3` currently produces for the `"codebase"` key. File-level deltas are not included (that was compare-only, now removed).

---

## Fix Hints per Behavior

Fix hints are sourced from the combined_metrics YAML behavior definitions. The `SampleRunner` / `CombinedMetrics` modules are responsible for resolving a `{category, behavior}` key to its fix_hint string. If no fix_hint is defined for a behavior, the field is omitted from the potential map.

Implementation note: verify at implementation time whether fix_hint is already present in the YAML behavior definitions or needs to be added.

---

## Formatter Changes

### Removed

- Worst offenders tables in all category sections (both threshold and cosine)
- All compare-command formatting code

### Added

**1. PR Impact Summary** (top of report, only when `pr_summary` present)

```
Score: B+ → C  |  Δ −8 pts  |  6 blocks flagged across 3 files  |  4 modified, 1 added
```

**2. Delta Bar Graphs** (after PR summary, before categories; only when `codebase_delta` present)

Bar graphs per major category (complexity, readability, duplication, structure) showing base vs head values. Ported from compare's GitHub formatter. Plain formatter uses ASCII, GitHub formatter uses mermaid.

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
GitHub formatter wraps each file in a `<details>` block.

---

## Deletions

The following files are deleted as part of this work:

- `lib/codeqa/cli/compare.ex`
- `lib/codeqa/comparator.ex`
- `lib/codeqa/formatter.ex` (compare formatter — verify no health-report usage first)
- `lib/codeqa/summarizer.ex` (verify compare-only before deleting)
- All compare-related tests

---

## Testing

- Unit tests for `HealthReport.Delta.compute/2`
- Unit tests for severity computation (all three thresholds + filter boundary)
- Unit tests for `top_blocks` assembly (filtering, ordering, fix_hint inclusion)
- Unit tests for PR summary computation
- Integration test: `HealthReport.generate/2` with and without `base_results`
- Formatter tests: block section renders correctly for plain and github formats
- CLI test: `--base-ref` wires through to git calls and generate correctly
- Deletion verification: no references to deleted modules remain

---

## Out of Scope

- Per-block raw metric values (blocks carry cosine_delta only, not raw metrics)
- File-level delta details (compare's per-file before/after table is dropped)
- Near-duplicate block pairs in the block section (they exist as metrics but are not surfaced here)
- Relative severity across blocks (no "this block is Nx worse than average block")
