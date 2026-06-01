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
      results = BlockImpactAnalyzer.analyze(results, files)

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
      results = BlockImpactAnalyzer.analyze(results, files)

      report = HealthReport.generate(results)

      # top_blocks is a flat list of blocks (may be empty if no blocks above threshold)
      assert is_list(report.top_blocks)

      Enum.each(report.top_blocks, fn block ->
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
      results = BlockImpactAnalyzer.analyze(results, files)

      report = HealthReport.generate(results)

      Enum.each(report.categories, fn cat ->
        assert Map.get(cat, :worst_offenders, []) == []
      end)
    end
  end

  describe "generate/2 with base_results" do
    @tag :slow
    test "pr_summary is populated" do
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n"}
      head_results = Analyzer.analyze_codebase(files)
      head_results = BlockImpactAnalyzer.analyze(head_results, files)
      base_results = Analyzer.analyze_codebase(files)

      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]

      report =
        HealthReport.generate(head_results,
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
      head_results = Analyzer.analyze_codebase(files)
      head_results = BlockImpactAnalyzer.analyze(head_results, files)
      base_results = Analyzer.analyze_codebase(files)

      report = HealthReport.generate(head_results, base_results: base_results)

      assert %{base: %{aggregate: _}, head: %{aggregate: _}, delta: %{aggregate: _}} =
               report.codebase_delta
    end

    @tag :slow
    test "top_blocks scoped to changed_files" do
      files = %{
        "lib/foo.ex" => "defmodule Foo do\n  def bar, do: :ok\nend\n",
        "lib/bar.ex" => "defmodule Bar do\n  def baz, do: :ok\nend\n"
      }

      head_results = Analyzer.analyze_codebase(files)
      head_results = BlockImpactAnalyzer.analyze(head_results, files)
      base_results = Analyzer.analyze_codebase(files)

      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]

      report =
        HealthReport.generate(head_results,
          base_results: base_results,
          changed_files: changed
        )

      paths = Enum.map(report.top_blocks, & &1.path)
      refute "lib/bar.ex" in paths
    end
  end
end
