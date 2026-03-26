defmodule CodeQA.Metrics.File.Brevity do
  @moduledoc """
  Measures how well Brevity law holds in the token distribution.

  Computes the Pearson correlation between token length and token frequency.
  A negative value indicates shorter tokens appear more often (law holds).
  A positive value indicates longer tokens appear more often (law violated).
  Also fits a log-log regression to capture the power-law slope.

  See [Brevity law](https://en.wikipedia.org/wiki/Brevity_law).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "brevity"

  @impl true
  def keys, do: ["correlation", "slope", "sample_size"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{token_counts: token_counts}) when map_size(token_counts) < 3 do
    %{"correlation" => 0.0, "slope" => 0.0, "sample_size" => map_size(token_counts)}
  end

  def analyze(%{token_counts: token_counts}) do
    pairs = Enum.map(token_counts, fn {token, freq} -> {String.length(token), freq} end)
    lengths = Enum.map(pairs, &elem(&1, 0))
    freqs = Enum.map(pairs, &elem(&1, 1))

    %{
      "correlation" => CodeQA.Math.pearson_correlation_list(lengths, freqs),
      "slope" => log_log_slope(lengths, freqs),
      "sample_size" => map_size(token_counts)
    }
  end

  defp log_log_slope(lengths, freqs) do
    log_lengths = lengths |> Enum.map(&:math.log(max(&1, 1))) |> Nx.tensor(type: :f64)
    log_freqs = freqs |> Enum.map(&:math.log(max(&1, 1))) |> Nx.tensor(type: :f64)

    {slope, _intercept, _r_squared} = CodeQA.Math.linear_regression(log_lengths, log_freqs)

    case Nx.to_number(slope) do
      val when is_float(val) -> Float.round(val, 4)
      _ -> 0.0
    end
  end
end
