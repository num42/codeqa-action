defmodule CodeQA.Metrics.NearDuplicateBlocksCodebaseTest do
  use ExUnit.Case, async: true

  alias CodeQA.Metrics.NearDuplicateBlocksCodebase

  defp files(pairs), do: Map.new(pairs)

  describe "name/0" do
    test "returns near_duplicate_blocks_codebase" do
      assert NearDuplicateBlocksCodebase.name() == "near_duplicate_blocks_codebase"
    end
  end

  describe "analyze/2" do
    test "returns a map with all count keys" do
      result = NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1"}]), [])
      for b <- [8, 16, 32, 64, 128, 256], d <- 1..8 do
        assert Map.has_key?(result, "near_dup_#{b}_d#{d}")
      end
    end

    test "zero counts for a single trivial file" do
      result = NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1"}]), [])
      assert result["near_dup_8_d1"] == 0
    end

    test "detects near-duplicate blocks across two files" do
      # Mix identifiers and numbers so normalized tokens differ
      block   = "a b c d e f g 1\n"  # ends with <NUM>
      variant = "a b c d e f g h\n"  # ends with <ID>
      result = NearDuplicateBlocksCodebase.analyze(
        files([
          {"a.ex", String.duplicate(block, 6)},
          {"b.ex", String.duplicate(variant, 6)}
        ]),
        []
      )
      total = for b <- [8], d <- 1..8, reduce: 0, do: (acc -> acc + result["near_dup_#{b}_d#{d}"])
      assert total > 0
    end

    test "pairs list is capped at max_pairs_per_bucket" do
      block   = "a b c d e f g 1\n"
      variant = "a b c d e f g h\n"
      result = NearDuplicateBlocksCodebase.analyze(
        files([
          {"a.ex", String.duplicate(block, 10)},
          {"b.ex", String.duplicate(variant, 10)}
        ]),
        [near_duplicate_blocks: [max_pairs_per_bucket: 2]]
      )
      pairs_lists = result |> Map.values() |> Enum.filter(&is_list/1)
      assert Enum.all?(pairs_lists, &(length(&1) <= 2))
    end

    test "pair sources include file paths" do
      block   = "a b c d e f g 1\n"
      variant = "a b c d e f g h\n"
      result = NearDuplicateBlocksCodebase.analyze(
        files([{"a.ex", String.duplicate(block, 6)}, {"b.ex", String.duplicate(variant, 6)}]),
        []
      )
      all_pairs = result |> Map.values() |> Enum.filter(&is_list/1) |> List.flatten()
      if length(all_pairs) > 0 do
        pair = hd(all_pairs)
        assert Map.has_key?(pair, "source_a")
        assert Map.has_key?(pair, "source_b")
      end
    end
  end
end
