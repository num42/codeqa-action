defmodule CodeQA.Metrics.CasingEntropy do
  @moduledoc false

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "casing_entropy"

  @impl true
  def analyze(%{identifiers: identifiers}) do
    identifiers_list = Tuple.to_list(identifiers)

    if identifiers_list == [] do
      %{"entropy" => 0.0}
    else
      counts =
        identifiers_list
        |> Enum.map(&CodeQA.Metrics.Inflector.detect_casing/1)
        |> Enum.frequencies()

      total = length(identifiers_list)

      entropy =
        counts
        |> Map.values()
        |> Enum.reduce(0.0, fn count, acc ->
          p = count / total
          acc - p * :math.log2(p)
        end)

      %{"entropy" => Float.round(entropy, 4)}
      |> Map.merge(
        counts
        |> Enum.map(fn {k, v} -> {"#{k}_count", v} end)
        |> Enum.into(%{})
      )
    end
  end
end
