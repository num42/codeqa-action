defmodule CodeQA.Metrics.Indentation do
  @moduledoc """
  Analyzes indentation depth patterns across non-blank lines.

  Reports mean depth, variance, and maximum depth. Deep or highly variable
  indentation often correlates with complex control flow. Tab characters
  count as 1 unit of depth; files mixing tabs and spaces may report
  inaccurate depth values.

  See [indentation style](https://en.wikipedia.org/wiki/Indentation_style).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "indentation"

  @impl true
  def keys, do: ["mean_depth", "variance", "max_depth", "uses_tabs"]


  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{lines: lines}) do
    lines_list = Tuple.to_list(lines)

    uses_tabs = Enum.any?(lines_list, &String.match?(&1, ~r/^\t/))

    depths =
      lines_list
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn line ->
        [leading] = Regex.run(~r/^\s*/, line)
        String.length(leading)
      end)

    if depths == [] do
      %{"mean_depth" => 0.0, "max_depth" => 0, "variance" => 0.0, "uses_tabs" => uses_tabs}
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
        "max_depth" => Enum.max(depths),
        "uses_tabs" => uses_tabs
      }
    end
  end
end
