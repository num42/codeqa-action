defmodule CodeQA.CombinedMetrics.Scorer do
  @moduledoc """
  Pure computation engine for combined metric formulas.

  Loads scalar weights from a YAML file and computes a score as a product of
  metric powers:

      score = metric_a ^ s_a  *  metric_b ^ s_b  *  ...

  Scalars of 0.0 contribute nothing (x^0 = 1.0) and are the default for all
  metric keys not listed in the YAML. Negative scalars penalise a metric
  (higher raw value → lower score).
  """

  @doc """
  Computes the score for `metric_name` using scalars from `yaml_path`.

  `metrics` is the `codebase.aggregate` map returned by `codeqa analyze`.
  """
  @spec compute_score(String.t(), String.t(), map()) :: float()
  def compute_score(yaml_path, metric_name, metrics) do
    default_scalars()
    |> Map.merge(scalars_for(yaml_path, metric_name))
    |> Enum.reduce(1.0, fn {{group, key}, scalar}, acc ->
      acc * pow(get(metrics, group, key), scalar)
    end)
  end

  @doc "Returns the non-zero scalar overrides for `metric_name` from `yaml_path`."
  @spec scalars_for(String.t(), String.t()) :: %{{String.t(), String.t()} => float()}
  def scalars_for(yaml_path, metric_name) do
    yaml_path
    |> yaml_data()
    |> Map.get(metric_name, %{})
    |> Enum.flat_map(fn
      {group, keys} when is_map(keys) ->
        Enum.map(keys, fn {key, scalar} -> {{group, key}, scalar / 1.0} end)
      _ ->
        []
    end)
    |> Map.new()
  end

  @doc "Returns the full default scalar map: all registered file metric keys mapped to 0.0."
  @spec default_scalars() :: %{{String.t(), String.t()} => float()}
  def default_scalars do
    CodeQA.Analyzer.build_registry().file_metrics
    |> Enum.flat_map(fn mod ->
      Enum.map(mod.keys(), fn key -> {{mod.name(), "mean_" <> key}, 0.0} end)
    end)
    |> Map.new()
  end

  @doc "Safely fetches a nested metric value, returning 1.0 if missing or non-positive."
  @spec get(map(), String.t(), String.t()) :: float()
  def get(metrics, group, key) do
    case get_in(metrics, [group, key]) do
      val when is_number(val) and val > 0 -> val / 1.0
      _ -> 1.0
    end
  end

  @doc "Computes `base ^ scalar`, returning 1.0 for non-positive bases."
  @spec pow(float(), float()) :: float()
  def pow(base, scalar) when base > 0, do: :math.pow(base, scalar)
  def pow(_base, _scalar), do: 1.0

  defp yaml_data(yaml_path) do
    {:ok, data} = YamlElixir.read_from_file(yaml_path)
    data
  end
end
