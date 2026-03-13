defmodule CodeQA.Metrics.Indentation do
  @moduledoc false

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "indentation"

  @impl true
  def analyze(%{lines: lines}) do
    lines_list = Tuple.to_list(lines)

    depths =
      lines_list
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn line ->
        [leading] = Regex.run(~r/^\s*/, line)
        String.length(leading)
      end)

    if depths == [] do
      %{"mean_depth" => 0.0, "max_depth" => 0, "variance" => 0.0}
    else
      n = length(depths)
      mean = Enum.sum(depths) / n

      variance =
        depths
        |> Enum.reduce(0.0, fn d, acc -> acc + :math.pow(d - mean, 2) end)
        |> Kernel./(n)

      %{
        "mean_depth" => Float.round(mean, 4),
        "variance" => Float.round(variance, 4),
        "max_depth" => Enum.max(depths)
      }
    end
  end
end
