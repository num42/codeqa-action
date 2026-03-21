# Health Report: Block Impact, PR Delta, and Compare Consolidation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify health-report and compare commands into a single PR-aware report showing impactful blocks per changed file, before/after metric delta, and a PR impact summary — while deleting the compare command entirely.

**Architecture:** `HealthReport.generate/2` gains `base_results:` and `changed_files:` opts; a new `HealthReport.TopBlocks` module assembles severity-classified blocks from node data; a new `HealthReport.Delta` module wraps aggregate delta computation ported from `Comparator`; formatters gain PR summary, delta, and block sections and lose worst_offenders rendering; `CLI.HealthReport` gains `--base-ref`/`--head-ref` and runs dual analysis when provided.

**Tech Stack:** Elixir, ExUnit, `CodeQA.Git`, `CodeQA.CombinedMetrics.{SampleRunner, Scorer}`, `CodeQA.HealthReport.Grader`, `CodeQA.BlockImpactAnalyzer`

---

## File Map

| File | Change |
|------|--------|
| `lib/codeqa/block_impact_analyzer.ex` | Add `"end_line"` to `serialize_node/9` output |
| `lib/codeqa/health_report/delta.ex` | **Create** — aggregate delta computation (ported from `Comparator`) |
| `lib/codeqa/health_report/top_blocks.ex` | **Create** — block assembly, severity, fix hint enrichment |
| `lib/codeqa/health_report.ex` | Accept new opts, wire `Delta` + `TopBlocks`, drop `worst_offenders` computation |
| `lib/codeqa/health_report/formatter/plain.ex` | Remove worst_offenders rendering; add PR summary, delta table, block section |
| `lib/codeqa/health_report/formatter/github.ex` | Remove worst_offenders rendering; add PR summary, delta table, block section |
| `lib/codeqa/cli/health_report.ex` | Add `--base-ref`/`--head-ref`; dual analysis when base-ref given |
| `lib/codeqa/cli.ex` | Remove compare entry |
| `lib/codeqa/cli/compare.ex` | **Delete** |
| `lib/codeqa/comparator.ex` | **Delete** |
| `lib/codeqa/formatter.ex` | **Delete** |
| `lib/codeqa/summarizer.ex` | **Delete** |
| `test/codeqa/block_impact_analyzer_test.exs` | Add `end_line` assertion |
| `test/codeqa/health_report/delta_test.exs` | **Create** |
| `test/codeqa/health_report/top_blocks_test.exs` | **Create** |
| `test/codeqa/health_report_test.exs` | Add: `top_blocks`, `pr_summary`, `codebase_delta` keys; remove worst_offenders assertions |
| `test/codeqa/health_report/formatter_test.exs` | Delete worst_offenders tests; add block/delta/summary tests |
| `test/codeqa/cli_compare_test.exs` | **Delete** |

---

## Task 1: Add `end_line` to BlockImpactAnalyzer node serialization

**Files:**
- Modify: `lib/codeqa/block_impact_analyzer.ex:167-175`
- Test: `test/codeqa/block_impact_analyzer_test.exs:42-52`

- [ ] **Step 1: Add `end_line` assertion to the existing "each node has required fields" test**

In `test/codeqa/block_impact_analyzer_test.exs`, inside the `Enum.each(nodes, fn node ->` block (line 42), add after line 43:

```elixir
assert Map.has_key?(node, "end_line")
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
mix test test/codeqa/block_impact_analyzer_test.exs --trace
```

Expected: FAIL — `"end_line"` key missing.

- [ ] **Step 3: Add `end_line` to the serialized node map**

In `lib/codeqa/block_impact_analyzer.ex`, edit the map at line 167:

```elixir
%{
  "start_line" => node.start_line,
  "end_line" => node.end_line,
  "column_start" => (first_token && first_token.col) || 0,
  "char_length" => char_length,
  "type" => Atom.to_string(node.type),
  "token_count" => length(node.tokens),
  "refactoring_potentials" => potentials,
  "children" => children
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
mix test test/codeqa/block_impact_analyzer_test.exs --trace
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/codeqa/block_impact_analyzer.ex test/codeqa/block_impact_analyzer_test.exs
git commit -m "feat(block-impact): serialize end_line in node output"
```

---

## Task 2: Create `HealthReport.Delta`

**Files:**
- Create: `lib/codeqa/health_report/delta.ex`
- Create: `test/codeqa/health_report/delta_test.exs`

- [ ] **Step 1: Write the test file**

```elixir
# test/codeqa/health_report/delta_test.exs
defmodule CodeQA.HealthReport.DeltaTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Delta

  defp make_results(aggregate) do
    %{"codebase" => %{"aggregate" => aggregate}}
  end

  test "returns base, head, and delta aggregates" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0}})
    head = make_results(%{"entropy" => %{"mean_value" => 6.0}})

    result = Delta.compute(base, head)

    assert result.base.aggregate == %{"entropy" => %{"mean_value" => 5.0}}
    assert result.head.aggregate == %{"entropy" => %{"mean_value" => 6.0}}
    assert result.delta.aggregate == %{"entropy" => %{"mean_value" => 1.0}}
  end

  test "rounds delta to 4 decimal places" do
    base = make_results(%{"entropy" => %{"mean_value" => 1.0}})
    head = make_results(%{"entropy" => %{"mean_value" => 4.3333}})

    result = Delta.compute(base, head)
    assert result.delta.aggregate["entropy"]["mean_value"] == 3.3333
  end

  test "handles missing base codebase gracefully" do
    base = %{}
    head = make_results(%{"entropy" => %{"mean_value" => 6.0}})

    result = Delta.compute(base, head)
    assert result.delta.aggregate == %{}
  end

  test "handles missing head codebase gracefully" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0}})
    head = %{}

    result = Delta.compute(base, head)
    assert result.delta.aggregate == %{}
  end

  test "skips non-numeric metric keys" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0, "label" => "x"}})
    head = make_results(%{"entropy" => %{"mean_value" => 6.0, "label" => "y"}})

    result = Delta.compute(base, head)
    refute Map.has_key?(result.delta.aggregate["entropy"], "label")
    assert result.delta.aggregate["entropy"]["mean_value"] == 1.0
  end
end
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
mix test test/codeqa/health_report/delta_test.exs --trace
```

Expected: FAIL — module not found.

