defmodule CodeQA.Diagnostics do
  @moduledoc """
  Diagnoses a codebase by identifying likely code quality issues using
  cosine similarity against combined metric behavior profiles.
  """

  alias CodeQA.CombinedMetrics.{SampleRunner, FileScorer}
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

    files = CodeQA.Engine.Collector.collect_files(path)
    result = CodeQA.Engine.Analyzer.analyze_codebase(files, [])

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
        language = CodeQA.Language.detect(file_path).name()
        diagnoses = SampleRunner.diagnose_aggregate(file_agg, top: top, language: language)
        {file_path, diagnoses}
      end)

    case format do
      :json ->
        files_json =
          Enum.map(file_diagnoses, fn {file_path, diagnoses} ->
            behaviors =
              Enum.map(diagnoses, fn d ->
                %{
                  behavior: "#{d.category}.#{d.behavior}",
                  cosine: d.cosine,
                  score: Grader.score_cosine(d.cosine)
                }
              end)

            %{file: file_path, behaviors: behaviors}
          end)

        Jason.encode!(%{files: files_json}, pretty: true)

      _ ->
        file_rows =
          Enum.flat_map(file_diagnoses, fn {file_path, diagnoses} ->
            Enum.map(diagnoses, fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
              {file_path, "#{cat}.#{beh}", cosine, score}
            end)
          end)

        "## Diagnose: per-file\n\n" <> per_file_table(file_rows, top)
    end
  end

  defp project_languages(files_map) do
    files_map
    |> Map.keys()
    |> Enum.map(&CodeQA.Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end

  defp issues_table(issues) do
    rows =
      Enum.map(issues, fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
        cosine_str = :erlang.float_to_binary(cosine / 1.0, decimals: 2)
        score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
        "| #{cat}.#{beh} | #{cosine_str} | #{score_str} |"
      end)

    Enum.join(
      ["| Behavior | Cosine | Score |", "|----------|--------|-------|"] ++ rows ++ [""],
      "\n"
    )
  end

  defp categories_text(categories) do
    Enum.map_join(categories, "\n", fn %{name: name, behaviors: behaviors} ->
      rows =
        Enum.map(behaviors, fn %{behavior: beh, score: score} ->
          score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
          "| #{beh} | #{score_str} |"
        end)

      Enum.join(
        ["### #{name}", "| Behavior | Score |", "|----------|-------|"] ++ rows ++ [""],
        "\n"
      )
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

    Enum.join(
      ["| File | Behavior | Cosine | Score |", "|------|----------|--------|-------|"] ++
        data_rows,
      "\n"
    )
  end
end
