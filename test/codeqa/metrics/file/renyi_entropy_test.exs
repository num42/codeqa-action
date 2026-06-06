defmodule CodeQA.Metrics.File.RenyiEntropyTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.RenyiEntropy

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: RenyiEntropy.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{
               "renyi_0" => 0.0,
               "renyi_1" => 0.0,
               "renyi_2" => 0.0,
               "renyi_inf" => 0.0,
               "hill_1" => 0.0,
               "hill_2" => 0.0,
               "spectrum_slope" => 0.0
             }
    end

    test "single unique token has zero entropy across the spectrum" do
      r = result("x x x x")
      assert r["renyi_0"] == 0.0
      assert r["renyi_1"] == 0.0
      assert r["renyi_2"] == 0.0
      assert r["renyi_inf"] == 0.0
      assert r["spectrum_slope"] == 0.0
    end

    test "single unique token has hill numbers equal to vocab_size of 1" do
      r = result("x x x x")
      assert r["hill_1"] == 1.0
      assert r["hill_2"] == 1.0
    end
  end

  describe "analyze/1 - uniform distribution (flat spectrum)" do
    test "uniform tokens give renyi_0 == renyi_2 and zero slope" do
      r = result("a b c d e f g h")
      assert r["renyi_0"] == r["renyi_2"]
      assert r["spectrum_slope"] == 0.0
    end

    test "uniform tokens give renyi_0 == renyi_inf (all orders collapse)" do
      r = result("a b c d e f g h")
      assert r["renyi_0"] == r["renyi_inf"]
      assert r["renyi_1"] == r["renyi_0"]
    end

    test "uniform vocab of 8 yields renyi_0 of log2(8) == 3.0" do
      r = result("a b c d e f g h")
      assert r["renyi_0"] == 3.0
    end

    test "hill numbers equal vocab_size for a uniform distribution" do
      r = result("a b c d e f g h")
      assert r["hill_1"] == 8.0
      assert r["hill_2"] == 8.0
    end
  end

  describe "analyze/1 - dominated distribution (steep spectrum)" do
    test "dominated token gives large positive spectrum_slope" do
      # x: 100× against 8 singletons → H₀ = log2(9) ≈ 3.17 but H₂ collapses
      # toward 0, so the slope is large. (With only 2 distinct tokens H₀ caps
      # at 1.0, which bounds the slope below 1 — needs a wider vocab to show.)
      code = String.duplicate("x ", 100) <> "a b c d e f g h"
      assert result(code)["spectrum_slope"] > 1.0
    end

    test "renyi monotonically decreases with order for a skewed distribution" do
      code = "x x x x x x x y"
      r = result(code)
      assert r["renyi_0"] >= r["renyi_1"]
      assert r["renyi_1"] >= r["renyi_2"]
      assert r["renyi_2"] >= r["renyi_inf"]
    end

    test "hill_2 is much smaller than vocab_size when one token dominates" do
      # vocab_size of 5 but effective vocabulary collapses toward 1
      code = String.duplicate("x ", 100) <> "a b c d"
      vocab_size = 5
      assert result(code)["hill_2"] < vocab_size / 2
    end
  end

  describe "behaviour contract" do
    test "name/0 is renyi_entropy" do
      assert RenyiEntropy.name() == "renyi_entropy"
    end

    test "keys/0 matches the keys returned by analyze/1" do
      keys = RenyiEntropy.keys()
      r = result("a b c a b")
      assert Enum.sort(keys) == Enum.sort(Map.keys(r))
    end

    test "keys/0 lists exactly the seven spec keys" do
      assert Enum.sort(RenyiEntropy.keys()) ==
               Enum.sort([
                 "renyi_0",
                 "renyi_1",
                 "renyi_2",
                 "renyi_inf",
                 "hill_1",
                 "hill_2",
                 "spectrum_slope"
               ])
    end
  end
end