- [ ] **Step 3: Create the module**

```elixir
# lib/codeqa/health_report/delta.ex
defmodule CodeQA.HealthReport.Delta do
  @moduledoc "Computes aggregate metric delta between two codebase analysis results."

  @spec compute(map(), map()) :: %{
          base: %{aggregate: map()},
          head: %{aggregate: map()},
          delta: %{aggregate: map()}
        }
  def compute(base_results, head_results) do
    base_agg = get_in(base_results, ["codebase", "aggregate"]) || %{}
    head_agg = get_in(head_results, ["codebase", "aggregate"]) || %{}

    %{
      base: %{aggregate: base_agg},
      head: %{aggregate: head_agg},
      delta: %{aggregate: compute_aggregate_delta(base_agg, head_agg)}
    }
  end

  defp compute_aggregate_delta(base_agg, head_agg) do
    MapSet.new(Map.keys(base_agg) ++ Map.keys(head_agg))
    |> Enum.reduce(%{}, fn metric_name, acc ->
      base_m = Map.get(base_agg, metric_name, %{})
      head_m = Map.get(head_agg, metric_name, %{})
      delta = compute_numeric_delta(base_m, head_m)
      if delta == %{}, do: acc, else: Map.put(acc, metric_name, delta)
    end)
  end

  defp compute_numeric_delta(base, head) do
    MapSet.new(Map.keys(base) ++ Map.keys(head))
    |> Enum.reduce(%{}, fn key, acc ->
      case {Map.get(base, key), Map.get(head, key)} do
        {b, h} when is_number(b) and is_number(h) ->
          Map.put(acc, key, Float.round(h - b, 4))

        _ ->
          acc
      end
    end)
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
mix test test/codeqa/health_report/delta_test.exs --trace
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/codeqa/health_report/delta.ex test/codeqa/health_report/delta_test.exs
git commit -m "feat(health-report): add Delta module for aggregate metric comparison"
```

---

## Task 3: Create `HealthReport.TopBlocks`

**Files:**
- Create: `lib/codeqa/health_report/top_blocks.ex`
- Create: `test/codeqa/health_report/top_blocks_test.exs`

- [ ] **Step 1: Write the test file**

```elixir
# test/codeqa/health_report/top_blocks_test.exs
defmodule CodeQA.HealthReport.TopBlocksTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.TopBlocks
  alias CodeQA.Git.ChangedFile

  # A node with cosine_delta 0.60 — will be :critical when codebase_cosine = 0.0 (gap=1.0, ratio=0.60)
  defp make_node(cosine_delta, token_count \\ 20) do
    %{
      "start_line" => 1,
      "end_line" => 10,
      "type" => "code",
      "token_count" => token_count,
      "refactoring_potentials" => [
        %{
          "category" => "function_design",
          "behavior" => "cyclomatic_complexity_under_10",
          "cosine_delta" => cosine_delta
        }
      ],
      "children" => []
    }
  end

  defp make_results(nodes) do
    %{"files" => %{"lib/foo.ex" => %{"nodes" => nodes}}}
  end

  defp lookup(cosine \\ 0.0) do
    %{{"function_design", "cyclomatic_complexity_under_10"} => cosine}
  end

  describe "severity classification" do
    test ":critical when severity_ratio > 0.50" do
      # gap = max(0.01, 1.0 - 0.0) = 1.0, ratio = 0.60 / 1.0 = 0.60 > 0.50
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :critical
    end

    test ":high when severity_ratio > 0.25 and <= 0.50" do
      # ratio = 0.30 / 1.0 = 0.30
      [group] = TopBlocks.build(make_results([make_node(0.30)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :high
    end

    test ":medium when severity_ratio > 0.10 and <= 0.25" do
      # ratio = 0.15 / 1.0 = 0.15
      [group] = TopBlocks.build(make_results([make_node(0.15)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :medium
    end

    test "filtered when severity_ratio <= 0.10" do
      # ratio = 0.05 / 1.0 = 0.05 — block should not appear
      assert TopBlocks.build(make_results([make_node(0.05)]), [], lookup()) == []
    end

    test "gap floor prevents division by zero when codebase_cosine = 1.0" do
      # gap = max(0.01, 1.0 - 1.0) = 0.01, ratio = 0.02 / 0.01 = 2.0 → :critical
      [group] = TopBlocks.build(make_results([make_node(0.02)]), [], lookup(1.0))
      assert hd(hd(group.blocks).potentials).severity == :critical
    end

    test "gap handles negative codebase_cosine" do
      # codebase_cosine = -0.5, gap = max(0.01, 1.0 - (-0.5)) = 1.5
      # ratio = 0.60 / 1.5 = 0.40 → :high
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup(-0.5))
      assert hd(hd(group.blocks).potentials).severity == :high
    end

    test "unknown behavior defaults codebase_cosine to 0.0" do
      lookup_empty = %{}
      # gap = 1.0, ratio = 0.60 → :critical
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup_empty)
      assert hd(hd(group.blocks).potentials).severity == :critical
    end
  end

  describe "changed_files filtering" do
    test "when changed_files is empty, shows all files" do
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert group.path == "lib/foo.ex"
      assert group.status == nil
    end

    test "when changed_files given, only shows matching files" do
      changed = [%ChangedFile{path: "lib/other.ex", status: "added"}]
      assert TopBlocks.build(make_results([make_node(0.60)]), changed, lookup()) == []
    end

    test "status comes from ChangedFile struct" do
      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]
      [group] = TopBlocks.build(make_results([make_node(0.60)]), changed, lookup())
      assert group.status == "modified"
    end
  end

  describe "block filtering" do
    test "blocks with token_count < 10 are excluded" do
      assert TopBlocks.build(make_results([make_node(0.60, 9)]), [], lookup()) == []
    end

    test "blocks are ordered by highest cosine_delta descending" do
      node_low = make_node(0.20)
      node_high = put_in(make_node(0.60), ["start_line"], 20)
      results = %{"files" => %{"lib/foo.ex" => %{"nodes" => [node_low, node_high]}}}

      [group] = TopBlocks.build(results, [], lookup())
      deltas = Enum.map(group.blocks, fn b -> hd(b.potentials).cosine_delta end)
      assert deltas == Enum.sort(deltas, :desc)
    end

    test "children nodes are included" do
      parent = %{
        "start_line" => 1, "end_line" => 20,
        "type" => "code", "token_count" => 5,
        "refactoring_potentials" => [],
        "children" => [make_node(0.60)]
      }
      [group] = TopBlocks.build(make_results([parent]), [], lookup())
      assert length(group.blocks) == 1
    end
  end

  describe "fix hints" do
    test "includes fix_hint string for known behavior" do
      # function_design/cyclomatic_complexity_under_10 has _fix_hint in YAML
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      potential = hd(hd(group.blocks).potentials)
      assert is_binary(potential.fix_hint)
    end

    test "fix_hint is nil for unknown behavior" do
      node = %{
        "start_line" => 1, "end_line" => 10, "type" => "code",
        "token_count" => 20,
        "refactoring_potentials" => [
          %{"category" => "unknown_cat", "behavior" => "unknown_beh", "cosine_delta" => 0.60}
        ],
        "children" => []
      }
      [group] = TopBlocks.build(make_results([node]), [], %{})
      assert hd(hd(group.blocks).potentials).fix_hint == nil
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
mix test test/codeqa/health_report/top_blocks_test.exs --trace
```

