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
end
