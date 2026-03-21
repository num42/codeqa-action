defmodule CodeQA.CombinedMetrics.FileScorer do
  @moduledoc """
  Scores individual files against combined metric behaviors.

  Converts per-file raw metric maps to aggregate-compatible format and
  identifies which behaviors each file most likely exhibits.
  """

  alias CodeQA.CombinedMetrics.SampleRunner
  alias CodeQA.Config
  alias CodeQA.HealthReport.Grader
  alias CodeQA.Language

  @doc """
  Converts a single file's raw metric map to aggregate format.

  Wraps each key in each group with the `mean_` prefix so the resulting
  map is compatible with `SampleRunner.diagnose_aggregate/2`.

  ## Example

      iex> CodeQA.CombinedMetrics.FileScorer.file_to_aggregate(%{"halstead" => %{"tokens" => 42.0}})
      %{"halstead" => %{"mean_tokens" => 42.0}}
  """
  @spec file_to_aggregate(map()) :: map()
  def file_to_aggregate(metrics) do
    Map.new(metrics, fn {group, keys} ->
      prefixed_keys = Map.new(keys, fn {key, value} -> {"mean_" <> key, value} end)
      {group, prefixed_keys}
    end)
  end

  @doc """
  Identifies the worst files per combined metric behavior.

  For each file in `files_map`, converts its metrics to aggregate format and
  runs `SampleRunner.diagnose_aggregate/2`. The results are collected per
  behavior and sorted ascending by cosine similarity (most negative = worst first),
  then truncated to `combined_top` entries.

  ## Options

    * `:combined_top` - number of worst files to keep per behavior (default: 2)

  ## Result shape

      %{
        "function_design.no_boolean_parameter" => [
          %{file: "lib/foo/bar.ex", cosine: -0.71},
          %{file: "lib/foo/baz.ex", cosine: -0.44}
        ],
        ...
      }
  """
  @spec worst_files_per_behavior(map(), keyword()) ::
          %{
            String.t() => [
              %{file: String.t(), cosine: float(), top_metrics: list(), top_nodes: list()}
            ]
          }
  def worst_files_per_behavior(files_map, opts \\ []) do
    # NOTE: cosine similarity is computed at file level; a line-level mapping would require computing a separate
    # cosine score for each AST node by projecting that node's metric vector against the behavior's
    # feature-weight vector. This is not currently possible because serialized nodes do not carry their own
    # metric values.
    top_n = Keyword.get(opts, :combined_top, 2)

    files_map
    |> Enum.reject(fn {_path, file_data} ->
      file_data |> Map.get("metrics", %{}) |> map_size() == 0
    end)
    |> Enum.reduce(%{}, fn {path, file_data}, acc ->
      accumulate_file_behaviors(path, file_data, acc)
    end)
    |> Map.new(fn {key, entries} ->
      threshold = Config.cosine_significance_threshold()

      sorted =
        entries
        |> Enum.filter(fn e -> e.cosine <= -threshold end)
        |> Enum.sort_by(& &1.cosine)
        |> Enum.take(top_n)

      {key, sorted}
    end)
  end

  # Diagnoses a single file's metrics and merges per-behavior entries into the accumulator.
  defp accumulate_file_behaviors(path, file_data, acc) do
    top_nodes = Grader.top_3_nodes(Map.get(file_data, "nodes"))
    language = Language.detect(path).name()

    file_data
    |> Map.get("metrics", %{})
    |> file_to_aggregate()
    |> SampleRunner.diagnose_aggregate(top: 99_999, language: language)
    |> Enum.reduce(acc, fn %{
                             category: category,
                             behavior: behavior,
                             cosine: cosine,
                             top_metrics: top_metrics
                           },
                           inner_acc ->
      key = "#{category}.#{behavior}"
      entry = %{file: path, cosine: cosine, top_metrics: top_metrics, top_nodes: top_nodes}
      Map.update(inner_acc, key, [entry], &[entry | &1])
    end)
  end
end
