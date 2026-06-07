defmodule CodeQA.Metrics.File.VowelDensity do
  @moduledoc """
  Measures the density of vowels in identifiers.

  Counts vowels (a, e, i, o, u, y) as a proportion of total identifier
  characters. Low vowel density may indicate heavy abbreviation or
  consonant-heavy naming that reduces readability.

  See [identifier naming](https://en.wikipedia.org/wiki/Identifier_(computer_languages)).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @vowels MapSet.new(~c"aeiouyAEIOUY")

  @impl true
  def name, do: "vowel_density"

  @impl true
  def keys, do: ["density", "vowel_count", "total_chars"]

  # Counts are over identifiers, which a block cut never splits (cuts fall on
  # token boundaries). So file-minus-block counts are baseline minus the block's
  # own counts; density is recomputed from the subtracted totals. The block's
  # identifiers are extracted by the same pipeline as the baseline (build a
  # context over the block's verbatim source), so the subtraction is exact — the
  # subtractive_loo guard asserts this matches a full re-analyze.
  @spec analyze_loo(map(), CodeQA.Engine.FileContext.t()) :: map()
  @impl true
  def analyze_loo(baseline, block_ctx) do
    block = analyze(block_ctx)
    vowels = baseline["vowel_count"] - block["vowel_count"]
    chars = baseline["total_chars"] - block["total_chars"]
    density = if chars == 0, do: 0.0, else: Float.round(vowels / chars, 4)
    %{"density" => density, "vowel_count" => vowels, "total_chars" => chars}
  end

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{identifiers: identifiers}) do
    list = identifiers

    if list == [] do
      %{"density" => 0.0, "vowel_count" => 0, "total_chars" => 0}
    else
      {vowels, chars} =
        list
        |> Enum.reduce({0, 0}, fn identifier, {v, c} ->
          id_chars = String.length(identifier)
          id_vowels = identifier |> String.graphemes() |> Enum.count(&MapSet.member?(@vowels, &1))
          {v + id_vowels, c + id_chars}
        end)

      if chars == 0 do
        %{"density" => 0.0, "vowel_count" => 0, "total_chars" => 0}
      else
        %{
          "density" => Float.round(vowels / chars, 4),
          "vowel_count" => vowels,
          "total_chars" => chars
        }
      end
    end
  end
end
