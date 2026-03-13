defmodule CodeQA.Metrics.VowelDensity do
  @moduledoc """
  Measures the density of vowels in identifiers.

  Counts vowels (a, e, i, o, u, y) as a proportion of total identifier
  characters. Low vowel density may indicate heavy abbreviation or
  consonant-heavy naming that reduces readability.

  See [identifier naming](https://en.wikipedia.org/wiki/Identifier_(computer_languages)).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "vowel_density"

  @impl true
  def analyze(%{identifiers: identifiers}) do
    list = Tuple.to_list(identifiers)

    if list == [] do
      %{"density" => 0.0}
    else
      {vowels, chars} =
        list
        |> Enum.reduce({0, 0}, fn id, {v, c} ->
          id_chars = String.length(id)
          id_vowels = length(Regex.scan(~r/[aeiouyAEIOUY]/, id))
          {v + id_vowels, c + id_chars}
        end)

      if chars == 0 do
        %{"density" => 0.0}
      else
        %{"density" => Float.round(vowels / chars, 4)}
      end
    end
  end
end
