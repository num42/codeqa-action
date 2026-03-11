defmodule CodeQA.HealthReport.Config do
  @moduledoc "Loads and merges health report configuration from YAML."

  alias CodeQA.HealthReport.Categories

  @spec load(String.t() | nil) :: %{categories: [map()], grade_scale: [{number(), String.t()}]}
  def load(nil), do: %{categories: Categories.defaults(), grade_scale: Categories.default_grade_scale()}

  def load(path) do
    yaml = YamlElixir.read_from_file!(path)
    overrides = Map.get(yaml, "categories", %{})

    defaults = Categories.defaults()
    defaults_by_key = Map.new(defaults, &{Atom.to_string(&1.key), &1})

    merged_keys =
      MapSet.union(
        MapSet.new(Map.keys(defaults_by_key)),
        MapSet.new(Map.keys(overrides))
      )

    categories =
      merged_keys
      |> Enum.sort()
      |> Enum.map(fn key ->
        default = Map.get(defaults_by_key, key)
        override = Map.get(overrides, key)
        merge_category(key, default, override)
      end)

    grade_scale = parse_grade_scale(Map.get(yaml, "grade_scale"))

    %{categories: categories, grade_scale: grade_scale}
  end

  defp parse_grade_scale(nil), do: Categories.default_grade_scale()

  defp parse_grade_scale(entries) when is_list(entries) do
    entries
    |> Enum.map(fn entry ->
      {entry["min"], entry["grade"]}
    end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
  end

  defp merge_category(key, nil, override) do
    # New category from YAML only
    %{
      key: String.to_atom(key),
      name: Map.get(override, "name", key),
      metrics: Enum.map(Map.get(override, "metrics", []), &parse_metric/1)
    }
    |> maybe_put_top(override)
  end

  defp merge_category(_key, default, nil), do: default

  defp merge_category(_key, default, override) do
    override_metrics = Map.get(override, "metrics", [])
    name = Map.get(override, "name", default.name)
    merged_metrics = merge_metrics(default.metrics, override_metrics)
    %{default | name: name, metrics: merged_metrics}
    |> maybe_put_top(override)
  end

  defp maybe_put_top(category, %{"top" => n}) when is_integer(n), do: Map.put(category, :top, n)
  defp maybe_put_top(category, _override), do: category

  defp merge_metrics(defaults, overrides) do
    overrides_by_name = Map.new(overrides, &{&1["name"], &1})
    default_names = MapSet.new(defaults, & &1.name)

    merged_defaults =
      Enum.map(defaults, fn default_metric ->
        case Map.get(overrides_by_name, default_metric.name) do
          nil -> default_metric
          override -> merge_metric(default_metric, override)
        end
      end)

    # Append new metrics from YAML that aren't in defaults
    new_metrics =
      overrides
      |> Enum.reject(fn o -> MapSet.member?(default_names, o["name"]) end)
      |> Enum.map(&parse_metric/1)

    merged_defaults ++ new_metrics
  end

  defp merge_metric(default, override) do
    thresholds =
      case Map.get(override, "thresholds") do
        nil -> default.thresholds
        t -> Map.merge(default.thresholds, atomize_thresholds(t))
      end

    good =
      if Map.has_key?(override, "good"),
        do: parse_good(override["good"]),
        else: default.good

    %{
      name: default.name,
      source: Map.get(override, "source", default.source),
      weight: Map.get(override, "weight", default.weight),
      good: good,
      thresholds: thresholds
    }
  end

  defp parse_metric(m) do
    %{
      name: m["name"],
      source: m["source"],
      weight: m["weight"],
      good: parse_good(m["good"]),
      thresholds: atomize_thresholds(Map.get(m, "thresholds", %{}))
    }
  end

  defp parse_good(nil), do: :low
  defp parse_good("high"), do: :high
  defp parse_good("low"), do: :low
  defp parse_good(atom) when is_atom(atom), do: atom

  defp atomize_thresholds(t) do
    Map.new(t, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  end
end
