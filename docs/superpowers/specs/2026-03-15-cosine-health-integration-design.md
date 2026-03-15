# Design: Cosine Health Integration, Impact Weights & Diagnose CLI

**Date:** 2026-03-15
**Branch:** feat/auto-load-codeqa-config
**Status:** Approved

---

## Overview

Three coordinated changes:

1. **Combined metrics become graded health categories** — each of the 12 combined-metric YAML categories becomes a proper graded category in the health report, scored via cosine similarity (higher = better, breakpoint-based 0–100 mapping)
2. **Impact-weighted overall score** — all categories (existing threshold-based + new cosine-based) carry a configurable `impact` value; overall score is a weighted average
3. **`diagnose` CLI command** — exposes file/directory cosine analysis as a first-class CLI command with aggregate and per-file modes

---

## 1. Grader Extension

### 1.1 Cosine Scoring

`Grader.score_cosine/1` maps cosine [-1, +1] → [0, 100] with linear interpolation within bands:

| Cosine range | Score range | Approx. grade |
|---|---|---|
| [0.5, 1.0] | [90, 100] | A |
| [0.2, 0.5) | [70, 90) | B |
| [0.0, 0.2) | [50, 70) | C |
| [-0.3, 0.0) | [30, 50) | D |
| [-1.0, -0.3) | [0, 30) | F |

Actual letter grades (A+, B-, C+, etc.) are determined by passing the 0–100 score through the existing `grade_letter/2` with the default 15-step grade scale, consistent with threshold-based categories.

Category score = arithmetic mean of behavior scores within that category.

### 1.2 Worst Files Per Behavior

**New module: `CodeQA.CombinedMetrics.FileScorer`**

Responsibility: compute per-file cosine scores for each combined-metric behavior.

```elixir
@spec worst_files_per_behavior(map(), keyword()) ::
  %{String.t() => [%{file: String.t(), cosine: float()}]}
```

Input: `analysis_results["files"]` — map of `%{path => %{"metrics" => %{group => %{key => value}}}}`.

**Key format handling:** Each file's raw metrics use non-prefixed keys (e.g. `tokens`, `effort`). The existing `Scorer.compute_score/3` and cosine logic expect aggregate-format keys (`mean_tokens`, `mean_effort`). To reuse the existing scalar/cosine computation without duplication, `FileScorer` wraps each file's metrics into a single-file aggregate:

```elixir
defp file_to_aggregate(file_metrics) do
  Map.new(file_metrics, fn {group, keys} ->
    {group, Map.new(keys, fn {k, v} -> {"mean_#{k}", v} end)}
  end)
end
```

This synthetic aggregate is then passed to the existing `SampleRunner` cosine logic per file.

Returns a map keyed by `"category.behavior"` with a list of `%{file, cosine}` sorted ascending (most negative first), truncated to `combined_top` entries.

### 1.3 Unified Category Shape

Both threshold-based and cosine-based categories share the same shape in the report, distinguished by a `type` field:

**Threshold category (existing, unchanged internally):**
```elixir
%{
  type: :threshold,
  key: "complexity",
  name: "Complexity",
  score: 72,
  grade: "B",
  impact: 5,
  summary: "Good overall, 1 metric(s) need attention",
  metric_scores: [...],
  worst_offenders: [...]
}
```

**Cosine category (new):**
```elixir
%{
  type: :cosine,
  key: "function_design",
  name: "Function Design",
  score: 64,
  grade: "C",
  impact: 4,
  behaviors: [
    %{
      behavior: "no_boolean_parameter",
      cosine: 0.12,
      score: 56,
      grade: "C",
      worst_offenders: [
        %{file: "lib/foo/bar.ex", cosine: -0.71},
        %{file: "lib/foo/baz.ex", cosine: -0.44}
      ]
    }
  ]
}
```

Both are appended into the single `categories` list in the report map. The separate `combined_categories` key is removed. Formatters pattern-match on `type` to select the correct rendering path.

---

## 2. Impact-Weighted Overall Score

### 2.1 Formula

```
overall_score = Σ(score_i × impact_i) / Σ(impact_i)
```

Only relative ratios of `impact` values matter — doubling all values changes nothing.

### 2.2 `overall_score/3` Signature

