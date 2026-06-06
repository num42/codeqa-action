defmodule CodeQA.HealthReportTest do
  use ExUnit.Case, async: true

  alias CodeQA.BlockImpactAnalyzer
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Git.ChangedFile
  alias CodeQA.HealthReport

  describe "generate/2 output keys" do
    @tag :slow
    test "without base_results: pr_summary and codebase_delta are nil" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)
      results = results |> BlockImpactAnalyzer.analyze(files)

      report = HealthReport.generate(results)

      assert report.pr_summary == nil
      assert report.codebase_delta == nil
      assert is_list(report.top_blocks)
      assert Map.has_key?(report, :overall_score)
      assert Map.has_key?(report, :overall_grade)
      assert Map.has_key?(report, :categories)
      assert Map.has_key?(report, :top_issues)
    end

    @tag :slow
    test "without base_results: top_blocks shows top 10 blocks by impact" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)
      results = results |> BlockImpactAnalyzer.analyze(files)

      report = HealthReport.generate(results)

      # top_blocks is a flat list of blocks (may be empty if no blocks above threshold)
      assert is_list(report.top_blocks)

      report.top_blocks
      |> Enum.each(fn block ->
        assert Map.has_key?(block, :path)
        assert Map.has_key?(block, :status)
        assert Map.has_key?(block, :potentials)
        assert Map.has_key?(block, :source)
        assert block.status == nil
      end)
    end

    @tag :slow
    test "worst_offenders is always empty in categories" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)
      results = results |> BlockImpactAnalyzer.analyze(files)

      report = HealthReport.generate(results)

      report.categories
      |> Enum.each(&assert Map.get(&1, :worst_offenders, []) == [])
    end
  end

  describe "generate/2 with base_results" do
    @tag :slow
    test "pr_summary is populated" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      head_results = Analyzer.analyze_codebase(files)
      head_results = head_results |> BlockImpactAnalyzer.analyze(files)
      base_results = Analyzer.analyze_codebase(files)

      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]

      report =
        HealthReport.generate(head_results,
          base_results: base_results,
          changed_files: changed
        )

      assert %{
               base_grade: _,
               base_score: base_score,
               blocks_flagged: flagged,
               files_added: 0,
               files_changed: 1,
               files_modified: 1,
               head_grade: _,
               head_score: head_score,
               score_delta: delta
             } = report.pr_summary

      assert is_integer(base_score)
      assert is_integer(head_score)
      assert delta == head_score - base_score
      assert is_integer(flagged)
    end

    @tag :slow
    test "codebase_delta is populated" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      head_results = Analyzer.analyze_codebase(files)
      head_results = head_results |> BlockImpactAnalyzer.analyze(files)
      base_results = Analyzer.analyze_codebase(files)

      report = HealthReport.generate(head_results, base_results: base_results)

      assert %{base: %{aggregate: _}, delta: %{aggregate: _}, head: %{aggregate: _}} =
               report.codebase_delta
    end

    @tag :slow
    test "top_blocks scoped to changed_files" do
      files = %{
        "lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n",
        "lib/bar.ex" => "defmodule Bar do\n  def baz, do: :ok\nend\n"
      }

      head_results = Analyzer.analyze_codebase(files)
      head_results = head_results |> BlockImpactAnalyzer.analyze(files)
      base_results = Analyzer.analyze_codebase(files)

      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]

      report =
        HealthReport.generate(head_results,
          base_results: base_results,
          changed_files: changed
        )

      paths = report.top_blocks |> Enum.map(& &1.path)
      refute "lib/bar.ex" in paths
    end
  end

  describe "generate/2 view scoping" do
    @tag :slow
    test ":metrics skips block work — no top_blocks, full metric keys" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)

      report = HealthReport.generate(results, view: :metrics)

      assert Map.has_key?(report, :categories)
      assert Map.has_key?(report, :overall_score)
      assert Map.has_key?(report, :top_issues)
      refute Map.has_key?(report, :top_blocks)
    end

    @tag :slow
    test ":actions skips metric grading — top_blocks present, no categories" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)
      results = results |> BlockImpactAnalyzer.analyze(files)

      report = HealthReport.generate(results, view: :actions)

      assert is_list(report.top_blocks)
      refute Map.has_key?(report, :categories)
      refute Map.has_key?(report, :overall_score)
    end

    @tag :slow
    test ":actions without base_results leaves delta and pr_summary nil" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      results = Analyzer.analyze_codebase(files)
      results = results |> BlockImpactAnalyzer.analyze(files)

      report = HealthReport.generate(results, view: :actions)

      assert report.codebase_delta == nil
      assert report.pr_summary == nil
    end
  end
end