Expected: FAIL — module not found.

- [ ] **Step 3: Create the module**

```elixir
# lib/codeqa/health_report/top_blocks.ex
defmodule CodeQA.HealthReport.TopBlocks do
  @moduledoc "Assembles the top_blocks report section from analysis node data."

  alias CodeQA.CombinedMetrics.Scorer

  @min_tokens 10
  @severity_critical 0.50
  @severity_high 0.25
  @severity_medium 0.10
  @gap_floor 0.01

  @spec build(map(), [struct()], map()) :: [map()]
  def build(analysis_results, changed_files, codebase_cosine_lookup) do
    files = Map.get(analysis_results, "files", %{})
    fix_hints = build_fix_hint_lookup()

    file_entries =
      if changed_files == [] do
        Enum.map(files, fn {path, data} -> {path, nil, data} end)
      else
        changed_index = Map.new(changed_files, &{&1.path, &1.status})

        files
        |> Enum.filter(fn {path, _} -> Map.has_key?(changed_index, path) end)
        |> Enum.map(fn {path, data} -> {path, Map.get(changed_index, path), data} end)
      end

    file_entries
    |> Enum.map(fn {path, status, file_data} ->
      blocks =
        file_data
        |> Map.get("nodes", [])
        |> Enum.flat_map(&collect_nodes/1)
        |> Enum.filter(&(&1["token_count"] >= @min_tokens))
        |> Enum.map(&enrich_block(&1, codebase_cosine_lookup, fix_hints))
        |> Enum.reject(&(&1.potentials == []))
        |> Enum.sort_by(&(-max_delta(&1)))

      %{path: path, status: status, blocks: blocks}
    end)
    |> Enum.reject(&(&1.blocks == []))
    |> Enum.sort_by(& &1.path)
  end

  defp collect_nodes(node) do
    children = node |> Map.get("children", []) |> Enum.flat_map(&collect_nodes/1)
    [node | children]
  end

  defp enrich_block(node, cosine_lookup, fix_hints) do
    potentials =
      node
      |> Map.get("refactoring_potentials", [])
      |> Enum.map(&enrich_potential(&1, cosine_lookup, fix_hints))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.cosine_delta, :desc)

    %{
      start_line: node["start_line"],
      end_line: node["end_line"],
      type: node["type"],
      token_count: node["token_count"],
      potentials: potentials
    }
  end

  defp enrich_potential(p, cosine_lookup, fix_hints) do
    category = p["category"]
    behavior = p["behavior"]
    cosine_delta = p["cosine_delta"]

    codebase_cosine = Map.get(cosine_lookup, {category, behavior}, 0.0)
    gap = max(@gap_floor, 1.0 - codebase_cosine)
    severity = classify(cosine_delta / gap)

    if severity == :filtered do
      nil
    else
      %{
        category: category,
        behavior: behavior,
        cosine_delta: cosine_delta,
        severity: severity,
        fix_hint: Map.get(fix_hints, {category, behavior})
      }
    end
  end

  defp classify(ratio) when ratio > @severity_critical, do: :critical
  defp classify(ratio) when ratio > @severity_high, do: :high
  defp classify(ratio) when ratio > @severity_medium, do: :medium
  defp classify(_ratio), do: :filtered

  defp max_delta(%{potentials: []}), do: 0.0
  defp max_delta(%{potentials: potentials}), do: Enum.max_by(potentials, & &1.cosine_delta).cosine_delta

  defp build_fix_hint_lookup do
    Scorer.all_yamls()
    |> Enum.flat_map(fn {yaml_path, data} ->
      category = yaml_path |> Path.basename() |> String.trim_trailing(".yml")

      Enum.flat_map(data, fn {behavior, behavior_data} ->
        case get_in(behavior_data, ["_fix_hint"]) do
          nil -> []
          hint -> [{{category, behavior}, hint}]
        end
      end)
    end)
    |> Map.new()
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
mix test test/codeqa/health_report/top_blocks_test.exs --trace
```

Expected: all PASS.

- [ ] **Step 5: Run full suite**

```bash
mix test
```

Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/health_report/top_blocks.ex test/codeqa/health_report/top_blocks_test.exs
git commit -m "feat(health-report): add TopBlocks module for severity-classified block assembly"
```

---

## Task 4: Update `HealthReport.generate/2`

**Files:**
- Modify: `lib/codeqa/health_report.ex`
- Modify: `test/codeqa/health_report_test.exs`

- [ ] **Step 1: Add tests for new output keys**

Open `test/codeqa/health_report_test.exs`. Add a describe block (create the file if it doesn't exist):

```elixir
describe "generate/2 output keys" do
  @tag :slow
  test "without base_results: pr_summary and codebase_delta are nil" do
    files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
    results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    results = CodeQA.BlockImpactAnalyzer.analyze(results, files)

    report = CodeQA.HealthReport.generate(results)

    assert report.pr_summary == nil
    assert report.codebase_delta == nil
    assert is_list(report.top_blocks)
    assert Map.has_key?(report, :overall_score)
    assert Map.has_key?(report, :overall_grade)
    assert Map.has_key?(report, :categories)
    assert Map.has_key?(report, :top_issues)
  end

  @tag :slow
  test "without base_results: top_blocks shows all files with significant blocks" do
    files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
    results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    results = CodeQA.BlockImpactAnalyzer.analyze(results, files)

    report = CodeQA.HealthReport.generate(results)

    # top_blocks is a list of file groups (may be empty if no blocks above threshold)
    assert is_list(report.top_blocks)
    Enum.each(report.top_blocks, fn group ->
      assert Map.has_key?(group, :path)
      assert Map.has_key?(group, :status)
      assert Map.has_key?(group, :blocks)
      assert group.status == nil
    end)
  end

  test "worst_offenders is always empty in categories" do
    files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
    results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    results = CodeQA.BlockImpactAnalyzer.analyze(results, files)

    report = CodeQA.HealthReport.generate(results)

    Enum.each(report.categories, fn cat ->
      assert Map.get(cat, :worst_offenders, []) == []
    end)
  end
