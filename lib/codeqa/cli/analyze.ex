defmodule CodeQA.CLI.Analyze do
  @moduledoc false

  alias CodeQA.CLI.Options

  @version "0.1.0"

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, [path], _} =
      Options.parse(args, [output: :string], [o: :output])

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    Options.validate_dir!(path)

    ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    print_progress(opts, files)

    analyze_opts = Options.build_analyze_opts(opts)

    start_time = System.monotonic_time(:millisecond)
    results = CodeQA.Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()
    results = filter_files_for_output(results, opts)

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
        IO.puts(json)

      file ->
        File.write!(file, json)
        IO.puts(:stderr, "Report written to #{file}")
    end

    if opts[:telemetry], do: CodeQA.Telemetry.print_report()
  end

  defp print_progress(opts, files) do
    if opts[:progress] do
      step_prefix = if opts[:show_ncd], do: "1/5 ", else: "1/1 "
      IO.puts(:stderr, "  #{step_prefix}Analyzing #{map_size(files)} files...")
    else
      IO.puts(:stderr, "Analyzing #{map_size(files)} files...")
    end
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
