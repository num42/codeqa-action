defmodule CodeQA.Diagnostics do
  alias CodeQA.Language

  import CodeQA.Shared, only: [project_languages_shared: 1]

  @moduledoc """
  Diagnoses a codebase by identifying likely code quality issues using
  cosine similarity against combined metric behavior profiles.
  """

  alias CodeQA.CombinedMetrics.FileScorer
  alias CodeQA.CombinedMetrics.SampleRunner
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Collector
  alias CodeQA.HealthReport.Grader

  @doc """
  Runs diagnostics on the given path and returns results as a string.

  ## Options

    * `:path` - file or directory path (required)
    * `:mode` - `:aggregate` (default) or `:per_file`
    * `:top` - number of top issues to display (default 15)
    * `:format` - `:plain` or `:json` (default `:plain`)
    * `:combined_top` - worst offender files per behavior (default 2)
  """
  @spec run(keyword()) :: String.t()
  def run(opts) do
    path = opts[:path]
    mode = opts[:mode] || :aggregate
    top = opts[:top] || 15
    format = opts[:format] || :plain

    files = Collector.collect_files(path)
    result = Analyzer.analyze_codebase(files, [])

    case mode do
      :per_file -> run_per_file(result, top, format)
      _ -> run_aggregate(result, top, format)
    end
  end

  defp run_aggregate(result, top, format) do
    aggregate = get_in(result, ["codebase", "aggregate"])
    files = Map.get(result, "files", %{})
    project_langs = project_languages(files)

    issues_task =
      Task.async(fn ->
        SampleRunner.diagnose_aggregate(aggregate, top: top, languages: project_langs)
      end)

    categories_task =
      Task.async(fn -> SampleRunner.score_aggregate(aggregate, languages: project_langs) end)

    issues = Task.await(issues_task)
    categories = Task.await(categories_task)

    case format do
      :json ->
        Jason.encode!(%{issues: issues, categories: categories}, pretty: true)

      _ ->
        "## Diagnose: aggregate\n\n" <>
          issues_table(issues) <>
          "\n" <>
          categories_text(categories)
    end
  end

  defp run_per_file(result, top, format) do
    files = Map.get(result, "files", %{})

    file_diagnoses =
      Map.new(files, fn {file_path, file_data} ->
        metrics = Map.get(file_data, "metrics", %{})
        file_agg = FileScorer.file_to_aggregate(metrics)
        language = Language.detect(file_path).name()
        diagnoses = SampleRunner.diagnose_aggregate(file_agg, top: top, language: language)
        {file_path, diagnoses}
      end)

    case format do
      :json ->
        files_json =
          file_diagnoses
          |> Enum.map(fn {file_path, diagnoses} ->
            %{file: file_path, behaviors: diagnoses |> Enum.map(&diagnosis_to_map/1)}
          end)

        Jason.encode!(%{files: files_json}, pretty: true)

      _ ->
        file_rows =
          file_diagnoses
          |> Enum.flat_map(fn {file_path, diagnoses} ->
            diagnoses_to_rows(file_path, diagnoses)
          end)

        "## Diagnose: per-file\n\n" <> per_file_table(file_rows, top)
    end
  end

  defp diagnosis_to_map(d) do
    %{
      behavior: "#{d.category}.#{d.behavior}",
      cosine: d.cosine,
      score: Grader.score_cosine(d.cosine)
    }
  end

  defp diagnoses_to_rows(file_path, diagnoses) do
    diagnoses
    |> Enum.map(fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
      {file_path, "#{cat}.#{beh}", cosine, score}
    end)
  end

  defp project_languages(files_map), do: project_languages_shared(files_map)

  defp issues_table(issues) do
    rows =
      issues
      |> Enum.map(fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
        cosine_str = :erlang.float_to_binary(cosine / 1.0, decimals: 2)
        score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
        "| #{cat}.#{beh} | #{cosine_str} | #{score_str} |"
      end)

    (["| Behavior | Cosine | Score |", "|----------|--------|-------|"] ++ rows ++ [""])
    |> Enum.join("\n")
  end

  defp categories_text(categories) do
    categories
    |> Enum.map_join("\n", fn %{name: name, behaviors: behaviors} ->
      rows =
        behaviors
        |> Enum.map(fn %{behavior: beh, score: score} ->
          score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
          "| #{beh} | #{score_str} |"
        end)

      (["### #{name}", "| Behavior | Score |", "|----------|-------|"] ++ rows ++ [""])
      |> Enum.join("\n")
    end)
  end

  defp per_file_table(rows, top) do
    data_rows =
      rows
      |> Enum.group_by(fn {file_path, _, _, _} -> file_path end)
      |> Enum.flat_map(fn {_file_path, file_rows} ->
        file_rows
        |> Enum.sort_by(fn {_, _, cosine, _} -> cosine end)
        |> Enum.take(top)
      end)
      |> Enum.map(fn {file_path, behavior_key, cosine, _score} ->
        cosine_str = :erlang.float_to_binary(cosine / 1.0, decimals: 2)
        cosine_score = Grader.score_cosine(cosine)
        "| #{file_path} | #{behavior_key} | #{cosine_str} | #{cosine_score} |"
      end)

    (["| File | Behavior | Cosine | Score |", "|------|----------|--------|-------|"] ++
       data_rows)
    |> Enum.join("\n")
  end
end
