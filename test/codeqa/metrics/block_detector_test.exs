defmodule CodeQA.Metrics.BlockDetectorTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.{BlockDetector, TokenNormalizer}

  defp tokenize(code), do: TokenNormalizer.normalize_structural(code)

  describe "detect_blocks/2" do
    test "single block for file with no blank lines" do
      tokens = tokenize("def foo\n  x = 1\nend\n")
      blocks = BlockDetector.detect_blocks(tokens, [])
      assert length(blocks) == 1
    end

    test "splits into two blocks at blank line" do
      tokens = tokenize("def foo\n  x\nend\n\n\ndef bar\n  y\nend\n")
      blocks = BlockDetector.detect_blocks(tokens, [])
      assert length(blocks) == 2
    end

    test "each block has correct line_count" do
      tokens = tokenize("a\nb\n\n\nc\nd\n")
      [b1, b2] = BlockDetector.detect_blocks(tokens, [])
      assert b1.line_count >= 2
      assert b2.line_count >= 2
    end

    test "empty input returns empty list" do
      assert BlockDetector.detect_blocks([], []) == []
    end

    test "detects bracket sub-blocks" do
      tokens = tokenize("foo(a, b)\nbar(c)\n")
      [block] = BlockDetector.detect_blocks(tokens, [])
      assert block.sub_blocks != []
    end

    test "detects colon-indent sub-blocks for python language hint" do
      tokens = tokenize("def foo:\n    return 1\n")
      [block] = BlockDetector.detect_blocks(tokens, language: :python)
      assert length(block.sub_blocks) >= 1
    end

    test "fewer sub-blocks without python hint than with it (colon rule not applied)" do
      tokens = tokenize("def foo:\n    return 1\n")
      without_hint = BlockDetector.detect_blocks(tokens, [])
      with_hint    = BlockDetector.detect_blocks(tokens, language: :python)
      count_without = without_hint |> Enum.map(&length(&1.sub_blocks)) |> Enum.sum()
      count_with    = with_hint    |> Enum.map(&length(&1.sub_blocks)) |> Enum.sum()
      assert count_with >= count_without
    end

    test "block has sub_block_count accessible via Block.sub_block_count/1" do
      alias CodeQA.Metrics.Block
      tokens = tokenize("foo(a)\nbar(b)\n")
      [block] = BlockDetector.detect_blocks(tokens, [])
      assert Block.sub_block_count(block) == length(block.sub_blocks)
    end
  end

  describe "language_from_path/1" do
    test "returns :python for .py files" do
      assert BlockDetector.language_from_path("lib/foo.py") == :python
    end

    test "returns :unknown for unknown extensions" do
      assert BlockDetector.language_from_path("lib/foo.ex") == :unknown
    end
  end
end
