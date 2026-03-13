defmodule CodeQA.Metrics.Heaps do
  @moduledoc false

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "heaps"

  @max_samples 50

  @impl true
  def analyze(%{tokens: tokens}) when tuple_size(tokens) == 0 do
    %{"k" => 0.0, "beta" => 0.0, "r_squared" => 0.0}
  end

  def analyze(%{tokens: tokens}) do
    token_list = Tuple.to_list(tokens)
    total = length(token_list)
    interval = max(1, div(total, @max_samples))

    data_points = sample_vocabulary_growth(token_list, interval)

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
      seen = MapSet.put(seen, token)

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
    ns = Enum.map(data_points, fn {n, _v} -> n / 1 end)
    vs = Enum.map(data_points, fn {_n, v} -> v / 1 end)

    log_ns = Nx.tensor(ns, type: :f64) |> Nx.log()
    log_vs = Nx.tensor(vs, type: :f64) |> Nx.log()

    {slope, intercept, r_squared} = CodeQA.Math.linear_regression(log_ns, log_vs)

    k = :math.exp(Nx.to_number(intercept))
    beta = Nx.to_number(slope)
    r_sq = Nx.to_number(r_squared)

    %{"k" => k, "beta" => beta, "r_squared" => r_sq}
  end
end
