defmodule CodeQA.HealthReportTest do
  use ExUnit.Case, async: true

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

      report =
        CodeQA.HealthReport.generate(head_results,
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

      report =
        CodeQA.HealthReport.generate(head_results,
          base_results: base_results,
          changed_files: changed
        )

      paths = Enum.map(report.top_blocks, & &1.path)
      refute "lib/bar.ex" in paths
    end
  end
end
