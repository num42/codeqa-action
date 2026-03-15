defmodule CodeQA.Metrics.NearDuplicateBlocksFileTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.NearDuplicateBlocksFile
  alias CodeQA.Pipeline

  defp ctx(code, path \\ "test.ex") do
    base = Pipeline.build_file_context(code)
    Map.put(base, :path, path)
  end

  describe "name/0" do
    test "returns near_duplicate_blocks_file" do
      assert NearDuplicateBlocksFile.name() == "near_duplicate_blocks_file"
    end
  end

  describe "keys/0" do
    test "returns 11 keys: block_count, sub_block_count, and d0..d8" do
      keys = NearDuplicateBlocksFile.keys()
      assert length(keys) == 11
      assert "block_count" in keys
      assert "sub_block_count" in keys
      assert "near_dup_block_d0" in keys
      assert "near_dup_block_d8" in keys
    end
  end

  describe "analyze/1" do
    test "returns a map with all expected keys" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1\n"))
      assert Map.has_key?(result, "block_count")
      assert Map.has_key?(result, "sub_block_count")
      for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}"))
    end

    test "no _pairs keys in output" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1\n"))
      refute Enum.any?(Map.keys(result), &String.ends_with?(&1, "_pairs"))
    end

    test "detects exact duplicate blocks at d0" do
      block = "def foo\n  x = 1\nend\n"
      result = NearDuplicateBlocksFile.analyze(ctx(block <> "\n\n" <> block))
      assert result["near_dup_block_d0"] >= 1
    end

    test "block_count is positive for non-trivial file" do
      result = NearDuplicateBlocksFile.analyze(ctx("def foo\n  x\nend\n"))
      assert result["block_count"] >= 1
    end
  end
end
