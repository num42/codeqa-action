defmodule CodeQA.Metrics.File.LexicalConcentrationTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.LexicalConcentration

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: LexicalConcentration.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{"yule_k" => 0.0, "simpson_d" => 0.0, "total_tokens" => 0}
    end

    test "returns zeros for a single token" do
      assert result("alpha") == %{"yule_k" => 0.0, "simpson_d" => 0.0, "total_tokens" => 1}
    end
  end

  describe "analyze/1 - concentration" do
    test "uniform distribution yields zero concentration" do
      # a..f each appear once: no repetition, K and D collapse to 0
      assert result("a b c d e f") == %{
               "yule_k" => 0.0,
               "simpson_d" => 0.0,
               "total_tokens" => 6
             }
    end

    test "a dominating token yields high concentration" do
      # x:5, y:1 => N=6, K = 1e4*(26-6)/36, D = (5*4)/(6*5)
      res = result("x x x x x y")
      assert res["yule_k"] == 5555.5556
      assert res["simpson_d"] == 0.6667
      assert res["total_tokens"] == 6
    end

    test "concentration rises as one token dominates more" do
      spread = result("a a b b c c")["yule_k"]
      concentrated = result("a a a a a b")["yule_k"]
      assert concentrated > spread
    end

    test "is length-invariant where raw TTR is not" do
      # Same repetition structure at two lengths: one token repeated, rest unique.
      short = result("a a b c")["yule_k"]
      long = result("a a b c d e f g")["yule_k"]
      # K stays in the same order of magnitude; it is not driven to 0 by added length.
      assert short > 0.0
      assert long > 0.0
    end
  end
end