end

describe "generate/2 with base_results" do
  @tag :slow
  test "pr_summary is populated" do
    files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
    head_results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    head_results = CodeQA.BlockImpactAnalyzer.analyze(head_results, files)
    base_results = CodeQA.Engine.Analyzer.analyze_codebase(files)

    changed = [%CodeQA.Git.ChangedFile{path: "lib/foo.ex", status: "modified"}]

    report = CodeQA.HealthReport.generate(head_results,
      base_results: base_results,
      changed_files: changed
    )

    assert %{
      base_score: base_score,
      head_score: head_score,
      score_delta: delta,
      base_grade: _,
      head_grade: _,
      blocks_flagged: flagged,
      files_changed: 1,
      files_added: 0,
      files_modified: 1
    } = report.pr_summary

    assert is_integer(base_score)
    assert is_integer(head_score)
    assert delta == head_score - base_score
    assert is_integer(flagged)
  end

  @tag :slow
  test "codebase_delta is populated" do
    files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
    head_results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    head_results = CodeQA.BlockImpactAnalyzer.analyze(head_results, files)
    base_results = CodeQA.Engine.Analyzer.analyze_codebase(files)

    report = CodeQA.HealthReport.generate(head_results, base_results: base_results)

    assert %{base: %{aggregate: _}, head: %{aggregate: _}, delta: %{aggregate: _}} =
             report.codebase_delta
  end

  @tag :slow
  test "top_blocks scoped to changed_files" do
    files = %{
      "lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n",
      "lib/bar.ex" => "defmodule Bar do\n  def baz, do: :ok\nend\n"
    }
    head_results = CodeQA.Engine.Analyzer.analyze_codebase(files)
    head_results = CodeQA.BlockImpactAnalyzer.analyze(head_results, files)
    base_results = CodeQA.Engine.Analyzer.analyze_codebase(files)

    changed = [%CodeQA.Git.ChangedFile{path: "lib/foo.ex", status: "modified"}]

    report = CodeQA.HealthReport.generate(head_results,
      base_results: base_results,
      changed_files: changed
    )

    paths = Enum.map(report.top_blocks, & &1.path)
    refute "lib/bar.ex" in paths
  end
