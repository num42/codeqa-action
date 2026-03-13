defmodule CodeQA.Metrics.IdentifierLengthVariance do
  @moduledoc """
  Measures the mean, variance, and maximum length of identifiers.

  High variance suggests inconsistent naming conventions (mixing very short
  and very long names), while an extreme maximum may flag overly verbose
  identifiers.

  See [identifier naming](https://en.wikipedia.org/wiki/Identifier_(computer_languages))
  and [variance](https://en.wikipedia.org/wiki/Variance).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "identifier_length_variance"

  @impl true
  def analyze(%{identifiers: identifiers}) do
    list = Tuple.to_list(identifiers)

    if list == [] do
      %{"mean" => 0.0, "variance" => 0.0, "max" => 0}
    else
      lengths = Enum.map(list, &String.length/1)
      n = length(lengths)
      mean = Enum.sum(lengths) / n

      variance =
        lengths
        |> Enum.reduce(0.0, fn l, acc -> acc + :math.pow(l - mean, 2) end)
        |> Kernel./(n)

      %{
        "mean" => Float.round(mean, 4),
        "variance" => Float.round(variance, 4),
        "max" => Enum.max(lengths)
      }
    end
  end
end
