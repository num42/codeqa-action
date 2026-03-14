defmodule CodeQA.Metrics.NearDuplicateBlocksFileTest do
  use ExUnit.Case, async: true

  alias CodeQA.Metrics.NearDuplicateBlocksFile
  alias CodeQA.Pipeline

  defp ctx(code), do: Pipeline.build_file_context(code)

  describe "name/0" do
    test "returns near_duplicate_blocks_file" do
      assert NearDuplicateBlocksFile.name() == "near_duplicate_blocks_file"
    end
  end

  describe "keys/0" do
    test "returns 48 count keys" do
      keys = NearDuplicateBlocksFile.keys()
      assert length(keys) == 48
      assert "near_dup_8_d1" in keys
      assert "near_dup_256_d8" in keys
    end
  end

  describe "analyze/1" do
    test "returns a map with all count keys" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1"))
      for b <- [8, 16, 32, 64, 128, 256], d <- 1..8 do
        assert Map.has_key?(result, "near_dup_#{b}_d#{d}")
      end
    end

    test "returns 0 counts for a trivially short file" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1"))
      assert result["near_dup_8_d1"] == 0
    end

    test "detects a near-duplicate 8-token block in a repeated snippet" do
      # After normalization: identifiers -> <ID>, numbers -> <NUM>
      # block: "foo foo foo foo foo foo foo foo" -> 8x <ID>
      # variant: "foo foo foo foo foo foo foo 1"  -> 7x <ID> + <NUM>
      # These differ by 1 token (edit distance = 1), so they are near-duplicates.
      block = "foo foo foo foo foo foo foo foo\n"
      variant = "foo foo foo foo foo foo foo 1\n"
      code = String.duplicate(block, 4) <> String.duplicate(variant, 4)
      result = NearDuplicateBlocksFile.analyze(ctx(code))
      near_dup_sum = for b <- [8], d <- 1..8, reduce: 0 do
        acc -> acc + result["near_dup_#{b}_d#{d}"]
      end
      assert near_dup_sum > 0
    end
  end
end
