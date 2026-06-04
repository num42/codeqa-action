defmodule CodeQA.CombinedMetrics.ScalarApplier do
  alias CodeQA.Language

  @moduledoc """
  Writes suggested scalars and language metadata back to the combined-metrics YAML
  config files under `priv/combined_metrics/`.

  Intended for internal use by `SampleRunner`. Two entry points:

  * `apply_scalars/2`   — rewrites scalar weights using log-linear suggestions
  * `apply_languages/2` — rewrites `_languages` based on sample file extensions
  """

  alias CodeQA.CombinedMetrics.YamlFormatter

  @samples_root "priv/combined_metrics/samples"
  @yaml_dir "priv/combined_metrics"
  @deadzone_low 0.995
  @deadzone_high 1.005

  @doc """
  Applies suggested scalars from `report` (a `build_metric_report/1` result) to
  the YAML files under `priv/combined_metrics/`.

  Returns a list of per-category stats maps with `:category`, `:updated`,
  `:deadzoned`, and `:skipped` keys.
  """
  @spec apply_scalars(map(), keyword()) :: [map()]
  def apply_scalars(report, opts \\ []) do
    dir = opts[:dir] || @yaml_dir

    dir
    |> category_yamls(opts[:category])
    |> Enum.map(fn yml_file ->
      category = String.trim_trailing(yml_file, ".yml")
      yaml_path = Path.join(dir, yml_file)
      {:ok, existing} = YamlElixir.read_from_file(yaml_path)

      {updated_yaml, stats} = apply_to_category(existing, category, report)
      File.write!(yaml_path, YamlFormatter.format(updated_yaml))

      Map.put(stats, :category, category)
    end)
  end

  @doc """
  Updates only the `_languages` field in YAML config files based on sample data.

  Returns a list of `%{category: String.t(), behaviors_with_languages: non_neg_integer()}`.
  """
  @spec apply_languages(keyword()) :: [map()]
  def apply_languages(opts \\ []) do
    dir = opts[:dir] || @yaml_dir

    dir
    |> category_yamls(opts[:category])
    |> Enum.map(fn yml_file ->
      category = String.trim_trailing(yml_file, ".yml")
      yaml_path = Path.join(dir, yml_file)
      {:ok, existing} = YamlElixir.read_from_file(yaml_path)

      updated =
        existing
        |> Enum.filter(fn {_k, v} -> is_map(v) end)
        |> Map.new(fn {behavior, groups} ->
          langs = languages_for_behavior(category, behavior)
          {behavior, maybe_put_languages(groups, langs)}
        end)

      File.write!(yaml_path, YamlFormatter.format(updated))

      behaviors_with_languages =
        updated |> Enum.count(fn {_b, groups} -> Map.has_key?(groups, "_languages") end)

      %{behaviors_with_languages: behaviors_with_languages, category: category}
    end)
  end

  # ---------------------------------------------------------------------------
  # Scalar application helpers
  # ---------------------------------------------------------------------------

  defp category_yamls(dir, filter_category) do
    dir
    |> File.ls!()
    |> Enum.filter(fn yml_file ->
      String.ends_with?(yml_file, ".yml") and
        (filter_category == nil or String.trim_trailing(yml_file, ".yml") == filter_category)
    end)
    |> Enum.sort()
  end

  defp apply_to_category(existing, category, report) do
    existing
    |> Enum.filter(fn {_k, v} -> is_map(v) end)
    |> Enum.reduce({%{}, %{deadzoned: 0, skipped: 0, updated: 0}}, fn
      {behavior, current_groups}, {acc_yaml, stats} ->
        report_key = "#{category}.#{behavior}"
        doc = read_behavior_doc(category, behavior)

        case Map.get(report, report_key) do
          nil ->
            groups = maybe_put_doc(current_groups, doc)
            {Map.put(acc_yaml, behavior, groups), Map.update!(stats, :skipped, &(&1 + 1))}

          metrics ->
            apply_metrics(acc_yaml, stats, behavior, current_groups, metrics, doc)
        end
    end)
  end

  defp apply_metrics(acc_yaml, stats, behavior, current_groups, metrics, doc) do
    {new_groups, log_baseline, n_updated, n_deadzoned} = groups_from_report(metrics)
    # Fall back to current groups if everything was deadzoned
    base_groups = if map_size(new_groups) > 0, do: new_groups, else: current_groups

    groups =
      base_groups
      |> merge_meta_fields(current_groups)
      |> Map.put("_log_baseline", Float.round(log_baseline, 6))
      |> maybe_put_doc(doc)

    {Map.put(acc_yaml, behavior, groups),
     %{
       stats
       | updated: stats.updated + n_updated,
         deadzoned: stats.deadzoned + n_deadzoned
     }}
  end

  defp groups_from_report(metrics) do
    metrics
    |> Enum.reduce({%{}, 0.0, 0, 0}, fn {metric_key, data},
                                        {groups, log_baseline, n_updated, n_deadzoned} ->
      [group, key] = String.split(metric_key, ".", parts: 2)

      if deadzone?(data.ratio) do
        {groups, log_baseline, n_updated, n_deadzoned + 1}
      else
        accumulate_metric(groups, log_baseline, n_updated, n_deadzoned, group, key, data)
      end
    end)
  end

  defp accumulate_metric(groups, log_baseline, n_updated, n_deadzoned, group, key, data) do
    new_groups =
      Map.update(
        groups,
        group,
        %{key => data.suggested_scalar},
        &Map.put(&1, key, data.suggested_scalar)
      )

    geo_mean = :math.sqrt(max(data.bad, 1.0e-10) * max(data.good, 1.0e-10))
    new_baseline = log_baseline + data.suggested_scalar * :math.log(geo_mean)
    {new_groups, new_baseline, n_updated + 1, n_deadzoned}
  end

  defp deadzone?(ratio), do: ratio >= @deadzone_low and ratio <= @deadzone_high

  defp read_behavior_doc(category, behavior) do
    config_path = Path.join([@samples_root, category, behavior, "config.yml"])

    File.read(config_path) |> parse_behavior_doc()
  end

  defp maybe_put_doc(groups, nil), do: groups
  defp maybe_put_doc(groups, doc), do: Map.put(groups, "_doc", doc)

  # ---------------------------------------------------------------------------
  # Language detection helpers
  # ---------------------------------------------------------------------------

  defp dir_languages(dir), do: File.ls(dir) |> languages_from_files()

  defp languages_for_behavior(category, behavior) do
    bad_langs = dir_languages(sample_path(category, behavior, "bad"))
    good_langs = dir_languages(sample_path(category, behavior, "good"))

    bad_langs
    |> MapSet.intersection(good_langs)
    |> MapSet.to_list()
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.sort()
  end

  defp maybe_put_languages(groups, []), do: groups

  defp maybe_put_languages(groups, langs) do
    # An allowlist (`_languages`) and a blocklist (`_excludes_languages`) are
    # mutually exclusive scoping models — a hand-authored blocklist wins.
    if Map.has_key?(groups, "_excludes_languages") do
      groups
    else
      Map.put(groups, "_languages", langs)
    end
  end

  # Carry forward hand-authored meta fields (language/block-type scoping) that a
  # scalar relearn would otherwise drop. `_log_baseline` and `_doc` are excluded
  # because apply_metrics rewrites them explicitly.
  @preserved_meta ~w(_languages _excludes_languages _excludes_block_types)
  defp merge_meta_fields(groups, current_groups) do
    @preserved_meta
    |> Enum.reduce(groups, fn key, acc ->
      case Map.get(current_groups, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp sample_path(category, behavior, kind),
    do: [@samples_root, category, behavior, kind] |> Path.join()

  defp parse_behavior_doc({:ok, content}) do
    case YamlElixir.read_from_string(content) do
      {:ok, %{"doc" => doc}} when is_binary(doc) -> doc
      _ -> nil
    end
  end

  defp parse_behavior_doc(_), do: nil

  defp languages_from_files({:ok, files}),
    do:
      files
      |> Enum.map(&Language.detect/1)
      |> Enum.map(& &1.name())
      |> MapSet.new()

  defp languages_from_files(_), do: MapSet.new()
end
