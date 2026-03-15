defmodule CodeQA.Metrics.BlockDetector do
  @moduledoc """
  Detects natural code blocks from a structural token stream.

  Uses BlankLineRule to find top-level block boundaries, then
  BracketRule (and ColonIndentationRule for Python) to find sub-blocks.
  """

  alias CodeQA.Metrics.Block
  alias CodeQA.Metrics.BlockRules.{BlankLineRule, BracketRule, ColonIndentationRule}

  @spec detect_blocks([String.t()], keyword()) :: [Block.t()]
  def detect_blocks([], _opts), do: []

  def detect_blocks(tokens, opts) do
    language = Keyword.get(opts, :language, :unknown)

    split_points =
      BlankLineRule.detect(tokens, opts)
      |> Enum.map(fn {:split, idx} -> idx end)
      |> Enum.sort()

    tokens
    |> split_at(split_points)
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.map(fn block_tokens ->
      sub_blocks = detect_sub_blocks(block_tokens, language, opts)
      line_count = Enum.count(block_tokens, &(&1 == "<NL>")) + 1

      %Block{
        tokens: block_tokens,
        line_count: line_count,
        sub_blocks: sub_blocks
      }
    end)
  end

  @spec language_from_path(String.t()) :: atom()
  def language_from_path(path) do
    case Path.extname(path) do
      ".py" -> :python
      _     -> :unknown
    end
  end

  defp detect_sub_blocks(tokens, language, opts) do
    rules = sub_block_rules(language)

    rules
    |> Enum.flat_map(fn rule -> rule.detect(tokens, opts) end)
    |> Enum.filter(&match?({:enclosure, _, _}, &1))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn {:enclosure, s, e} ->
      sub_tokens = Enum.slice(tokens, s..e)
      line_count = Enum.count(sub_tokens, &(&1 == "<NL>")) + 1
      %Block{tokens: sub_tokens, line_count: line_count, sub_blocks: []}
    end)
  end

  defp sub_block_rules(:python), do: [BracketRule, ColonIndentationRule]
  defp sub_block_rules(_),       do: [BracketRule]

  defp split_at(tokens, []), do: [tokens]

  defp split_at(tokens, split_points) do
    boundaries = [0 | split_points] ++ [length(tokens)]

    boundaries
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [start, stop] -> Enum.slice(tokens, start..(stop - 1)) end)
  end
end
