defmodule CodeQA.BlockImpact.RefactoringPotentialsTest do
  use ExUnit.Case, async: true

  alias CodeQA.BlockImpact.RefactoringPotentials
  alias CodeQA.CombinedMetrics.FileScorer
  alias CodeQA.CombinedMetrics.SampleRunner

  defp file_cosines(fm) do
    fm
    |> FileScorer.file_to_aggregate()
    |> SampleRunner.diagnose_aggregate(top: 99_999)
  end

  describe "compute/5" do
    test "returns a list of maps with category, behavior, cosine_delta" do
      content = """
      defmodule Foo do
        def bar(a, b, c) do
          if a do
            if b do
              if c do
                :nested
              end
            end
          end
        end
      end
      """

      baseline_fm = CodeQA.Engine.Analyzer.analyze_file("lib/foo.ex", content)
      simple = "defmodule Foo do\n  def bar, do: :ok\nend\n"
      without_fm = CodeQA.Engine.Analyzer.analyze_file("lib/foo.ex", simple)

      files = %{"lib/foo.ex" => content}
      baseline_agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(files)
      without_agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(%{"lib/foo.ex" => simple})

      baseline_file_cosines = file_cosines(baseline_fm)
      baseline_codebase_cosines = SampleRunner.diagnose_aggregate(baseline_agg, top: 99_999)

      result =
        RefactoringPotentials.compute(
          baseline_file_cosines,
          without_fm,
          baseline_codebase_cosines,
          without_agg
        )

      assert is_list(result)

      Enum.each(result, fn item ->
        assert Map.has_key?(item, "category")
        assert Map.has_key?(item, "behavior")
        assert Map.has_key?(item, "cosine_delta")
        assert is_binary(item["category"])
        assert is_binary(item["behavior"])
        assert is_float(item["cosine_delta"])
      end)
    end

    test "returns at most top N results (default 3)" do
      content = "defmodule A do\n  def foo, do: 1\nend\n"
      fm = CodeQA.Engine.Analyzer.analyze_file("lib/a.ex", content)
      agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(%{"lib/a.ex" => content})

      baseline_file_cosines = file_cosines(fm)
      baseline_codebase_cosines = SampleRunner.diagnose_aggregate(agg, top: 99_999)

      result =
        RefactoringPotentials.compute(baseline_file_cosines, fm, baseline_codebase_cosines, agg)

      assert length(result) <= 3
    end

    test "respects top: N option" do
      content = "defmodule A do\n  def foo, do: 1\nend\n"
      fm = CodeQA.Engine.Analyzer.analyze_file("lib/a.ex", content)
      agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(%{"lib/a.ex" => content})

      baseline_file_cosines = file_cosines(fm)
      baseline_codebase_cosines = SampleRunner.diagnose_aggregate(agg, top: 99_999)

      result =
        RefactoringPotentials.compute(baseline_file_cosines, fm, baseline_codebase_cosines, agg,
          top: 5
        )

      assert length(result) <= 5
    end

    test "results are sorted descending by cosine_delta" do
      content = "defmodule A do\n  def foo, do: 1\nend\n"
      fm = CodeQA.Engine.Analyzer.analyze_file("lib/a.ex", content)
      agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(%{"lib/a.ex" => content})

      baseline_file_cosines = file_cosines(fm)
      baseline_codebase_cosines = SampleRunner.diagnose_aggregate(agg, top: 99_999)

      result =
        RefactoringPotentials.compute(baseline_file_cosines, fm, baseline_codebase_cosines, agg,
          top: 99
        )

      deltas = Enum.map(result, & &1["cosine_delta"])
      assert deltas == Enum.sort(deltas, :desc)
    end
  end
end
