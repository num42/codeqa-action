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

    test "single insertion" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a b x c]) == 1
    end

    test "single deletion" do
      assert NDB.token_edit_distance(~w[a b c d], ~w[a b d]) == 1
    end

    test "distance is symmetric" do
      a = ~w[foo bar baz]
      b = ~w[foo qux baz quux]
      assert NDB.token_edit_distance(a, b) == NDB.token_edit_distance(b, a)
    end
  end

  describe "extract_blocks/2" do
    test "returns empty for token list shorter than block size" do
      assert NDB.extract_blocks(~w[a b c], 8) == []
    end

    test "returns one block when tokens exactly equal block size" do
      tokens = Enum.map(1..8, &"t#{&1}")
      [{block, offset}] = NDB.extract_blocks(tokens, 8)
      assert block == tokens
      assert offset == 0
    end

    test "stride is block_size div 2" do
      tokens = Enum.map(1..16, &"t#{&1}")
      blocks = NDB.extract_blocks(tokens, 8)
      offsets = Enum.map(blocks, &elem(&1, 1))
      assert offsets == [0, 4, 8]
    end

    test "each block has exactly block_size tokens" do
      tokens = Enum.map(1..32, &"t#{&1}")
      blocks = NDB.extract_blocks(tokens, 8)
      assert Enum.all?(blocks, fn {block, _} -> length(block) == 8 end)
    end
  end

  describe "find_pairs/2" do
    test "finds no pairs when all blocks are identical (edit distance 0)" do
      block = ~w[a b c d e f g h]
      labeled = [{block, 0}, {block, 4}]
      result = NDB.find_pairs(labeled, max_distance: 8, max_pairs_per_bucket: nil)
      assert result == %{}
    end

    test "finds a pair at edit distance 1" do
      base  = ~w[a b c d e f g h]
      near  = ~w[a b c d e f g x]
      labeled = [{base, 0}, {near, 4}]
      result = NDB.find_pairs(labeled, max_distance: 8, max_pairs_per_bucket: nil)
      assert Map.get(result, {8, 1}) != nil
      assert Map.get(result, {8, 1}).count == 1
    end

    test "does not report pairs with edit distance > max_distance" do
      a = ~w[a b c d e f g h]
      b = ~w[1 2 3 4 5 6 7 8]
      labeled = [{a, 0}, {b, 4}]
      result = NDB.find_pairs(labeled, max_distance: 3, max_pairs_per_bucket: nil)
      assert result == %{}
    end

    test "caps pairs list at max_pairs_per_bucket" do
      base = ~w[a b c d e f g h]
      variants = for i <- 1..6, do: {List.replace_at(base, 7, "x#{i}"), i * 4}
      labeled = [{base, 0} | variants]
      result = NDB.find_pairs(labeled, max_distance: 8, max_pairs_per_bucket: 2)
      bucket = Map.get(result, {8, 1})
      assert bucket.count >= 2
      assert length(bucket.pairs) <= 2
    end
  end

  describe "analyze/3" do
    test "returns zero counts for a file with too few tokens" do
      result = NDB.analyze([{"short", ~w[a b c]}], [], [])
      assert Map.get(result, "near_dup_8_d1") == 0
    end

    test "detects within-file near-duplicate blocks" do
      block   = ~w[a b c d e f g h]
      variant = ~w[a b c d e f g x]
      tokens  = block ++ variant
      result = NDB.analyze([{"file.ex", tokens}], [], max_pairs_per_bucket: nil)
      assert Enum.any?(result, fn {k, v} -> String.contains?(k, "near_dup_8_d") and v > 0 end)
    end

    test "output map contains all expected count keys" do
      result = NDB.analyze([{"f", ~w[a b c d e f g h]}], [], [])
      for b <- [8, 16, 32, 64, 128, 256], d <- 1..8 do
        assert Map.has_key?(result, "near_dup_#{b}_d#{d}")
      end
    end
  end
end
