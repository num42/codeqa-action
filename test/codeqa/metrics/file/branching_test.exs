defmodule CodeQA.Metrics.File.BranchingTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.Branching

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp density(code), do: Branching.analyze(ctx(code))["branching_density"]

  describe "analyze/1" do
    test "returns 0.0 for empty content" do
      assert density("") == 0.0
    end

    test "returns 0.0 when no branching keywords present" do
      assert density("x = 1\ny = 2\nz = x + y") == 0.0
    end

    test "density increases with more branching keywords" do
      low = density("if x\n  y\nend")
      high = density("if x\n  if y\n    if z\n    end\n  end\nend")
      assert high > low
    end
  end

  describe "analyze/1 - each keyword is counted" do
    for keyword <- Branching.branching_keywords() |> MapSet.to_list() |> Enum.sort() do
      test "counts #{keyword} as a branching token" do
        code = "line_before\n#{unquote(keyword)} condition\nline_after"

        assert density(code) > 0.0,
               "expected '#{unquote(keyword)}' to be counted as a branching token"
      end
    end
  end
end
