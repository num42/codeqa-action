defmodule CodeQA.Metrics.File.Heaps do
  @moduledoc """
  Fits Heaps' law to vocabulary growth in a file.

  Samples the token stream at increasing sizes and fits a power-law curve
  `V = k * N^beta` via log-linear regression. The beta exponent and R-squared
  goodness-of-fit indicate how predictably new vocabulary is introduced.

  See [Heaps' law](https://en.wikipedia.org/wiki/Heaps%27_law).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "heaps"

  @impl true
  def keys, do: ["k", "beta", "r_squared"]

  @max_samples 50

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{tokens: []}) do
    %{"k" => 0.0, "beta" => 0.0, "r_squared" => 0.0}
  end

  def analyze(%{tokens: tokens}) do
    total = length(tokens)
    interval = max(1, div(total, @max_samples))

    data_points = sample_vocabulary_growth(tokens, interval)

    if length(data_points) < 5 do
      %{"k" => 0.0, "beta" => 0.0, "r_squared" => 0.0}
    else
      fit_heaps(data_points)
    end
  end

  defp sample_vocabulary_growth(tokens, interval) do
    tokens
    |> Enum.with_index(1)
    |> Enum.reduce({MapSet.new(), []}, fn {token, i}, {seen, points} ->
      seen = MapSet.put(seen, token.content)

      if rem(i, interval) == 0 do
        {seen, [{i, MapSet.size(seen)} | points]}
      else
        {seen, points}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp fit_heaps(data_points) do
    # log(V) = log(k) + β * log(n)  →  linear regression in log-space
    ns = Enum.map(data_points, &elem(&1, 0))
    vs = Enum.map(data_points, &elem(&1, 1))

    log_ns = Nx.tensor(ns, type: :f64) |> Nx.log()
    log_vs = Nx.tensor(vs, type: :f64) |> Nx.log()

    {slope, intercept, r_squared} = CodeQA.Math.linear_regression(log_ns, log_vs)

    k = :math.exp(Nx.to_number(intercept))
    beta = Nx.to_number(slope)
    r_sq = Nx.to_number(r_squared)

    %{
      "k" => Float.round(k, 4),
      "beta" => Float.round(beta, 4),
      "r_squared" => Float.round(r_sq, 4)
    }
  end
end
