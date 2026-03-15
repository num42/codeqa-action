defmodule CodeQA.Diagnostics do
  @moduledoc """
  Diagnoses a codebase by identifying likely code quality issues using
  cosine similarity against combined metric behavior profiles.
  """

  alias CodeQA.CombinedMetrics.{SampleRunner, FileScorer}
  alias CodeQA.HealthReport.Grader

  @doc """
  Runs diagnostics on the given path and prints results to stdout.

  ## Options

    * `:path` - file or directory path (required)
    * `:mode` - `:aggregate` (default) or `:per_file`
    * `:top` - number of top issues to display (default 15)
    * `:format` - `:plain` or `:json` (default `:plain`)
    * `:combined_top` - worst offender files per behavior (default 2)
  """
  @spec run(keyword()) :: :ok
  def run(opts) do
    path = opts[:path]
    mode = opts[:mode] || :aggregate
    top = opts[:top] || 15
    format = opts[:format] || :plain

    files = CodeQA.Collector.collect_files(path, [])
    result = CodeQA.Analyzer.analyze_codebase(files, [])

    case mode do
      :per_file -> run_per_file(result, top, format)
      _ -> run_aggregate(result, top, format)
    end
  end

  defp run_aggregate(result, top, format) do
    aggregate = get_in(result, ["codebase", "aggregate"])
    issues = SampleRunner.diagnose_aggregate(aggregate, top: top)
    categories = SampleRunner.score_aggregate(aggregate)

    case format do
      :json ->
        output = %{
          issues: issues,
          categories: categories
        }

        IO.puts(Jason.encode!(output, pretty: true))

      _ ->
        IO.puts("## Diagnose: aggregate\n")
        print_issues_table(issues)
        print_categories(categories)
    end

    :ok
  end

  defp run_per_file(result, top, format) do
    files = Map.get(result, "files", %{})

    file_diagnoses =
      Map.new(files, fn {file_path, file_data} ->
        metrics = Map.get(file_data, "metrics", %{})
        file_agg = FileScorer.file_to_aggregate(metrics)
        diagnoses = SampleRunner.diagnose_aggregate(file_agg, top: top)
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

        IO.puts(Jason.encode!(%{files: files_json}, pretty: true))

      _ ->
        file_rows =
          Enum.flat_map(file_diagnoses, fn {file_path, diagnoses} ->
            Enum.map(diagnoses, fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
              {file_path, "#{cat}.#{beh}", cosine, score}
            end)
          end)

        IO.puts("## Diagnose: per-file\n")
        print_per_file_table(file_rows, top)
    end

    :ok
  end

  defp print_issues_table(issues) do
    IO.puts("| Behavior | Cosine | Score |")
    IO.puts("|----------|--------|-------|")

    Enum.each(issues, fn %{category: cat, behavior: beh, cosine: cosine, score: score} ->
      cosine_str = :erlang.float_to_binary(cosine / 1.0, decimals: 2)
      score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
      IO.puts("| #{cat}.#{beh} | #{cosine_str} | #{score_str} |")
    end)

    IO.puts("")
  end

  defp print_categories(categories) do
    Enum.each(categories, fn %{name: name, behaviors: behaviors} ->
      IO.puts("### #{name}")
      IO.puts("| Behavior | Score |")
      IO.puts("|----------|-------|")

      Enum.each(behaviors, fn %{behavior: beh, score: score} ->
        score_str = :erlang.float_to_binary(score / 1.0, decimals: 2)
        IO.puts("| #{beh} | #{score_str} |")
      end)

      IO.puts("")
    end)
  end

  defp print_per_file_table(rows, top) do
    IO.puts("| File | Behavior | Cosine | Score |")
    IO.puts("|------|----------|--------|-------|")

    rows
    |> Enum.group_by(fn {file_path, _, _, _} -> file_path end)
    |> Enum.flat_map(fn {_file_path, file_rows} ->
      file_rows
      |> Enum.sort_by(fn {_, _, cosine, _} -> cosine end)
      |> Enum.take(top)
    end)
    |> Enum.each(fn {file_path, behavior_key, cosine, _score} ->
      cosine_str = :erlang.float_to_binary(cosine / 1.0, decimals: 2)
      cosine_score = Grader.score_cosine(cosine)
      IO.puts("| #{file_path} | #{behavior_key} | #{cosine_str} | #{cosine_score} |")
    end)
  end
end
