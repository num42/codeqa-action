defmodule CodeQA.BlockImpact.FileImpact do
  @moduledoc """
  Leave-one-out file metrics: reconstruct file content without a target node's tokens
  and return the re-run file metrics map.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Engine.Analyzer

  @min_tokens 10

  @doc """
  Computes file metrics for the content with the target node's tokens removed.

  Returns `nil` if the node has fewer than `#{@min_tokens}` tokens.
  Returns a raw `%{"group" => %{"key" => value}}` metrics map otherwise.
  """
  @spec compute(String.t(), Node.t()) :: map() | nil
  def compute(_content, %Node{tokens: tokens}) when length(tokens) < @min_tokens, do: nil

  def compute(content, node) do
    root_tokens = TokenNormalizer.normalize_structural(content)
    reconstructed = reconstruct_without(root_tokens, node)
    Analyzer.analyze_file("", reconstructed)
  end

  @spec reconstruct_without([CodeQA.AST.Lexing.Token.t()], Node.t()) :: String.t()
  def reconstruct_without(root_tokens, %Node{tokens: []}),
    do: root_tokens |> Enum.map_join("", & &1.content)

  def reconstruct_without(root_tokens, node) do
    first = List.first(node.tokens)

    case root_tokens
         |> Enum.find_index(fn t -> t.line == first.line and t.col == first.col end) do
      nil ->
        root_tokens |> Enum.map_join("", & &1.content)

      start_idx ->
        end_idx = start_idx + length(node.tokens)
        remaining = Enum.take(root_tokens, start_idx) ++ Enum.drop(root_tokens, end_idx)
        remaining |> Enum.map_join("", & &1.content)
    end
  end

  @doc """
  Cuts the node's source span out of the original `content`, byte-exact.

  Returns `{block, reconstructed}`: the verbatim original bytes of the block and
  the original file with that span removed. Unlike `reconstruct_without/2`, this
  never re-joins normalized tokens, so it preserves whitespace, indentation, and
  non-ASCII exactly — the precondition for a subtractive leave-one-out metric to
  match a full re-analyze.

  Offsets come from the first and last token's 1-based `line` and 0-based byte
  `col`; the block end is the last token's start plus its content's byte size. A
  node with no tokens, or whose first token can't be located in `content`,
  returns `{"", content}` (no block to remove).
  """
  @spec slice_without_original(String.t(), Node.t()) :: {String.t(), String.t()}
  def slice_without_original(content, %Node{tokens: []}), do: {"", content}

  def slice_without_original(content, %Node{tokens: tokens}) do
    first = List.first(tokens)
    last = List.last(tokens)
    line_offsets = line_start_offsets(content)

    with start_off when is_integer(start_off) <- offset_at(line_offsets, first.line, first.col),
         end_off when is_integer(end_off) <-
           offset_at(line_offsets, last.line, last.col + byte_size(last.content)),
         true <- end_off > start_off and end_off <= byte_size(content) do
      block = binary_part(content, start_off, end_off - start_off)
      head = binary_part(content, 0, start_off)
      tail = binary_part(content, end_off, byte_size(content) - end_off)
      {block, head <> tail}
    else
      _ -> {"", content}
    end
  end

  # Byte offset of each line's start: offsets[n] is the byte index where the
  # (1-based) n-th line begins. Each line contributes its bytes plus one for the
  # `\n` separator.
  defp line_start_offsets(content) do
    content
    |> String.split("\n")
    |> Enum.scan(0, fn line, acc -> acc + byte_size(line) + 1 end)
    |> then(&[0 | &1])
  end

  defp offset_at(line_offsets, line, col) when line >= 1 do
    case Enum.at(line_offsets, line - 1) do
      nil -> nil
      base -> base + col
    end
  end

  defp offset_at(_line_offsets, _line, _col), do: nil
end