```elixir
@spec overall_score(
  categories :: [map()],
  grade_scale :: [{number(), String.t()}],
  impact_map :: %{String.t() => pos_integer()}
) :: {integer(), String.t()}
```

Each category's impact is looked up from `impact_map` by `category.key`, defaulting to `1` if the key is absent. This means `Config.load/1` does not need to discover combined category keys upfront — the default-1 fallback lives in the lookup at score time.

### 2.3 Defaults

| Category key | Impact | Reasoning |
|---|---|---|
| complexity | 5 | Core maintainability signal |
| file_structure | 4 | Architecture debt is costly |
| function_design | 4 | Directly affects readability |
| code_smells | 3 | Strong quality signal |
| naming_conventions | 2 | |
| error_handling | 2 | |
| consistency | 2 | |
| documentation | 1 | Hard to measure accurately |
| testing | 1 | Proxy metrics only |
| *(all combined metric categories)* | 1 | Default; override in config |

### 2.4 Config (`.codeqa.yml`)

```yaml
impact:
  complexity: 5
  file_structure: 4
  function_design: 4
  code_smells: 3
  naming_conventions: 2
  error_handling: 2
  consistency: 2
  documentation: 1
  testing: 1
  # combined categories override example:
  # variable_naming: 2

combined_top: 2   # worst offender files per combined-metric behavior
```

`Config.load/1` merges user-provided impact values over the default map. The merged map is passed through to `overall_score/3`.

Updated return type:

```elixir
@spec load(String.t() | nil) :: %{
  categories: [map()],
  grade_scale: [{number(), String.t()}],
  impact_map: %{String.t() => pos_integer()},
  combined_top: pos_integer()
}
```

`load(nil)` returns the default impact map (Section 2.3 table) and `combined_top: 2`.

---

## 3. `diagnose` CLI Command

### 3.1 Usage

```
codeqa diagnose --path <file-or-dir> [options]

Options:
  --mode aggregate      Treat directory as one codebase aggregate (default)
  --mode per-file       Score each file individually
  --top N               Top issues to show per result (default: 15)
  --format plain|json   Output format (default: plain)
  --combined-top N      Worst offender files per behavior (default: 2)
```

Note: `--path` is used (not `--file`) for consistency with other CLI commands.

Single files are accepted in both modes — for a single file, aggregate and per-file produce the same result.

### 3.2 Module: `CodeQA.Diagnostics`

Named `Diagnostics` to match the project's agent-noun convention (`Analyzer`, `Collector`, `Comparator`).

Thin wrapper — no new analysis logic:

```
--path <file or directory>
  ↓
CodeQA.Diagnostics.run/1
  ├── mode: :aggregate
  │     → collect files → Analyzer.analyze_codebase → aggregate map
  │     → SampleRunner.diagnose_aggregate(aggregate, top: N)
  │     → SampleRunner.score_aggregate(aggregate)
  │     → render top issues + category breakdown
  │
  └── mode: :per_file
        → collect files → for each file: FileScorer.file_to_aggregate
        → SampleRunner.diagnose_aggregate(file_agg, top: N) per file
        → render table: file | behavior | cosine | score
          (sorted by worst cosine per file, --top N behaviors shown per file)
```

### 3.3 Per-File Output Format

```
## Diagnose: per-file

| File | Behavior | Cosine | Score |
|------|----------|--------|-------|
| lib/foo/bar.ex | function_design.no_boolean_parameter | -0.71 | 32 |
| lib/foo/bar.ex | code_smells.long_method | -0.44 | 41 |
| lib/foo/baz.ex | naming_conventions.name_is_generic | -0.62 | 28 |
...
```

Top `--top N` behaviors shown per file (default 15), sorted per file by cosine ascending.

### 3.4 CLI Routing

New clause in `CodeQA.CLI.main/1`:

```elixir
["diagnose" | rest] -> handle_diagnose(rest)
```

`handle_diagnose/1` parses flags and delegates to `CodeQA.Diagnostics.run/1`.

---

## 4. Formatter Updates

### 4.1 Health Report Table

Add `Impact` column to the overall summary table:

```
| Category | Grade | Score | Impact | Summary |
```

### 4.2 Cosine Legend

Append below the report header (before the summary table):

