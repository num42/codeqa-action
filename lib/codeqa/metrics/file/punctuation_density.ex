defmodule CodeQA.Metrics.File.PunctuationDensity do
  @moduledoc """
  Character-level punctuation and structural pattern metrics.

  Captures signals that character-level metrics miss: naming conventions using
  `?`/`!` suffixes, chained method calls (dots), non-standard bracket adjacency,
  and numeric bracket pair patterns.
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "punctuation_density"

  @impl true
  def keys do
    [
      "question_mark_density",
      "exclamation_density",
      "dot_count",
      "id_nonalpha_suffix_density",
      "bracket_nonalpha_prefix_count",
      "bracket_nonalpha_suffix_count",
      "bracket_number_pair_count",
      "arrow_density",
      "colon_suffix_density"
    ]
  end

  # identifier-like token (starts with letter/underscore) ending with non-alphanumeric non-whitespace
  @id_nonalpha_suffix ~r/[a-zA-Z_]\w*[^\w\s]/
  # opening bracket immediately preceded by non-alphanumeric non-whitespace (e.g. `?(`, `==[`)
  @bracket_nonalpha_prefix ~r/[^\w\s\(\[\{][\(\[\{]/
  # closing bracket immediately followed by non-alphanumeric non-whitespace (e.g. `}.`, `)?`)
  @bracket_nonalpha_suffix ~r/[\)\]\}][^\w\s\)\]\}]/
  # number (with optional underscores) wrapped in brackets: (42), [1_000], (3.14)
  @bracket_number_pair ~r/[\(\[]\d[\d_]*(?:\.\d+)?[\)\]]/
  # arrow operators: -> and =>
  @arrow ~r/->|=>/
  # identifier immediately followed by colon (keyword args, dict keys, labels)
  @colon_suffix ~r/[a-zA-Z_]\w*:/

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: content, tokens: tokens}) do
    total_chars = String.length(content)
    total_tokens = length(tokens)

    if total_chars == 0 do
      %{
        "question_mark_density" => 0.0,
        "exclamation_density" => 0.0,
        "dot_count" => 0,
        "id_nonalpha_suffix_density" => 0.0,
        "bracket_nonalpha_prefix_count" => 0,
        "bracket_nonalpha_suffix_count" => 0,
        "bracket_number_pair_count" => 0,
        "arrow_density" => 0.0,
        "colon_suffix_density" => 0.0
      }
    else
      qmarks = count_char(content, "?")
      excls = count_char(content, "!")
      dots = count_char(content, ".")

      id_suffix_count = count_matches(content, @id_nonalpha_suffix)
      bracket_prefix = count_matches(content, @bracket_nonalpha_prefix)
      bracket_suffix = count_matches(content, @bracket_nonalpha_suffix)
      bracket_num = count_matches(content, @bracket_number_pair)

      id_denom = max(total_tokens, 1)
      arrows = count_matches(content, @arrow)
      colon_suffixes = count_matches(content, @colon_suffix)

      %{
        "question_mark_density" => Float.round(qmarks / total_chars, 6),
        "exclamation_density" => Float.round(excls / total_chars, 6),
        "dot_count" => dots,
        "id_nonalpha_suffix_density" => Float.round(id_suffix_count / id_denom, 4),
        "bracket_nonalpha_prefix_count" => bracket_prefix,
        "bracket_nonalpha_suffix_count" => bracket_suffix,
        "bracket_number_pair_count" => bracket_num,
        "arrow_density" => Float.round(arrows / id_denom, 4),
        "colon_suffix_density" => Float.round(colon_suffixes / id_denom, 4)
      }
    end
  end

  defp count_char(content, char) do
    content |> String.graphemes() |> Enum.count(&(&1 == char))
  end

  defp count_matches(content, regex) do
    regex |> Regex.scan(content) |> length()
  end
end
