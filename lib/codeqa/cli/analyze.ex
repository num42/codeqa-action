defmodule CodeQA.CLI.Analyze do
  @moduledoc false

  @behaviour CodeQA.CLI.Command

  alias CodeQA.CLI.Options
  alias CodeQA.Config
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Collector

  @version "0.1.0"

  @impl CodeQA.CLI.Command
  def usage do
    """
    Usage: codeqa analyze <path> [options]

      Analyze a codebase for statistical code quality metrics.

    Options:
      -o, --output FILE     Output file path (default: stdout)
      --progress            Show per-file progress on stderr
      -w, --workers N       Number of parallel workers
      --cache               Enable caching file metrics
      --cache-dir DIR       Directory to store cache (default: .codeqa_cache)
      -t, --timeout MS      Timeout for similarity analysis (default: 5000)
      --show-ncd            Compute and show NCD similarity metric
      --ncd-top N           Number of top similar files to show per file
      --ncd-paths PATHS     Comma-separated list of paths to compute NCD for
      --show-files          Include individual file metrics in the output
      --show-file-paths P   Comma-separated list of paths to include in the output
      --ignore-paths PATHS  Comma-separated list of path patterns to ignore (supports wildcards, e.g. "test/*,docs/*")
    """
  end

  @impl CodeQA.CLI.Command
  def run(args) when args in [["--help"], ["-h"]] do
    usage()
  end

  def run(args) do
    {opts, [path], _} =
      Options.parse(args, [output: :string], o: :output)

    Options.validate_dir!(path)
    Config.load(path)

    files =
      Collector.collect_files(path, Options.parse_ignore_paths(opts[:ignore_paths]))

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    print_progress(opts, files)

    analyze_opts =
      Options.build_analyze_opts(opts) ++ Config.near_duplicate_blocks_opts()

    start_time = System.monotonic_time(:millisecond)
    results = Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()
    results = filter_files_for_output(results, opts, "json")

    report =
      %{
        "metadata" => %{
          "path" => Path.expand(path),
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "total_files" => map_size(files),
          "total_bytes" => total_bytes,
          "version" => @version
        }
      }
      |> Map.merge(results)

    json = Jason.encode!(report, pretty: true)

    case opts[:output] do
      nil ->
        json

      file ->
        File.write!(file, json)
        IO.puts(:stderr, "Report written to #{file}")
        ""
    end
  end

  defp print_progress(opts, files) do
    if opts[:progress] do
      step_prefix = if opts[:show_ncd], do: "1/5 ", else: "1/1 "
      IO.puts(:stderr, "  #{step_prefix}Analyzing #{map_size(files)} files...")
    else
      IO.puts(:stderr, "Analyzing #{map_size(files)} files...")
    end
  end

  defp filter_files_for_output(results, opts, _format) do
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