> *Combined metric scores use cosine similarity: +1 = metric profile perfectly matches healthy pattern for this behavior, 0 = no signal, −1 = anti-pattern detected. Mapped to 0–100 using breakpoints (approx: ≥0.5→A, ≥0.2→B, ≥0.0→C, ≥−0.3→D, <−0.3→F); actual letter grades use the full 15-step scale.*

### 4.3 Category Section Rendering

Formatters pattern-match on `category.type`:

- `:threshold` → existing rendering (metric_scores table, worst offenders by file score)
- `:cosine` → new rendering: behavior table with cosine + score + grade, worst offenders per behavior

Cosine category section:
```
## Function Design — C

> Cosine similarity scores for 14 behaviors.

| Behavior | Cosine | Score | Grade |
|----------|--------|-------|-------|
| no_boolean_parameter | 0.12 | 56 | C |
| ... |

### Worst Offenders: no_boolean_parameter

| File | Cosine |
|------|--------|
| lib/foo/bar.ex | -0.71 |
| lib/foo/baz.ex | -0.44 |
```

### 4.4 GitHub Formatter

Same changes as plain formatter. Cosine category sections use `<details>` collapsible blocks, same as existing combined category rendering.

### 4.5 Removed

The separate `top_issues` section (currently rendered as "## Top Likely Issues") is kept as-is — it still provides the codebase-level worst behaviors ranked by cosine, which is a useful quick summary distinct from the per-category breakdown.

The separate `combined_categories` key is removed from the report map; those categories are now in `categories`.

---

## 5. Data Flow

```
HealthReport.generate/2
  ├── Config.load/1
  │     → threshold categories + grade_scale + impact_map + combined_top
  │
  ├── Grader.grade_aggregate/3
  │     → threshold category grades [{type: :threshold, key, score, impact, ...}]
  │
  ├── FileScorer.worst_files_per_behavior/2
  │     → %{"category.behavior" => [{file, cosine}]}
  │
  ├── Grader.grade_cosine_categories/3  (new, in Grader alongside grade_aggregate/3)
  │     → cosine category grades [{type: :cosine, key, score, impact, behaviors: [...]}]
  │
  ├── categories = threshold_grades ++ cosine_grades
  │
  ├── SampleRunner.diagnose_aggregate/2   (unchanged, for top_issues)
  │
  └── Grader.overall_score/3
        → weighted by impact_map, default 1 for missing keys
```

---

## 6. Files Changed

| File | Change |
|---|---|
| `lib/codeqa/health_report.ex` | Orchestrate FileScorer, grade_cosine_categories; merge into single categories list; remove combined_categories key; pass impact_map to overall_score/3 |
| `lib/codeqa/health_report/config.ex` | Load `impact` (merge with defaults) and `combined_top` from YAML |
| `lib/codeqa/health_report/grader.ex` | Add `score_cosine/1`; update `overall_score/2` → `/3` with impact_map; add `grade_cosine_categories/3` |
| `lib/codeqa/combined_metrics/file_scorer.ex` | New module: `worst_files_per_behavior/2`, `file_to_aggregate/1` |
| `lib/codeqa/diagnostics.ex` | New module: CLI diagnose logic (aggregate + per-file modes) |
| `lib/codeqa/cli.ex` | Add `diagnose` command routing |
| `lib/codeqa/health_report/formatter/plain.ex` | Impact column; cosine legend; type-based category rendering; remove combined_metric_sections |
| `lib/codeqa/health_report/formatter/github.ex` | Same formatter updates |
| `.codeqa.yml` | Add `impact:` and `combined_top:` with documented defaults |
| `test/codeqa/health_report/grader_test.exs` | Tests for `score_cosine/1`, weighted `overall_score/3`, `grade_cosine_categories/3` |
| `test/codeqa/health_report/config_test.exs` | Tests for impact + combined_top loading and default merging |
| `test/codeqa/combined_metrics/file_scorer_test.exs` | Tests for `worst_files_per_behavior/2`, `file_to_aggregate/1` |
| `test/codeqa/diagnostics_test.exs` | Tests for `Diagnostics.run/1` aggregate and per-file modes |

---

## 7. Out of Scope

- Per-metric baseline storage for size-invariant cosine (noted as future work in session summary)
- Modifying scalar calibration (`--apply-scalars`) workflow
- Changing the `top_issues` section (kept as-is)
