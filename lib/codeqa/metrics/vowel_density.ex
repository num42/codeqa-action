defmodule CodeQA.Metrics.VowelDensity do
  @moduledoc """
  Measures the density of vowels in identifiers.

  Counts vowels (a, e, i, o, u, y) as a proportion of total identifier
  characters. Low vowel density may indicate heavy abbreviation or
  consonant-heavy naming that reduces readability.

  See [identifier naming](https://en.wikipedia.org/wiki/Identifier_(computer_languages)).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @vowels MapSet.new(~c"aeiouyAEIOUY")

  @impl true
  def name, do: "vowel_density"

  @impl true
  def keys, do: ["density", "vowel_count", "total_chars"]


  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{identifiers: identifiers}) do
    list = Tuple.to_list(identifiers)

    if list == [] do
      %{"density" => 0.0, "vowel_count" => 0, "total_chars" => 0}
    else
      {vowels, chars} =
        list
        |> Enum.reduce({0, 0}, fn id, {v, c} ->
          id_chars = String.length(id)
          id_vowels = id |> String.graphemes() |> Enum.count(&MapSet.member?(@vowels, &1))
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
