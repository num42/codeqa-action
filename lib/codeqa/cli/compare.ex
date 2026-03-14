defmodule CodeQA.CLI.Compare do
  @moduledoc false

  alias CodeQA.CLI.Options

  @version "0.1.0"

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, [path], _} =
      Options.parse(args,
        [
          base_ref: :string,
          head_ref: :string,
          changes_only: :boolean,
          all_files: :boolean,
          format: :string,
          output: :string
        ],
        []
      )

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    base_ref = opts[:base_ref] || raise "Missing --base-ref"
    head_ref = opts[:head_ref] || "HEAD"
    changes_only = if opts[:all_files], do: false, else: true
    format = opts[:format] || "json"
    output_mode = opts[:output] || "auto"

    Options.validate_dir!(path)

    ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])
    opts = Keyword.put(opts, :ignore_patterns, ignore_patterns)

    {base_result, head_result, changes} =
      run_comparison(path, base_ref, head_ref, changes_only, opts)

    comparison =
      CodeQA.Comparator.compare_results(base_result, head_result, changes)
      |> enrich_metadata(base_ref, head_ref, changes_only)
      |> filter_files_for_output(opts)

    output_comparison(comparison, format, output_mode)

    if opts[:telemetry], do: CodeQA.Telemetry.print_report()
  end

  defp run_comparison(path, base_ref, head_ref, changes_only, opts) do
    ignore_patterns = opts[:ignore_patterns] || []
    changes = CodeQA.Git.changed_files(path, base_ref, head_ref)
    changes = CodeQA.Collector.reject_ignored(changes, ignore_patterns, & &1.path)

    file_paths =
      if changes_only do
        IO.puts(:stderr, "Comparing #{length(changes)} changed files...")
        Enum.map(changes, & &1.path)
      else
        IO.puts(:stderr, "Comparing all source files...")
        nil
      end

    empty = %{"files" => %{}, "codebase" => %{"aggregate" => %{}, "similarity" => %{}}}

    if changes_only and length(changes) == 0 do
      IO.puts(:stderr, "No source files changed — nothing to compare.")
      {empty, empty, []}
    else
      base_files = CodeQA.Git.collect_files_at_ref(path, base_ref, file_paths)
      head_files = CodeQA.Git.collect_files_at_ref(path, head_ref, file_paths)
      base_files = CodeQA.Collector.reject_ignored_map(base_files, ignore_patterns)
      head_files = CodeQA.Collector.reject_ignored_map(head_files, ignore_patterns)

      if map_size(base_files) == 0 and map_size(head_files) == 0 do
        IO.puts(:stderr, "Warning: no source files found at either ref")
        exit({:shutdown, 1})
      end

      print_progress(opts, base_files, head_files)

      analyze_opts = Options.build_analyze_opts(opts)

      base_result =
        if map_size(base_files) > 0,
          do: CodeQA.Analyzer.analyze_codebase(base_files, analyze_opts),
          else: empty

      head_result =
        if map_size(head_files) > 0,
          do: CodeQA.Analyzer.analyze_codebase(head_files, analyze_opts),
          else: empty

      changes = if changes_only, do: changes, else: synthesize_changes(base_files, head_files)

      {base_result, head_result, changes}
    end
  end

  defp print_progress(opts, base_files, head_files) do
    if opts[:progress] do
      step_prefix = if opts[:show_ncd], do: "1/5 ", else: "1/1 "

      IO.puts(
        :stderr,
        "  #{step_prefix}Analyzing base (#{map_size(base_files)} files) and head (#{map_size(head_files)} files)..."
      )
    else
      IO.puts(
        :stderr,
        "Analyzing base (#{map_size(base_files)} files) and head (#{map_size(head_files)} files)..."
      )
    end
  end

  defp enrich_metadata(comparison, base_ref, head_ref, changes_only) do
    comparison
    |> put_in(["metadata", "base_ref"], base_ref)
    |> put_in(["metadata", "head_ref"], head_ref)
    |> put_in(["metadata", "changes_only"], changes_only)
    |> put_in(["metadata", "version"], @version)
    |> put_in(["metadata", "timestamp"], DateTime.utc_now() |> DateTime.to_iso8601())
  end

  defp output_comparison(comparison, "markdown", output_mode) do
    IO.puts(CodeQA.Formatter.format_markdown(comparison, output_mode))
  end

  defp output_comparison(comparison, "github", output_mode) do
    IO.puts(CodeQA.Formatter.format_github(comparison, output_mode))
  end

  defp output_comparison(comparison, _format, output_mode) do
    codebase_summary = CodeQA.Summarizer.summarize_codebase(comparison)

    file_summaries =
      Map.new(Map.get(comparison, "files", %{}), fn {path, data} ->
        {path, CodeQA.Summarizer.summarize_file(path, data)}
      end)

    IO.puts(
      Jason.encode!(build_json_output(comparison, codebase_summary, file_summaries, output_mode),
        pretty: true
      )
    )
  end

  defp build_json_output(comparison, codebase_summary, file_summaries, output_mode) do
    result = %{"metadata" => comparison["metadata"]}

    result =
      if output_mode in ["auto", "summary"] do
        result
        |> Map.put("summary", codebase_summary)
        |> Map.put("codebase", comparison["codebase"])
      else
        result
      end

    if output_mode in ["auto", "changes"] and Map.has_key?(comparison, "files") do
      files_with_summaries =
        Map.new(comparison["files"], fn {path, data} ->
          {path, Map.put(data, "summary", Map.get(file_summaries, path, %{}))}
        end)

      Map.put(result, "files", files_with_summaries)
    else
      result
    end
  end

  defp synthesize_changes(base_files, head_files) do
    all_paths = MapSet.union(MapSet.new(Map.keys(base_files)), MapSet.new(Map.keys(head_files)))

    all_paths
    |> Enum.sort()
    |> Enum.map(fn path ->
      status =
        cond do
          Map.has_key?(base_files, path) and Map.has_key?(head_files, path) -> "modified"
          Map.has_key?(head_files, path) -> "added"
          true -> "deleted"
        end

      %CodeQA.Git.ChangedFile{path: path, status: status}
    end)
  end

  defp filter_files_for_output(results, opts) do
    cond do
      opts[:show_files] ->
        results

      opts[:show_file_paths] ->
        target_paths = String.split(opts[:show_file_paths], ",") |> MapSet.new()

        filtered =
          Map.filter(results["files"], fn {path, _} -> MapSet.member?(target_paths, path) end)

        Map.put(results, "files", filtered)

      true ->
        Map.delete(results, "files")
    end
  end
end