end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
mix test test/codeqa/health_report_test.exs --trace
```

Expected: FAIL — `pr_summary` key missing, etc.

- [ ] **Step 3: Update `lib/codeqa/health_report.ex`**

Replace the entire file:

```elixir
defmodule CodeQA.HealthReport do
  @moduledoc "Orchestrates health report generation from analysis results."

  alias CodeQA.HealthReport.{Config, Grader, Formatter, Delta, TopBlocks}
  alias CodeQA.CombinedMetrics.{FileScorer, SampleRunner}

  @spec generate(map(), keyword()) :: map()
  def generate(analysis_results, opts \\ []) do
    config_path = Keyword.get(opts, :config)
    detail = Keyword.get(opts, :detail, :default)
    base_results = Keyword.get(opts, :base_results)
    changed_files = Keyword.get(opts, :changed_files, [])

    %{
      categories: categories,
      grade_scale: grade_scale,
      impact_map: impact_map,
      combined_top: combined_top
    } =
      Config.load(config_path)

    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})
    project_langs = project_languages(files)

    threshold_grades =
      categories
      |> Grader.grade_aggregate(aggregate, grade_scale)
      |> Enum.zip(categories)
      |> Enum.map(fn {graded, _cat_def} ->
        summary = build_category_summary(graded)

        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: summary, worst_offenders: []})
      end)

    worst_files_map = FileScorer.worst_files_per_behavior(files, combined_top: combined_top)

    cosine_grades =
      Grader.grade_cosine_categories(aggregate, worst_files_map, grade_scale, project_langs)

    all_categories =
      (threshold_grades ++ cosine_grades)
      |> Enum.map(fn cat ->
        Map.put(cat, :impact, Map.get(impact_map, to_string(cat.key), 1))
      end)

    {overall_score, overall_grade} = Grader.overall_score(all_categories, grade_scale, impact_map)

    metadata = build_metadata(analysis_results)

    all_cosines =
      SampleRunner.diagnose_aggregate(aggregate, top: 99_999, languages: project_langs)

    top_issues = Enum.take(all_cosines, 10)

    codebase_cosine_lookup =
      Map.new(all_cosines, fn i -> {{i.category, i.behavior}, i.cosine} end)

    top_blocks = TopBlocks.build(analysis_results, changed_files, codebase_cosine_lookup)

    {codebase_delta, pr_summary} =
      if base_results do
        build_delta_and_summary(
          base_results,
          analysis_results,
          overall_score,
          overall_grade,
          all_categories,
          categories,
          grade_scale,
          impact_map,
          combined_top,
          changed_files,
          top_blocks
        )
      else
        {nil, nil}
      end

    %{
      metadata: metadata,
      pr_summary: pr_summary,
      overall_score: overall_score,
      overall_grade: overall_grade,
      codebase_delta: codebase_delta,
      categories: all_categories,
      top_issues: top_issues,
      top_blocks: top_blocks
    }
  end

  @spec to_markdown(map(), atom(), atom()) :: String.t()
  def to_markdown(report, detail \\ :default, format \\ :plain) do
    Formatter.format_markdown(report, detail, format)
  end

  defp build_delta_and_summary(
         base_results,
         head_results,
         head_score,
         head_grade,
         head_categories,
         category_defs,
         grade_scale,
         impact_map,
         combined_top,
         changed_files,
         top_blocks
       ) do
    delta = Delta.compute(base_results, head_results)

    base_aggregate = get_in(base_results, ["codebase", "aggregate"]) || %{}
    base_files = Map.get(base_results, "files", %{})
    base_project_langs = project_languages(base_files)

    base_threshold_grades =
      category_defs
      |> Grader.grade_aggregate(base_aggregate, grade_scale)
      |> Enum.zip(category_defs)
      |> Enum.map(fn {graded, _cat_def} ->
        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: "", worst_offenders: []})
      end)

    base_worst_files_map =
      FileScorer.worst_files_per_behavior(base_files, combined_top: combined_top)

    base_cosine_grades =
      Grader.grade_cosine_categories(
        base_aggregate,
        base_worst_files_map,
        grade_scale,
        base_project_langs
      )

    base_all_categories =
      (base_threshold_grades ++ base_cosine_grades)
      |> Enum.map(fn cat ->
        Map.put(cat, :impact, Map.get(impact_map, to_string(cat.key), 1))
      end)

    {base_score, base_grade} = Grader.overall_score(base_all_categories, grade_scale, impact_map)

    blocks_flagged = Enum.sum(Enum.map(top_blocks, fn g -> length(g.blocks) end))
    files_added = Enum.count(changed_files, &(&1.status == "added"))
    files_modified = Enum.count(changed_files, &(&1.status == "modified"))

    summary = %{
      base_score: base_score,
      head_score: head_score,
      score_delta: head_score - base_score,
      base_grade: base_grade,
      head_grade: head_grade,
      blocks_flagged: blocks_flagged,
      files_changed: length(changed_files),
      files_added: files_added,
      files_modified: files_modified
    }

    {delta, summary}
  end

  defp build_metadata(analysis_results) do
    meta = Map.get(analysis_results, "metadata", %{})

    %{
      path: meta["path"] || "unknown",
      timestamp: meta["timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601(),
      total_files: meta["total_files"] || map_size(Map.get(analysis_results, "files", %{}))
    }
  end

  defp project_languages(files_map) do
    files_map
    |> Map.keys()
    |> Enum.map(&CodeQA.Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end

  defp build_category_summary(%{type: :cosine}), do: ""

  defp build_category_summary(graded) do
    low_scorers =
      graded.metric_scores
      |> Enum.filter(fn m -> m.score < 60 end)
      |> length()

    cond do
      graded.score >= 90 -> "Excellent"
      graded.score >= 70 and low_scorers == 0 -> "Good"
      graded.score >= 70 -> "Good overall, #{low_scorers} metric(s) need attention"
      graded.score >= 50 -> "Needs improvement"
      true -> "Critical — requires attention"
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/codeqa/health_report_test.exs --trace
```

Expected: new tests PASS.

- [ ] **Step 5: Run full suite to check for regressions**

```bash
mix test
```

Fix any test that asserts on `worst_offenders` being non-empty in the report output — those assertions should now expect `[]`.

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/health_report.ex test/codeqa/health_report_test.exs
git commit -m "feat(health-report): add top_blocks, pr_summary, codebase_delta; drop worst_offenders"
```

---

## Task 5: Update plain formatter

**Files:**
- Modify: `lib/codeqa/health_report/formatter/plain.ex`
- Modify: `test/codeqa/health_report/formatter_test.exs`

- [ ] **Step 1: Delete failing worst_offenders tests and add new tests**

In `test/codeqa/health_report/formatter_test.exs`:

**Delete** these tests (they assert on worst_offenders rendering that is now gone):
- `"includes worst offenders section"` (lines 186–194)
- `"renders cosine worst offenders per behavior"` (lines 216–226)

**Update** `"summary detail omits category sections"` (line 196) — change to:
```elixir
test "summary detail omits category sections" do
  result = Formatter.format_markdown(@sample_report, :summary, :plain)
  refute result =~ "Codebase averages"
end
```

**Add** these tests after the existing plain describe blocks:

```elixir
describe "plain formatter: PR summary section" do
  @sample_report_with_pr Map.put(@sample_report, :pr_summary, %{
    base_score: 85,
    head_score: 77,
    score_delta: -8,
    base_grade: "B+",
    head_grade: "C+",
    blocks_flagged: 6,
    files_changed: 3,
    files_added: 1,
    files_modified: 2
  })

  test "renders PR summary line when pr_summary present" do
    result = Formatter.format_markdown(@sample_report_with_pr, :default, :plain)
    assert result =~ "B+"
    assert result =~ "C+"
    assert result =~ "-8"
    assert result =~ "6"
    assert result =~ "1 added"
    assert result =~ "2 modified"
  end

  test "omits PR summary when pr_summary is nil" do
    result = Formatter.format_markdown(@sample_report, :default, :plain)
    refute result =~ "Score:"
  end
end

describe "plain formatter: delta section" do
  @delta %{
    base: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 65.0}, "halstead" => %{"mean_difficulty" => 12.0}}},
    head: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 61.0}, "halstead" => %{"mean_difficulty" => 15.0}}}
  }

  @sample_report_with_delta Map.put(@sample_report, :codebase_delta, @delta)

  test "renders metric changes table when codebase_delta present" do
    result = Formatter.format_markdown(@sample_report_with_delta, :default, :plain)
    assert result =~ "Metric Changes"
    assert result =~ "Readability"
    assert result =~ "65.00"
    assert result =~ "61.00"
  end

  test "omits delta section when codebase_delta is nil" do
    result = Formatter.format_markdown(@sample_report, :default, :plain)
    refute result =~ "Metric Changes"
  end
end

describe "plain formatter: block section" do
  @block_potential %{
    category: "function_design",
    behavior: "cyclomatic_complexity_under_10",
    cosine_delta: 0.41,
    severity: :critical,
    fix_hint: "Reduce branching"
  }

  @top_blocks [
    %{
      path: "lib/foo.ex",
      status: "modified",
      blocks: [
        %{
          start_line: 42,
          end_line: 67,
          type: "code",
          token_count: 84,
          potentials: [@block_potential]
        }
      ]
    }
  ]

  @sample_report_with_blocks Map.put(@sample_report, :top_blocks, @top_blocks)

  test "renders block section header" do
    result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
    assert result =~ "Blocks"
    assert result =~ "1 flagged"
  end

  test "renders file group with status" do
    result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
    assert result =~ "lib/foo.ex"
    assert result =~ "modified"
  end

  test "renders block location and type" do
    result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
    assert result =~ "lines 42"
    assert result =~ "67"
    assert result =~ "84 tokens"
  end

  test "renders severity icon and behavior" do
    result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
    assert result =~ "🔴"
    assert result =~ "CRITICAL"
    assert result =~ "cyclomatic_complexity_under_10"
    assert result =~ "0.41"
  end

  test "renders fix hint" do
    result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
    assert result =~ "Reduce branching"
  end

  test "omits block section when top_blocks is empty" do
    report = Map.put(@sample_report, :top_blocks, [])
    result = Formatter.format_markdown(report, :default, :plain)
    refute result =~ "## Blocks"
  end

  test "omits block section when top_blocks key absent" do
    result = Formatter.format_markdown(@sample_report, :default, :plain)
    refute result =~ "## Blocks"
  end
end
```

- [ ] **Step 2: Run formatter tests to confirm failures**

```bash
mix test test/codeqa/health_report/formatter_test.exs --trace
```

Expected: new tests FAIL, deleted tests no longer present.

- [ ] **Step 3: Update `lib/codeqa/health_report/formatter/plain.ex`**

Replace the `render/2` function and remove `cosine_worst_offenders/2` + `worst_offenders_section/2`. Add new section functions:

```elixir
@spec render(map(), atom()) :: String.t()
def render(report, detail) do
  [
    pr_summary_section(Map.get(report, :pr_summary)),
    header(report),
    cosine_legend(),
    delta_section(Map.get(report, :codebase_delta)),
    overall_table(report),
    top_issues_section(Map.get(report, :top_issues, []), detail),
    blocks_section(Map.get(report, :top_blocks, [])),
    category_sections(report.categories, detail)
  ]
  |> List.flatten()
  |> Enum.join("\n")
end
```

Remove `cosine_worst_offenders/2` (lines 91–116) and `worst_offenders_section/2` (lines 196–235) entirely.

Update `render_category/2` for cosine — remove the `cosine_worst_offenders` call:

```elixir
defp render_category(%{type: :cosine} = cat, _detail) do
  cosine_section_header(cat) ++ cosine_behaviors_table(cat)
end

defp render_category(cat, _detail) do
  section_header(cat) ++ metric_detail(cat)
end
```

Add the three new private functions at the bottom of the module:

```elixir
defp pr_summary_section(nil), do: []

defp pr_summary_section(summary) do
  delta_str =
    if summary.score_delta >= 0,
      do: "+#{summary.score_delta}",
      else: "#{summary.score_delta}"

  status_str = "#{summary.files_modified} modified, #{summary.files_added} added"

  [
    "> **Score:** #{summary.base_grade} → #{summary.head_grade}  |  **Δ** #{delta_str} pts  |  **#{summary.blocks_flagged}** blocks flagged across #{summary.files_changed} files  |  #{status_str}",
    ""
  ]
end

defp delta_section(nil), do: []

defp delta_section(delta) do
  base_agg = delta.base.aggregate
  head_agg = delta.head.aggregate

  metrics = [
    {"Readability", "readability", "mean_flesch_adapted"},
    {"Complexity", "halstead", "mean_difficulty"},
    {"Duplication", "compression", "mean_redundancy"},
    {"Structure", "branching", "mean_branch_count"}
  ]

  rows =
    Enum.flat_map(metrics, fn {label, group, key} ->
      base_val = get_in(base_agg, [group, key])
      head_val = get_in(head_agg, [group, key])

      if is_number(base_val) and is_number(head_val) do
        diff = Float.round(head_val - base_val, 2)
        diff_str = if diff >= 0, do: "+#{format_num(diff)}", else: "#{format_num(diff)}"
        ["| #{label} | #{format_num(base_val)} | #{format_num(head_val)} | #{diff_str} |"]
      else
        []
      end
    end)

  if rows == [] do
    []
  else
    [
      "## Metric Changes",
      "",
      "| Category | Base | Head | Δ |",
      "|----------|------|------|---|"
      | rows
    ] ++ [""]
  end
end

defp blocks_section([]), do: []

defp blocks_section(top_blocks) do
  total = Enum.sum(Enum.map(top_blocks, fn g -> length(g.blocks) end))

  file_parts =
    Enum.flat_map(top_blocks, fn group ->
      status_str = if group.status, do: "  [#{group.status}]", else: ""

      block_lines =
        Enum.flat_map(group.blocks, fn block ->
          end_line = block.end_line || block.start_line
          header = "**lines #{block.start_line}–#{end_line}** · #{block.type} · #{block.token_count} tokens"

          potential_lines =
            Enum.flat_map(block.potentials, fn p ->
              icon = severity_icon(p.severity)
              delta_str = format_num(p.cosine_delta)
              label = "#{String.upcase(to_string(p.severity))}"
              line = "  #{icon} #{label}  #{p.category} / #{p.behavior}  (Δ #{delta_str})"
              fix = if p.fix_hint, do: ["    → #{p.fix_hint}"], else: []
              [line | fix]
            end)

          [header | potential_lines] ++ [""]
        end)

      ["### #{group.path}#{status_str}", "" | block_lines]
    end)

  [
    "## Blocks  (#{total} flagged across #{length(top_blocks)} files)",
    ""
    | file_parts
  ]
end

defp severity_icon(:critical), do: "🔴"
defp severity_icon(:high), do: "🟠"
defp severity_icon(:medium), do: "🟡"
```

- [ ] **Step 4: Run formatter tests**

```bash
mix test test/codeqa/health_report/formatter_test.exs --trace
```

Expected: all PASS.

- [ ] **Step 5: Run full suite**

```bash
mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/health_report/formatter/plain.ex test/codeqa/health_report/formatter_test.exs
git commit -m "feat(formatter): add block, delta, PR summary sections; remove worst_offenders (plain)"
```

---

## Task 6: Update GitHub formatter

**Files:**
- Modify: `lib/codeqa/health_report/formatter/github.ex`
- Modify: `test/codeqa/health_report/formatter_test.exs`

- [ ] **Step 1: Add GitHub formatter tests**

In `test/codeqa/health_report/formatter_test.exs`, add a new describe block:

```elixir
describe "github formatter: block section" do
  @block_potential %{
    category: "function_design",
    behavior: "cyclomatic_complexity_under_10",
    cosine_delta: 0.41,
    severity: :critical,
    fix_hint: "Reduce branching"
  }

  @top_blocks_gh [
    %{
      path: "lib/foo.ex",
      status: "modified",
      blocks: [
        %{start_line: 42, end_line: 67, type: "code", token_count: 84, potentials: [@block_potential]}
      ]
    }
  ]

  @report_with_blocks_gh Map.put(@sample_report, :top_blocks, @top_blocks_gh)

  test "renders block section with details wrapper per file" do
    result = Formatter.format_markdown(@report_with_blocks_gh, :default, :github)
    assert result =~ "Blocks"
    assert result =~ "<details>"
    assert result =~ "lib/foo.ex"
    assert result =~ "modified"
  end

  test "renders severity and fix hint" do
    result = Formatter.format_markdown(@report_with_blocks_gh, :default, :github)
    assert result =~ "🔴"
    assert result =~ "cyclomatic_complexity_under_10"
    assert result =~ "Reduce branching"
  end
end

describe "github formatter: PR summary and delta" do
  @pr_summary_gh %{
    base_score: 85, head_score: 77, score_delta: -8,
    base_grade: "B+", head_grade: "C+",
    blocks_flagged: 6, files_changed: 3, files_added: 1, files_modified: 2
  }

  @delta_gh %{
    base: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 65.0}}},
    head: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 61.0}}}
  }

  test "renders PR summary" do
    report = @sample_report |> Map.put(:pr_summary, @pr_summary_gh)
    result = Formatter.format_markdown(report, :default, :github)
    assert result =~ "B+"
    assert result =~ "C+"
    assert result =~ "-8"
  end

  test "renders delta section" do
    report = @sample_report |> Map.put(:codebase_delta, @delta_gh)
    result = Formatter.format_markdown(report, :default, :github)
    assert result =~ "Metric Changes"
    assert result =~ "65.00"
    assert result =~ "61.00"
  end
end
```

- [ ] **Step 2: Run tests to confirm failures**

```bash
mix test test/codeqa/health_report/formatter_test.exs --trace 2>&1 | grep -E "FAILED|failure"
```

- [ ] **Step 3: Update `lib/codeqa/health_report/formatter/github.ex`**

Update `render/3` to include new sections and remove worst_offenders:

```elixir
def render(report, detail, opts \\ []) do
  chart? = Keyword.get(opts, :chart, true)
  display_categories = merge_cosine_categories(report.categories)

  [
    pr_summary_section(Map.get(report, :pr_summary)),
    header(report),
    cosine_legend(),
    delta_section(Map.get(report, :codebase_delta)),
    if(chart?, do: mermaid_chart(display_categories), else: []),
    progress_bars(display_categories),
    top_issues_section(Map.get(report, :top_issues, []), detail),
    blocks_section(Map.get(report, :top_blocks, [])),
    category_sections(display_categories, detail),
    footer()
  ]
  |> List.flatten()
  |> Enum.join("\n")
end
```

Remove `cosine_worst_offenders/2` (lines 254–304) and `worst_offenders/2` (lines 384–435).

Update `cosine_section_content/2` — remove the call to `cosine_worst_offenders`:

```elixir
defp cosine_section_content(cat, _detail) do
  # ... existing behaviors_table code ...
  behaviors_table ++ [""]
end
```

Update `section_content/2` — remove the `++ worst_offenders(cat)` at the end (line 381):

```elixir
defp section_content(cat, _detail) do
  # ... existing code without worst_offenders ...
  [
    "Codebase averages: #{metric_summary}",
    ""
    | metrics_table
  ] ++ [""]
end
```

Add new private functions at the bottom:

```elixir
defp pr_summary_section(nil), do: []

defp pr_summary_section(summary) do
  delta_str =
    if summary.score_delta >= 0,
      do: "+#{summary.score_delta}",
      else: "#{summary.score_delta}"

  status_str = "#{summary.files_modified} modified, #{summary.files_added} added"

  [
    "> **Score:** #{summary.base_grade} → #{summary.head_grade}  |  **Δ** #{delta_str} pts  |  **#{summary.blocks_flagged}** blocks flagged across #{summary.files_changed} files  |  #{status_str}",
    ""
  ]
end

defp delta_section(nil), do: []

defp delta_section(delta) do
  base_agg = delta.base.aggregate
  head_agg = delta.head.aggregate

  metrics = [
    {"Readability", "readability", "mean_flesch_adapted"},
    {"Complexity", "halstead", "mean_difficulty"},
    {"Duplication", "compression", "mean_redundancy"},
    {"Structure", "branching", "mean_branch_count"}
  ]

  rows =
    Enum.flat_map(metrics, fn {label, group, key} ->
      base_val = get_in(base_agg, [group, key])
      head_val = get_in(head_agg, [group, key])

      if is_number(base_val) and is_number(head_val) do
        diff = Float.round(head_val - base_val, 2)
        diff_str = if diff >= 0, do: "+#{format_num(diff)}", else: "#{format_num(diff)}"
        ["| #{label} | #{format_num(base_val)} | #{format_num(head_val)} | #{diff_str} |"]
      else
        []
      end
    end)

  if rows == [] do
    []
  else
    [
      "## Metric Changes",
      "",
      "| Category | Base | Head | Δ |",
      "|----------|------|------|---|"
      | rows
    ] ++ [""]
  end
end

defp blocks_section([]), do: []

defp blocks_section(top_blocks) do
  total = Enum.sum(Enum.map(top_blocks, fn g -> length(g.blocks) end))

  file_cards =
    Enum.flat_map(top_blocks, fn group ->
      status_str = if group.status, do: " [#{group.status}]", else: ""
      summary_line = "🔍 #{group.path}#{status_str} — #{length(group.blocks)} block(s)"

      block_lines =
        Enum.flat_map(group.blocks, fn block ->
          end_line = block.end_line || block.start_line

          potential_lines =
            Enum.flat_map(block.potentials, fn p ->
              icon = severity_icon(p.severity)
              delta_str = format_num(p.cosine_delta)
              label = String.upcase(to_string(p.severity))
              line = "**#{icon} #{label}** `#{p.category}/#{p.behavior}` (Δ #{delta_str})"
              fix = if p.fix_hint, do: ["> #{p.fix_hint}"], else: []
              [line | fix]
            end)

          ["**lines #{block.start_line}–#{end_line}** · #{block.type} · #{block.token_count} tokens"] ++
            potential_lines ++ [""]
        end)

      inner = List.flatten(block_lines) |> Enum.join("\n")

      [
        "<details>",
        "<summary>#{summary_line}</summary>",
        "",
        inner,
        "</details>",
        ""
      ]
    end)

  [
    "## 🔍 Blocks  (#{total} flagged across #{length(top_blocks)} files)",
    ""
    | file_cards
  ]
