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
end
