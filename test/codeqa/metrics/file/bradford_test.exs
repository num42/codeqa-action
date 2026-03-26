defmodule CodeQA.Metrics.File.BradfordTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.Bradford

  # Bradford zones are built by ranking lines densest-first, then walking down
  # until each third of total tokens is accumulated:
  #   zone 1 (core)   — fewest lines needed to reach 1/3 of all tokens
  #   zone 2 (middle) — fewest additional lines to reach 2/3
  #   zone 3 (tail)   — all remaining lines
  #
  # k1 = zone2_lines / zone1_lines  — how many more lines the middle needs vs the core
  # k2 = zone3_lines / zone2_lines  — how many more lines the tail needs vs the middle
  # k_ratio = k2 / k1               — > 1 means tail is more stretched; < 1 means core is extreme

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: Bradford.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      # can't form three meaningful zones with nothing
      assert result("") == %{"k1" => 0.0, "k2" => 0.0, "k_ratio" => 0.0}
    end

    test "returns zeros for a single line" do
      # a single line cannot be split into three zones
      assert result("a b c") == %{"k1" => 0.0, "k2" => 0.0, "k_ratio" => 0.0}
    end

    test "returns zeros for two lines" do
      # two lines still can't fill three zones
      assert result("a b c\nd e f") == %{"k1" => 0.0, "k2" => 0.0, "k_ratio" => 0.0}
    end
  end

  describe "analyze/1 - uniform distribution" do
    # 9 lines × 3 tokens = 27 total, third = 9
    # sorted counts: [3, 3, 3, 3, 3, 3, 3, 3, 3]
    # zone 1: 3 lines (3+3+3 = 9 ≥ 9)
    # zone 2: 3 lines (3+3+3 = 9 ≥ 9)
    # zone 3: 3 lines remaining
    # k1 = 3/3 = 1.0  — middle needs the same number of lines as the core
    # k2 = 3/3 = 1.0  — tail needs the same number of lines as the middle
    # k_ratio = 1.0   — perfectly symmetric: no zone is more stretched than another
    test "uniform file has k = 1" do
      code = Enum.map_join(1..9, "\n", fn _ -> "a b c" end)
      assert result(code) == %{"k1" => 1.0, "k2" => 1.0, "k_ratio" => 1.0}
    end
  end

  describe "analyze/1 - Bradford concentration" do
    # 1 line with 10 tokens  +  3 lines with 3 tokens  +  9 lines with 1 token
    # total = 28, third ≈ 9.333
    # sorted: [10, 3, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1]  (13 lines)
    # zone 1: 1 line  (10 ≥ 9.333)                        → n1 = 1
    # zone 2: 4 lines (3+3+3 = 9 < 9.333; +1 → 10 ≥ 9.333) → n2 = 4
    # zone 3: 8 lines remaining                            → n3 = 8
    # k1 = 4/1 = 4.0  — the middle needs 4× more lines than the dense core
    # k2 = 8/4 = 2.0  — the tail needs 2× more lines than the middle
    # k_ratio = 0.5   — the core-to-middle jump (4×) is bigger than middle-to-tail (2×),
    #                    meaning extreme concentration is at the very top, not spread across zones
    test "concentrated file produces k1=4.0, k2=2.0, k_ratio=0.5" do
      dense = "a b c d e f g h i j"
      medium = Enum.map_join(1..3, "\n", fn _ -> "a b c" end)
      sparse = Enum.map_join(1..9, "\n", fn _ -> "a" end)
      code = Enum.join([dense, medium, sparse], "\n")

      assert result(code) == %{
               # 1 dense line does the work of 4 middle lines — extreme core
               "k1" => 4.0,
               # 4 middle lines do the work of 8 tail lines — moderate long tail
               "k2" => 2.0,
               # k2 < k1: the core is more concentrated than the tail is sparse
               "k_ratio" => 0.5
             }
    end

    test "concentrated file has higher k1 than uniform" do
      # k1 is the primary concentration signal: how many times more lines the
      # middle zone needs compared to the core. A uniform file scores 1.0 here.
      uniform = Enum.map_join(1..9, "\n", fn _ -> "a b c" end)

      dense = "a b c d e f g h i j"
      medium = Enum.map_join(1..3, "\n", fn _ -> "a b c" end)
      sparse = Enum.map_join(1..9, "\n", fn _ -> "a" end)
      concentrated = Enum.join([dense, medium, sparse], "\n")

      assert result(concentrated)["k1"] > result(uniform)["k1"]
    end

    test "k_ratio < 1 when the core is more extreme than the tail" do
      # k_ratio = k2 / k1
      # k_ratio < 1  →  k2 < k1  →  the core-to-middle multiplier exceeds the
      #                               middle-to-tail multiplier: the spike is at
      #                               the very top, not spread evenly down the rank list
      # k_ratio > 1  →  k2 > k1  →  the tail is more stretched than the core jump,
      #                               typical of many medium lines plus a huge sparse tail
      code =
        Enum.join(
          [
            "a b c d e f g h i j",
            "a b c",
            "a b c",
            "a b c",
            "a",
            "a",
            "a",
            "a",
            "a",
            "a",
            "a",
            "a",
            "a"
          ],
          "\n"
        )

      assert result(code)["k_ratio"] < 1.0
    end
  end
end