end

defp severity_icon(:critical), do: "🔴"
defp severity_icon(:high), do: "🟠"
defp severity_icon(:medium), do: "🟡"
```

- [ ] **Step 4: Run formatter tests**

```bash
mix test test/codeqa/health_report/formatter_test.exs --trace
```

Expected: all PASS.

- [ ] **Step 5: Run full suite**

```bash
mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/health_report/formatter/github.ex test/codeqa/health_report/formatter_test.exs
git commit -m "feat(formatter): add block, delta, PR summary sections; remove worst_offenders (github)"
```

---

## Task 7: Update `CLI.HealthReport`

**Files:**
- Modify: `lib/codeqa/cli/health_report.ex`

- [ ] **Step 1: Update `@command_options` and usage string**

In `lib/codeqa/cli/health_report.ex`, add to `@command_options`:

```elixir
@command_options [
  output: :string,
  config: :string,
  detail: :string,
  top: :integer,
  format: :string,
  ignore_paths: :string,
  base_ref: :string,
  head_ref: :string
]
```

Add to the usage string:

```
      --base-ref REF        Base git ref for PR comparison (enables delta and block scoping)
      --head-ref REF        Head git ref (default: HEAD)
```

- [ ] **Step 2: Update `run/1` to wire dual analysis**

Replace the `run/1` body (keeping the existing single-pass as the fallback when no `--base-ref`). The full updated `run/1`:

```elixir
def run(args) do
  {opts, [path], _} = Options.parse(args, @command_options, o: :output)
  Options.validate_dir!(path)
  extra_ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])

  base_ref = opts[:base_ref]
  head_ref = opts[:head_ref] || "HEAD"

  files =
    CodeQA.Engine.Collector.collect_files(path, extra_ignore_patterns)

  if map_size(files) == 0 do
    IO.puts(:stderr, "Warning: no source files found in '#{path}'")
    exit({:shutdown, 1})
  end

  IO.puts(:stderr, "Analyzing #{map_size(files)} files for health report...")

  analyze_opts =
    Options.build_analyze_opts(opts) ++ CodeQA.Config.near_duplicate_blocks_opts()

  start_time = System.monotonic_time(:millisecond)
  results = CodeQA.Engine.Analyzer.analyze_codebase(files, analyze_opts)
  end_time = System.monotonic_time(:millisecond)

  IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

  nodes_top = opts[:nodes_top] || 3
  results = CodeQA.BlockImpactAnalyzer.analyze(results, files, nodes_top: nodes_top)

  total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

  results =
    Map.put(results, "metadata", %{
      "path" => Path.expand(path),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "total_files" => map_size(files),
      "total_bytes" => total_bytes
    })

  {base_results, changed_files} =
    if base_ref do
      IO.puts(:stderr, "Collecting base snapshot at #{base_ref}...")
      base_files = CodeQA.Git.collect_files_at_ref(path, base_ref)
      changed = CodeQA.Git.changed_files(path, base_ref, head_ref)

      IO.puts(:stderr, "Analyzing base snapshot (#{map_size(base_files)} files)...")
      base_res = CodeQA.Engine.Analyzer.analyze_codebase(base_files, analyze_opts)

      {base_res, changed}
    else
      {nil, []}
    end

  detail = parse_detail(opts[:detail])
  format = parse_format(opts[:format])
  top_n = opts[:top] || 5

  report =
    CodeQA.HealthReport.generate(results,
      config: opts[:config],
      detail: detail,
      top: top_n,
      base_results: base_results,
      changed_files: changed_files
    )

  markdown = CodeQA.HealthReport.to_markdown(report, detail, format)

  case opts[:output] do
    nil ->
      markdown

    file ->
      File.write!(file, markdown)
      IO.puts(:stderr, "Health report written to #{file}")
      ""
  end
