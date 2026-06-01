defmodule CodeQA.Metrics.File.LinePatterns do
  @moduledoc """
  Structural line-level and nesting metrics.

  ## Output keys

  - `"blank_line_ratio"` — blank lines / total lines (spacing/organisation signal)
  - `"unique_line_ratio"` — distinct non-blank trimmed lines / total non-blank lines
    (low values indicate repetition or boilerplate)
  - `"max_nesting_depth"` — maximum bracket nesting depth across `()`, `[]`, `{}`
    (complexity proxy independent of branching keywords)
  - `"string_literal_ratio"` — quoted string literal spans / total tokens
    (high values may indicate magic strings or hardcoded data)
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "line_patterns"

  @impl true
  def keys,
    do: ["blank_line_ratio", "unique_line_ratio", "max_nesting_depth", "string_literal_ratio"]

  @string_literal ~r/(?:"[^"]*"|'[^']*')/

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: content, lines: lines, tokens: tokens}) do
    total_lines = length(lines)
    total_tokens = length(tokens)

    if total_lines == 0 do
      %{
        "blank_line_ratio" => 0.0,
        "unique_line_ratio" => 1.0,
        "max_nesting_depth" => 0,
        "string_literal_ratio" => 0.0
      }
    else
      blank_count = Enum.count(lines, &(String.trim(&1) == ""))
      blank_ratio = Float.round(blank_count / total_lines, 4)

      non_blank = lines |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

      unique_ratio =
        if non_blank == [],
          do: 1.0,
          else: Float.round(length(Enum.uniq(non_blank)) / length(non_blank), 4)

      string_count = @string_literal |> Regex.scan(content) |> length()

      string_ratio =
        if total_tokens == 0,
          do: 0.0,
          else: Float.round(string_count / total_tokens, 4)

      %{
        "blank_line_ratio" => blank_ratio,
        "unique_line_ratio" => unique_ratio,
        "max_nesting_depth" => max_nesting_depth(content),
        "string_literal_ratio" => string_ratio
      }
    end
  end

  defp max_nesting_depth(content) do
    content
    |> String.graphemes()
    |> Enum.reduce({0, 0}, fn
      char, {depth, max_d} when char in ["(", "[", "{"] ->
        new_depth = depth + 1
        {new_depth, max(max_d, new_depth)}

      char, {depth, max_d} when char in [")", "]", "}"] ->
        {max(depth - 1, 0), max_d}

      _, acc ->
        acc
    end)
    |> elem(1)
  end
end
