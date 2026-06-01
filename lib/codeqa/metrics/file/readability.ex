defmodule CodeQA.Metrics.File.Readability do
  @moduledoc """
  Computes adapted Flesch and Fog readability indices for source code.

  Treats tokens-per-line as words-per-sentence and uses identifier complexity
  as a proxy for syllable count. Higher Flesch scores indicate more readable
  code; higher Fog scores indicate more complex code.

  See [Flesch reading ease](https://en.wikipedia.org/wiki/Flesch%E2%80%93Kincaid_readability_tests)
  and [Gunning fog index](https://en.wikipedia.org/wiki/Gunning_fog_index).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "readability"

  @impl true
  def keys,
    do: [
      "avg_tokens_per_line",
      "avg_line_length",
      "avg_sub_words_per_id",
      "flesch_adapted",
      "fog_adapted",
      "total_lines"
    ]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(ctx) do
    lines =
      ctx.lines
      |> Enum.filter(fn line ->
        trimmed = String.trim(line)
        trimmed != "" and not String.starts_with?(trimmed, "#")
      end)

    if lines == [] do
      %{
        "avg_tokens_per_line" => 0.0,
        "avg_line_length" => 0.0,
        "avg_sub_words_per_id" => 0.0,
        "flesch_adapted" => 0.0,
        "fog_adapted" => 0.0,
        "total_lines" => 0
      }
    else
      compute_readability(ctx, lines)
    end
  end

  defp compute_readability(ctx, lines) do
    total_lines = length(lines)
    total_tokens = length(ctx.tokens)
    avg_tokens = total_tokens / total_lines
    avg_line_length = lines |> Enum.map(&String.length/1) |> Enum.sum() |> Kernel./(total_lines)

    words = ctx.words

    {avg_sub_words, complex_fraction} =
      if words != [] do
        sub_counts = Enum.map(words, &length(split_identifier(&1)))
        avg = Enum.sum(sub_counts) / length(sub_counts)
        complex = Enum.count(sub_counts, &(&1 > 2)) / length(sub_counts)
        {avg, complex}
      else
        {0.0, 0.0}
      end

    flesch = 206.835 - 1.015 * avg_tokens - 84.6 * avg_sub_words
    fog = 0.4 * (avg_tokens + 100 * complex_fraction)

    %{
      "avg_tokens_per_line" => Float.round(avg_tokens, 4),
      "avg_line_length" => Float.round(avg_line_length, 4),
      "avg_sub_words_per_id" => Float.round(avg_sub_words, 4),
      "flesch_adapted" => Float.round(flesch, 4),
      "fog_adapted" => Float.round(fog, 4),
      "total_lines" => total_lines
    }
  end

  defp split_identifier(name) do
    # Efficient split without Regex
    # We split by underscores and then by transitions from lowercase to uppercase
    name
    |> String.split("_")
    |> Enum.flat_map(fn part ->
      part
      |> String.to_charlist()
      |> split_camel_case([])
      |> Enum.map(&List.to_string/1)
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_camel_case([], []), do: []
  defp split_camel_case([], [current | rest]), do: Enum.reverse([Enum.reverse(current) | rest])
  defp split_camel_case([char | rest], []), do: split_camel_case(rest, [[char]])

  defp split_camel_case([char | rest], [current | acc_rest]) do
    # If current char is uppercase and previous (head of current) was lowercase, start new part
    prev = hd(current)

    if char in ?A..?Z and prev in ?a..?z do
      split_camel_case(rest, [[char] | [Enum.reverse(current) | acc_rest]])
    else
      split_camel_case(rest, [[char | current] | acc_rest])
    end
  end
end
