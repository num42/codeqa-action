defmodule CodeQA.CombinedMetrics.SampleRunner do
  @moduledoc """
  Discovers sample directories, analyzes them, and scores each behavior formula.

  Returns structured results suitable for rendering a separation table, enabling
  manual scalar tuning of combined metric formulas.
  """

  alias CodeQA.CombinedMetrics.Scorer

  @samples_root "priv/combined_metrics/samples"
  @yaml_dir "priv/combined_metrics"
  @deadzone_low 0.995
  @deadzone_high 1.005

  @doc """
  Runs all behaviors found in sample directories, optionally filtered by category.

  ## Options

    * `:category` - restrict to one category (e.g. `"variable_naming"`)
    * `:verbose`  - when `true`, populates `:metric_detail` in each result

  ## Result shape

      %{
        category:     "variable_naming",
        behavior:     "name_is_generic",
        bad_score:    0.074,
        good_score:   0.550,
        ratio:        7.43,
        direction_ok: true,
        metric_detail: [...]   # empty unless verbose: true
      }
  """
  @spec run(keyword()) :: [map()]
  def run(opts \\ []) do
    filter_category = opts[:category]

    @samples_root
    |> File.ls!()
    |> Enum.flat_map(fn category ->
      Path.join([@samples_root, category])
      |> File.ls!()
      |> Enum.map(&{category, &1})
    end)
    |> Enum.filter(fn {category, behavior} ->
      (filter_category == nil or category == filter_category) and
        has_both_dirs?(category, behavior)
    end)
    |> Enum.map(fn {category, behavior} ->
      score_behavior(category, behavior, opts)
    end)
  end

  defp has_both_dirs?(category, behavior) do
    File.dir?(sample_path(category, behavior, "bad")) and
      File.dir?(sample_path(category, behavior, "good"))
  end

  defp score_behavior(category, behavior, opts) do
    yaml_path = "priv/combined_metrics/#{category}.yml"
    bad_agg = analyze(sample_path(category, behavior, "bad"))
    good_agg = analyze(sample_path(category, behavior, "good"))

    bad_score = Scorer.compute_score(yaml_path, behavior, bad_agg)
    good_score = Scorer.compute_score(yaml_path, behavior, good_agg)
    ratio = if bad_score > 0, do: good_score / bad_score, else: 0.0

    base = %{
      category: category,
      behavior: behavior,
      bad_score: bad_score,
      good_score: good_score,
      ratio: Float.round(ratio, 2),
      direction_ok: good_score >= bad_score
    }

    if opts[:verbose] do
      Map.put(base, :metric_detail, metric_detail(yaml_path, behavior, bad_agg, good_agg))
    else
      Map.put(base, :metric_detail, [])
    end
  end

  defp analyze(dir) do
    dir
    |> CodeQA.Engine.Collector.collect_files()
    |> CodeQA.Engine.Analyzer.analyze_codebase()
    |> get_in(["codebase", "aggregate"])
  end

  defp metric_detail(yaml_path, behavior, bad_agg, good_agg) do
    Scorer.scalars_for(yaml_path, behavior)
    |> Enum.map(fn {{group, key}, scalar} ->
      bad_val = Scorer.get(bad_agg, group, key)
      good_val = Scorer.get(good_agg, group, key)
      ratio = if bad_val > 0, do: Float.round(good_val / bad_val, 2), else: 0.0

      %{
        group: group,
        key: key,
        scalar: scalar,
        bad: bad_val,
        good: good_val,
        ratio: ratio
      }
    end)
    |> Enum.sort_by(&abs(&1.ratio - 1.0), :desc)
  end

  @doc """
  Builds a per-behavior metric correlation report for scalar tuning.

  For each behavior with sample data, computes all `mean_*` metric values for
  both good and bad samples, then suggests normalized scalars in [-2, 2] using
  the log-linear method:

      log_diff = log(good_val) - log(bad_val)
      suggested_scalar = 2.0 * log_diff / max(|all log_diffs| for this behavior)

  The strongest signal for each behavior maps to ±2.0; all others scale
  proportionally. This lets you paste the suggested scalars into the YAML as a
  starting point and refine from there.

  ## Result shape (keyed by "category.behavior")

      %{
        "variable_naming.name_is_generic" => %{
          "identifier_length_variance.mean_variance" => %{
            bad: 5.131, good: 25.109,
            log_bad: 1.635, log_good: 3.224,
            ratio: 4.895,
            suggested_scalar: 2.0
          },
          ...
        }
      }
  """
  @spec build_metric_report(keyword()) :: map()
  def build_metric_report(opts \\ []) do
    filter_category = opts[:category]

    @samples_root
    |> File.ls!()
    |> Enum.flat_map(fn category ->
      Path.join([@samples_root, category])
      |> File.ls!()
      |> Enum.map(&{category, &1})
    end)
    |> Enum.filter(fn {category, behavior} ->
      (filter_category == nil or category == filter_category) and
        has_both_dirs?(category, behavior)
    end)
    |> Map.new(fn {category, behavior} ->
      {"#{category}.#{behavior}", behavior_metric_table(category, behavior)}
    end)
  end

  defp behavior_metric_table(category, behavior) do
    bad_agg = analyze(sample_path(category, behavior, "bad"))
    good_agg = analyze(sample_path(category, behavior, "good"))

    entries =
      Scorer.default_scalars()
      |> Map.keys()
      |> Enum.map(fn {group, key} ->
        bad_val = Scorer.get(bad_agg, group, key)
        good_val = Scorer.get(good_agg, group, key)
        log_bad = :math.log(bad_val)
        log_good = :math.log(good_val)
        ratio = good_val / bad_val
        log_diff = log_good - log_bad
        {"#{group}.#{key}", bad_val, good_val, log_bad, log_good, ratio, log_diff}
      end)

    max_abs_log_diff =
      entries
      |> Enum.map(fn {_, _, _, _, _, _, ld} -> abs(ld) end)
      |> Enum.max(fn -> 1.0 end)
      |> max(1.0e-10)

    Map.new(entries, fn {metric_key, bad_val, good_val, log_bad, log_good, ratio, log_diff} ->
      suggested_scalar = Float.round(2.0 * log_diff / max_abs_log_diff, 4)

      {metric_key,
       %{
         bad: r4(bad_val),
         good: r4(good_val),
         log_bad: r4(log_bad),
         log_good: r4(log_good),
         ratio: r4(ratio),
         suggested_scalar: suggested_scalar
       }}
    end)
  end

  @doc """
  Scores all combined metric behaviors against the given codebase aggregate map.

  Reads all YAML config files from `priv/combined_metrics/` and returns one entry
  per YAML category, each containing the scores for all behaviors within it.
  Behaviors are sorted ascending by score so the lowest-scoring (worst) appear first.

  ## Result shape

      [
        %{
          category: "variable_naming",
          name: "Variable Naming",
          behaviors: [
            %{behavior: "name_is_generic", score: 3.45},
            ...
          ]
        },
        ...
      ]
  """
  @spec score_aggregate(map(), keyword()) :: [map()]
  def score_aggregate(aggregate, opts \\ []) do
    languages = Keyword.get(opts, :languages)

    Scorer.all_yamls()
    |> Enum.sort_by(fn {path, _} -> path end)
    |> Enum.map(fn {yaml_path, data} ->
      category = yaml_path |> Path.basename() |> String.trim_trailing(".yml")

      behaviors =
        data
        |> Enum.filter(fn {_k, v} -> is_map(v) end)
        |> Enum.reject(fn {_behavior, behavior_data} ->
          behavior_langs = Map.get(behavior_data, "_languages", [])
          not behavior_language_applies?(behavior_langs, nil, languages)
        end)
        |> Enum.map(fn {behavior, behavior_data} ->
          log_baseline = Map.get(behavior_data, "_log_baseline", 0.0) / 1.0
          raw_score = Scorer.compute_score(yaml_path, behavior, aggregate)
          calibrated = :math.log(max(raw_score, 1.0e-300)) - log_baseline
          %{behavior: behavior, score: Float.round(calibrated, 4)}
        end)
        |> Enum.sort_by(& &1.score)

      %{category: category, name: humanize(category), behaviors: behaviors}
    end)
  end

  defp humanize(slug) do
    slug
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Identifies the most likely code quality issues in an aggregate by cosine similarity.

  For each behavior, computes the cosine similarity between its scalar weight vector
  `s` and the file's log-metric vector `v`:

      cos_sim = (s · v) / (|s| × |v|)

  A negative cosine means the file's metric profile anti-aligns with what good code
  looks like for that behavior — i.e. the file likely exhibits that anti-pattern.

  Results are sorted by cosine similarity ascending (most negative = most likely
  issue). Behaviors with no non-zero scalars (no sample data) are excluded.

  ## Options

    * `:top`       - number of results to return (default 15)
    * `:language`  - single language string for per-file filtering; when set, only
                     behaviors whose `_languages` list includes this language are scored
    * `:languages` - list of language strings for project-level filtering; when set, only
                     behaviors whose `_languages` list overlaps with this list are scored

  ## Result shape

      %{
        category:  "function_design",
        behavior:  "no_boolean_parameter",
        cosine:    -0.83,
        score:     -13.54,
        top_metrics: [%{metric: "branching.mean_branching_density", contribution: -4.1}, ...]
      }
  """
  @spec diagnose_aggregate(map(), keyword()) :: [map()]
  def diagnose_aggregate(aggregate, opts \\ []) do
    top_n = Keyword.get(opts, :top, 15)
    language = Keyword.get(opts, :language)
    languages = Keyword.get(opts, :languages)

    Scorer.all_yamls()
    |> Enum.sort_by(fn {path, _} -> path end)
    |> Enum.flat_map(fn {yaml_path, data} ->
      category = yaml_path |> Path.basename() |> String.trim_trailing(".yml")

      data
      |> Enum.filter(fn {_k, v} -> is_map(v) end)
      |> Enum.flat_map(fn {behavior, behavior_data} ->
        behavior_langs = Map.get(behavior_data, "_languages", [])

        if not behavior_language_applies?(behavior_langs, language, languages) do
          []
        else
          scalars = Scorer.scalars_for(yaml_path, behavior)

          if map_size(scalars) == 0 do
            []
          else
            log_baseline = Map.get(behavior_data, "_log_baseline", 0.0) / 1.0

            {dot, norm_s_sq, norm_v_sq, contributions} =
              Enum.reduce(scalars, {0.0, 0.0, 0.0, []}, fn {{group, key}, scalar},
                                                           {d, ns, nv, contribs} ->
                log_m = :math.log(Scorer.get(aggregate, group, key))
                contrib = scalar * log_m

                {d + contrib, ns + scalar * scalar, nv + log_m * log_m,
                 [{:"#{group}.#{key}", contrib} | contribs]}
              end)

            cos_sim =
              if norm_s_sq > 0 and norm_v_sq > 0,
                do: dot / (:math.sqrt(norm_s_sq) * :math.sqrt(norm_v_sq)),
                else: 0.0

            raw_score = Scorer.compute_score(yaml_path, behavior, aggregate)
            calibrated = :math.log(max(raw_score, 1.0e-300)) - log_baseline

            top_metrics =
              contributions
              |> Enum.sort_by(fn {_, c} -> c end)
              |> Enum.take(5)
              |> Enum.map(fn {metric, contribution} ->
                %{metric: to_string(metric), contribution: Float.round(contribution, 4)}
              end)

            [
              %{
                category: category,
                behavior: behavior,
                cosine: Float.round(cos_sim, 4),
                score: Float.round(calibrated, 4),
                top_metrics: top_metrics
              }
            ]
          end
        end
      end)
    end)
    |> Enum.sort_by(& &1.cosine)
    |> Enum.take(top_n)
  end

  @doc """
  Applies suggested scalars from sample analysis back to the YAML config files.

  For each behavior that has sample data, rewrites its scalar entries using the
  log-linear suggestion method. Metrics whose ratio falls in the deadzone
  (#{@deadzone_low} ≤ ratio ≤ #{@deadzone_high}) are excluded. All non-deadzoned
  metrics are written, even if they were not previously present in the YAML.

  Behaviors without sample data are left unchanged.

  Returns a list of per-category stats maps.
  """
  @spec apply_scalars(keyword()) :: [map()]
  def apply_scalars(opts \\ []) do
    report = build_metric_report(opts)
    filter_category = opts[:category]

    @yaml_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.filter(fn yml_file ->
      filter_category == nil or String.trim_trailing(yml_file, ".yml") == filter_category
    end)
    |> Enum.sort()
    |> Enum.map(fn yml_file ->
      category = String.trim_trailing(yml_file, ".yml")
      yaml_path = Path.join(@yaml_dir, yml_file)
      {:ok, existing} = YamlElixir.read_from_file(yaml_path)

      {updated_yaml, stats} = apply_to_category(existing, category, report)
      File.write!(yaml_path, format_yaml(updated_yaml))

      Map.put(stats, :category, category)
    end)
  end

  defp apply_to_category(existing, category, report) do
    existing
    |> Enum.filter(fn {_k, v} -> is_map(v) end)
    |> Enum.reduce({%{}, %{updated: 0, deadzoned: 0, skipped: 0}}, fn
      {behavior, current_groups}, {acc_yaml, stats} ->
        report_key = "#{category}.#{behavior}"
        doc = read_behavior_doc(category, behavior)

        case Map.get(report, report_key) do
          nil ->
            groups = maybe_put_doc(current_groups, doc)
            {Map.put(acc_yaml, behavior, groups), Map.update!(stats, :skipped, &(&1 + 1))}

          metrics ->
            {new_groups, log_baseline, n_updated, n_deadzoned} = groups_from_report(metrics)
            # Fall back to current groups if everything was deadzoned
            groups =
              if(map_size(new_groups) > 0, do: new_groups, else: current_groups)
              |> Map.put("_log_baseline", Float.round(log_baseline, 6))
              |> maybe_put_doc(doc)

            {Map.put(acc_yaml, behavior, groups),
             %{
               stats
               | updated: stats.updated + n_updated,
                 deadzoned: stats.deadzoned + n_deadzoned
             }}
        end
    end)
  end

  defp read_behavior_doc(category, behavior) do
    config_path = Path.join([@samples_root, category, behavior, "config.yml"])

    case File.read(config_path) do
      {:ok, content} ->
        case YamlElixir.read_from_string(content) do
          {:ok, %{"doc" => doc}} when is_binary(doc) -> doc
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp maybe_put_doc(groups, nil), do: groups
  defp maybe_put_doc(groups, doc), do: Map.put(groups, "_doc", doc)

  defp groups_from_report(metrics) do
    Enum.reduce(metrics, {%{}, 0.0, 0, 0}, fn {metric_key, data},
                                              {groups, log_baseline, n_updated, n_deadzoned} ->
      [group, key] = String.split(metric_key, ".", parts: 2)

      if deadzone?(data.ratio) do
        {groups, log_baseline, n_updated, n_deadzoned + 1}
      else
        new_groups =
          Map.update(
            groups,
            group,
            %{key => data.suggested_scalar},
            &Map.put(&1, key, data.suggested_scalar)
          )

        # Baseline: expected log score at the geometric mean of good/bad sample values
        geo_mean = :math.sqrt(max(data.bad, 1.0e-10) * max(data.good, 1.0e-10))
        new_baseline = log_baseline + data.suggested_scalar * :math.log(geo_mean)
        {new_groups, new_baseline, n_updated + 1, n_deadzoned}
      end
    end)
  end

  defp deadzone?(ratio), do: ratio >= @deadzone_low and ratio <= @deadzone_high

  # Returns true if the behavior should be included for the given language context.
  # behavior_langs: the "_languages" list from the YAML ([] = applies to all)
  # language: single language string from :language opt (nil = no filter)
  # languages: project language list from :languages opt (nil = no filter)
  defp behavior_language_applies?(_behavior_langs, nil, nil), do: true

  # Empty behavior_langs means "applies to all languages" — always include.
  # This clause takes priority over all non-nil filter cases.
  defp behavior_language_applies?([], _language, _languages), do: true

  defp behavior_language_applies?(_behavior_langs, nil, []), do: true

  defp behavior_language_applies?(behavior_langs, language, nil) when is_binary(language),
    do: language in behavior_langs

  defp behavior_language_applies?(behavior_langs, nil, languages) when is_list(languages),
    do: Enum.any?(behavior_langs, &(&1 in languages))

  defp behavior_language_applies?(behavior_langs, language, languages)
       when is_binary(language) and is_list(languages),
       do: language in behavior_langs or Enum.any?(behavior_langs, &(&1 in languages))

  defp format_yaml(data) do
    lines =
      data
      |> Enum.sort_by(fn {behavior, _} -> behavior end)
      |> Enum.flat_map(fn {behavior, groups} ->
        doc_line =
          case Map.get(groups, "_doc") do
            nil -> []
            doc -> ["  _doc: #{inspect(doc)}"]
          end

        baseline_line =
          case Map.get(groups, "_log_baseline") do
            nil -> []
            val -> ["  _log_baseline: #{fmt_scalar(val)}"]
          end

        fix_hint_line =
          case Map.get(groups, "_fix_hint") do
            nil -> []
            hint -> ["  _fix_hint: #{inspect(hint)}"]
          end

        languages_line =
          case Map.get(groups, "_languages") do
            nil -> []
            [] -> []
            langs -> ["  _languages: [#{Enum.join(langs, ", ")}]"]
          end

        group_lines =
          groups
          |> Enum.filter(fn {k, v} ->
            k not in ["_doc", "_log_baseline", "_fix_hint", "_languages"] and is_map(v)
          end)
          |> Enum.sort_by(fn {group, _} -> group end)
          |> Enum.flat_map(fn {group, keys} ->
            key_lines =
              keys
              |> Enum.sort_by(fn {key, _} -> key end)
              |> Enum.map(fn {key, scalar} -> "    #{key}: #{fmt_scalar(scalar)}" end)

            ["  #{group}:" | key_lines]
          end)

        ["#{behavior}:" | doc_line] ++
          fix_hint_line ++ languages_line ++ baseline_line ++ group_lines ++ [""]
      end)

    Enum.join(lines, "\n") <> "\n"
  end

  defp fmt_scalar(f) when is_float(f), do: :erlang.float_to_binary(f, decimals: 4)
  defp fmt_scalar(n) when is_integer(n), do: "#{n}.0"

  defp r4(f), do: Float.round(f / 1.0, 4)

  defp sample_path(category, behavior, kind) do
    Path.join([@samples_root, category, behavior, kind])
  end

  defp dir_languages(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.map(&CodeQA.Language.detect/1)
        |> Enum.map(& &1.name())
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end

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
  defp maybe_put_languages(groups, langs), do: Map.put(groups, "_languages", langs)

  @doc """
  Updates only the `_languages` field in YAML config files based on sample data.

  Scans `bad/` and `good/` sample directories for each behavior, detects languages
  from file extensions via `CodeQA.Language.detect/1`, and writes the intersection
  as `_languages` to the YAML. Behaviors without sample data are left without a
  `_languages` key (treated as applying to all languages at scoring time).
  All existing scalars and baselines are preserved.

  Returns a list of `%{category: String.t(), behaviors_with_languages: non_neg_integer()}`.
  """
  @spec apply_languages(keyword()) :: [map()]
  def apply_languages(opts \\ []) do
    filter_category = opts[:category]

    @yaml_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.filter(fn yml_file ->
      filter_category == nil or String.trim_trailing(yml_file, ".yml") == filter_category
    end)
    |> Enum.sort()
    |> Enum.map(fn yml_file ->
      category = String.trim_trailing(yml_file, ".yml")
      yaml_path = Path.join(@yaml_dir, yml_file)
      {:ok, existing} = YamlElixir.read_from_file(yaml_path)

      updated =
        existing
        |> Enum.filter(fn {_k, v} -> is_map(v) end)
        |> Map.new(fn {behavior, groups} ->
          langs = languages_for_behavior(category, behavior)
          {behavior, maybe_put_languages(groups, langs)}
        end)

      File.write!(yaml_path, format_yaml(updated))

      behaviors_with_languages =
        Enum.count(updated, fn {_b, groups} -> Map.has_key?(groups, "_languages") end)

      %{category: category, behaviors_with_languages: behaviors_with_languages}
    end)
  end
end