end
```

- [ ] **Step 3: Run full test suite**

```bash
mix test
```

Expected: all PASS (no tests for git integration at this stage — the git calls require an actual repo with refs, which integration tests would mock or skip).

- [ ] **Step 4: Commit**

```bash
git add lib/codeqa/cli/health_report.ex
git commit -m "feat(cli): add --base-ref/--head-ref to health-report for PR delta and block scoping"
```

---

## Task 8: Delete compare command and related files

**Files:**
- Delete: `lib/codeqa/cli/compare.ex`
- Delete: `lib/codeqa/comparator.ex`
- Delete: `lib/codeqa/formatter.ex`
- Delete: `lib/codeqa/summarizer.ex`
- Delete: `test/codeqa/cli_compare_test.exs`
- Modify: `lib/codeqa/cli.ex`

- [ ] **Step 1: Remove compare from the CLI router**

Read `lib/codeqa/cli.ex` and remove the line that registers `compare` (line 6). It will look like:

```elixir
"compare" => CodeQA.CLI.Compare,
```

Remove that entry entirely.

- [ ] **Step 2: Delete the four source files**

```bash
rm lib/codeqa/cli/compare.ex lib/codeqa/comparator.ex lib/codeqa/formatter.ex lib/codeqa/summarizer.ex
```

- [ ] **Step 3: Delete compare tests**

```bash
rm test/codeqa/cli_compare_test.exs
```

- [ ] **Step 4: Verify no remaining references**

```bash
grep -r "CLI\.Compare\|CodeQA\.Comparator\|CodeQA\.Formatter\b\|CodeQA\.Summarizer" lib/ test/ --include="*.ex" --include="*.exs"
```

Expected: no output.

- [ ] **Step 5: Run full test suite**

```bash
mix test
```

Expected: all PASS, no references to deleted modules.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(cli): delete compare command — absorbed into health-report"
```

---
