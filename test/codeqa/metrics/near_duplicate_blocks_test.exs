defmodule CodeQA.Metrics.NearDuplicateBlocksTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.NearDuplicateBlocks, as: NDB

  describe "token_edit_distance/2" do
    test "identical sequences have distance 0" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a b c]) == 0
    end

    test "empty vs non-empty equals length of other" do
      assert NDB.token_edit_distance([], ~w[a b c]) == 3
      assert NDB.token_edit_distance(~w[a b c], []) == 3
    end

    test "single substitution" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a x c]) == 1
    end
  end

  describe "percent_bucket/2" do
    test "returns 0 for edit distance 0" do
      assert NDB.percent_bucket(0, 100) == 0
    end

    test "returns 1 for 1% difference (within 0–5%)" do
      assert NDB.percent_bucket(1, 100) == 1
    end

    test "returns 1 for 5% difference (boundary)" do
      assert NDB.percent_bucket(5, 100) == 1
    end

    test "returns 2 for 6% difference" do
      assert NDB.percent_bucket(6, 100) == 2
    end

    test "returns 8 for 50% difference" do
      assert NDB.percent_bucket(50, 100) == 8
    end

    test "returns nil for >50% difference" do
      assert NDB.percent_bucket(51, 100) == nil
    end

    test "returns nil when min_token_count is 0" do
      assert NDB.percent_bucket(0, 0) == nil
    end

    test "returns 7 for exactly 40% (d7 upper boundary)" do
      assert NDB.percent_bucket(40, 100) == 7
    end

    test "returns 8 for 41% (just above d7 boundary, in d8)" do
      assert NDB.percent_bucket(41, 100) == 8
    end

    test "returns 7 for mid-range d7 (35%)" do
      assert NDB.percent_bucket(35, 100) == 7
    end
  end

  describe "analyze/2" do
    test "returns all expected count keys" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])
      for d <- 0..8 do
        assert Map.has_key?(result, "near_dup_block_d#{d}")
      end
    end

    test "returns block_count and sub_block_count" do
      result = NDB.analyze([{"a.ex", "def foo\n  x\nend\n"}], [])
      assert Map.has_key?(result, "block_count")
      assert Map.has_key?(result, "sub_block_count")
    end

    test "block_count reflects detected blocks" do
      code = "def foo\n  x\nend\n\n\ndef bar\n  y\nend\n"
      result = NDB.analyze([{"a.ex", code}], [])
      assert result["block_count"] >= 2
    end

    test "detects exact duplicate blocks at d0" do
      # Two identical function-like blocks separated by blank lines
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "detects near-duplicate blocks (single token difference)" do
      block_a = "def foo\n  x = 1\nend\n"
      block_b = "def bar\n  x = 1\nend\n"  # one identifier differs
      result = NDB.analyze([{"a.ex", block_a <> "\n\n" <> block_b}], [])
      near_dup_total = Enum.sum(for d <- 0..8, do: result["near_dup_block_d#{d}"])
      assert near_dup_total >= 1
    end

    test "cross-file detection: same block in two files" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block}, {"b.ex", block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "returns only count keys (no pairs keys)" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])
      refute Enum.any?(Map.keys(result), &String.ends_with?(&1, "_pairs"))
    end

    test "find_pairs/2 with include_pairs option returns pair data" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], include_pairs: true)
      pairs_keys = Map.keys(result) |> Enum.filter(&String.ends_with?(&1, "_pairs"))
      assert length(pairs_keys) > 0
    end
  end
end
