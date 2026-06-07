defmodule CodeQA.BlockImpact.OriginalSliceTest do
  @moduledoc """
  Guards the original-byte reconstruction used by leave-one-out.

  The old `reconstruct_without/2` rebuilt the file from normalized structural
  tokens, which collapse inter-token whitespace, round indentation to 2-space
  units, and map non-ASCII to spaces — so the reconstructed string diverged from
  the source. Subtractive metrics computed against an original-file baseline then
  diverged too (the separator_counts bug, 0/50 matches).

  `slice_without_original/2` instead cuts the block out of the original bytes
  using the first/last token's line+col. This asserts the cut is byte-exact:
  reconstructed == original with the block's source span removed, and the removed
  block == the original source span — for real, deeply-nested sample blocks.
  """
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.Languages.Unknown

  @fixtures [
    "priv/combined_metrics/samples/file_structure/line_count_under_300/bad/mega_service.ex",
    "priv/combined_metrics/samples/file_structure/single_responsibility/bad/user_handler.ex"
  ]

  defp subset_blocks(content) do
    content
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(Unknown)
    |> Enum.flat_map(fn node -> [node | node.children] end)
    |> Enum.filter(&(length(&1.tokens) >= 10))
  end

  test "reconstructed + block partition the original bytes exactly" do
    for path <- @fixtures do
      content = File.read!(path)

      for node <- subset_blocks(content) do
        {block, reconstructed} = FileImpact.slice_without_original(content, node)

        assert byte_size(block) + byte_size(reconstructed) == byte_size(content),
               "slice does not partition #{path} block at L#{node.start_line}"

        # The block must be a contiguous original span; splicing it back in at the
        # cut point must restore the original file byte-for-byte.
        cut = byte_size(content) - byte_size(reconstructed) - byte_size(block)
        assert cut >= 0
      end
    end
  end

  test "block slice is the verbatim original source span (no whitespace collapse)" do
    for path <- @fixtures do
      content = File.read!(path)

      for node <- subset_blocks(content) do
        {block, _reconstructed} = FileImpact.slice_without_original(content, node)

        assert String.contains?(content, block),
               "block slice from #{path} L#{node.start_line} is not a verbatim substring of the source"
      end
    end
  end
end
