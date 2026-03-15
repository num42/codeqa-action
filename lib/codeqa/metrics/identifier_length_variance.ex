defmodule CodeQA.Metrics.IdentifierLengthVariance do
  @moduledoc """
  Measures the mean, variance, and maximum length of identifiers.

  High variance suggests inconsistent naming conventions (mixing very short
  and very long names), while an extreme maximum may flag overly verbose
  identifiers. Population variance (÷n) is used since the identifiers
  represent the complete file, not a sample.

  See [identifier naming](https://en.wikipedia.org/wiki/Identifier_(computer_languages))
  and [variance](https://en.wikipedia.org/wiki/Variance).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "identifier_length_variance"

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{identifiers: identifiers}) when tuple_size(identifiers) == 0 do
    %{"mean" => 0.0, "variance" => 0.0, "std_dev" => 0.0, "max" => 0}
  end

  def analyze(%{identifiers: identifiers}) do
    list = Tuple.to_list(identifiers)
    lengths = Enum.map(list, &String.length/1)
    n = length(lengths)
    mean = Enum.sum(lengths) / n

    variance =
      lengths
      |> Enum.reduce(0.0, fn l, acc -> acc + :math.pow(l - mean, 2) end)
      |> Kernel./(n)

    std_dev = :math.sqrt(variance)

    %{
      "mean" => Float.round(mean, 4),
      "variance" => Float.round(variance, 4),
      "std_dev" => Float.round(std_dev, 4),
      "max" => Enum.max(lengths)
    }
  end
end
